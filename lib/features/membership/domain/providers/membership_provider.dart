import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/membership_models.dart';
import '../../../payment/data/payment_data_source.dart';
import '../../../payment/data/models/payment_models.dart';
import '../../../scene/data/models/scene_models.dart';
import '../../../scene/domain/providers/scene_provider.dart';

class MembershipState {
  final QuotaInfo? quota;
  final PlanType selectedPlan;
  final PaymentChannel channel;
  final bool isLoading;
  final int totalScenes;

  const MembershipState({
    this.quota,
    this.selectedPlan = PlanType.yearly,
    this.channel = PaymentChannel.alipay,
    this.isLoading = false,
    this.totalScenes = 0,
  });

  /// 从场景列表动态生成权益项
  List<BenefitItem> buildBenefits(List<SceneConfig> scenes) {
    final items = <BenefitItem>[];
    for (final scene in scenes) {
      items.add(BenefitItem(
        name: scene.name,
        freeValue: scene.pricing.isFree ? '免费' : '1次体验',
        proValue: '不限',
        isFreeChecked: true,
        isProChecked: true,
      ));
    }
    items.addAll([
      const BenefitItem(name: '文档精修', freeValue: '—', proValue: '∞', isFreeChecked: false),
      const BenefitItem(name: '多语言翻译', freeValue: '—', proValue: '6种语言', isFreeChecked: false),
      const BenefitItem(name: '导出格式', freeValue: 'Word', proValue: 'Word/PDF/HTML', isFreeChecked: true),
      const BenefitItem(name: 'AI响应速度', freeValue: '标准', proValue: '优先', isFreeChecked: true),
    ]);
    return items;
  }

  String get ctaLabel => '立即订阅 · ${selectedPlan.price}/${selectedPlan == PlanType.lifetime ? '永久' : selectedPlan.period.replaceAll('/', '')}';
  String get ctaPrice => selectedPlan.price;

  MembershipState copyWith({
    QuotaInfo? quota,
    PlanType? selectedPlan,
    PaymentChannel? channel,
    bool? isLoading,
    int? totalScenes,
  }) {
    return MembershipState(
      quota: quota ?? this.quota,
      selectedPlan: selectedPlan ?? this.selectedPlan,
      channel: channel ?? this.channel,
      isLoading: isLoading ?? this.isLoading,
      totalScenes: totalScenes ?? this.totalScenes,
    );
  }
}

class MembershipNotifier extends StateNotifier<MembershipState> {
  final PaymentDataSource _paymentDs;
  final Ref _ref;
  bool _cancelled = false;
  bool _initialized = false;

  MembershipNotifier(this._ref, this._paymentDs) : super(const MembershipState());

  /// 首次访问时延迟初始化（不阻塞构造函数）
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await Future.wait([
      _loadSceneStats(),
      loadQuota(),
    ]);
  }

  /// 从场景列表聚合统计数据
  Future<void> _loadSceneStats() async {
    try {
      final scenes = await _ref.read(sceneListProvider.future);
      if (!mounted) return;
      state = state.copyWith(totalScenes: scenes.length);
    } catch (e) {
      debugPrint('[Membership] _loadSceneStats error: $e');
    }
  }

  /// 加载真实配额数据
  Future<void> loadQuota() async {
    try {
      final quota = await _paymentDs.getMyQuota();
      state = state.copyWith(quota: quota);
    } catch (e) {
      debugPrint('[Membership] loadQuota error: $e');
    }
  }

  void selectPlan(PlanType plan) {
    state = state.copyWith(selectedPlan: plan);
  }

  void selectChannel(PaymentChannel ch) {
    state = state.copyWith(channel: ch);
  }

  /// 取消订阅轮询
  void cancelSubscribe() {
    _cancelled = true;
    state = state.copyWith(isLoading: false);
  }

  /// 真实订阅流程
  Future<void> subscribe() async {
    _cancelled = false;
    state = state.copyWith(isLoading: true);
    try {
      final order = await _paymentDs.createOrder(CreateOrderRequest(
        channel: state.channel.name,
        orderType: 'membership',
      ));

      // 打开支付链接（安全校验）
      if (order.payUrl != null && order.payUrl!.isNotEmpty) {
        final uri = Uri.parse(order.payUrl!);
        if (uri.scheme.startsWith('https') || uri.scheme.startsWith('alipays') || uri.scheme.startsWith('weixin')) {
          await launchUrl(uri);
        }
      }

      // 轮询至支付完成
      for (var i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted || _cancelled) return;
        try {
          final updated = await _paymentDs.getOrder(order.orderNo);
          if (updated.isPaid) {
            await loadQuota();
            return;
          }
          if (!updated.isPending) return;
        } catch (e) {
          debugPrint('[Membership] poll order error: $e');
          if (i >= 2) break;
        }
      }
    } catch (e) {
      debugPrint('[Membership] subscribe error: $e');
    } finally {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }
}

final membershipProvider =
    StateNotifierProvider<MembershipNotifier, MembershipState>((ref) {
  final paymentDs = PaymentDataSource();
  return MembershipNotifier(ref, paymentDs);
});
