import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/iap/channel_detector.dart';
import '../../data/models/membership_models.dart';
import '../../../payment/data/payment_data_source.dart';
import '../../../payment/data/models/payment_models.dart';
import '../../../payment/domain/providers/payment_provider.dart';
import '../../../scene/data/models/scene_models.dart';
import '../../../scene/domain/providers/scene_provider.dart';

/// 订阅下单结果：包含支付宝 URL 或微信 APP 调起参数
class PaymentLaunchResult {
  final String? payUrl;
  final Map<String, String>? payParams;
  const PaymentLaunchResult({this.payUrl, this.payParams});
}

class MembershipState {
  final QuotaInfo? quota;
  final PlanType selectedPlan;
  final PaymentChannel channel;
  final bool isLoading;
  final int totalScenes;
  final String? successMessage;
  final String? errorMessage;

  const MembershipState({
    this.quota,
    this.selectedPlan = PlanType.yearly,
    this.channel = PaymentChannel.alipay,
    this.isLoading = false,
    this.totalScenes = 0,
    this.successMessage,
    this.errorMessage,
  });

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

  bool get isIap => ChannelDetector.isIap;

  MembershipState copyWith({
    QuotaInfo? quota,
    PlanType? selectedPlan,
    PaymentChannel? channel,
    bool? isLoading,
    int? totalScenes,
    String? successMessage,
    bool clearSuccess = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MembershipState(
      quota: quota ?? this.quota,
      selectedPlan: selectedPlan ?? this.selectedPlan,
      channel: channel ?? this.channel,
      isLoading: isLoading ?? this.isLoading,
      totalScenes: totalScenes ?? this.totalScenes,
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class MembershipNotifier extends StateNotifier<MembershipState> {
  final PaymentDataSource _paymentDs;
  final Ref _ref;
  bool _cancelled = false;
  bool _initialized = false;

  MembershipNotifier(this._ref, this._paymentDs) : super(const MembershipState());

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    await Future.wait([
      _loadSceneStats(),
      loadQuota(),
    ]);
  }

  Future<void> _loadSceneStats() async {
    try {
      final scenes = await _ref.read(sceneListProvider.future);
      if (!mounted) return;
      state = state.copyWith(totalScenes: scenes.length);
    } catch (e) {
      debugPrint('[Membership] _loadSceneStats error: $e');
    }
  }

  Future<void> loadQuota() async {
    try {
      final quota = await _paymentDs.getMyQuota();
      state = state.copyWith(quota: quota);
    } catch (e) {
      debugPrint('[Membership] loadQuota error: $e');
    }
  }

  void selectPlan(PlanType plan) {
    state = state.copyWith(selectedPlan: plan, clearError: true, clearSuccess: true);
  }

  void selectChannel(PaymentChannel ch) {
    state = state.copyWith(channel: ch, clearError: true, clearSuccess: true);
  }

  void cancelSubscribe() {
    _cancelled = true;
    state = state.copyWith(isLoading: false);
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  /// 订阅 — 自动分流 IAP / 在线支付
  Future<PaymentLaunchResult?> subscribe() async {
    _cancelled = false;
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      if (state.isIap) {
        return await _subscribeIap();
      } else {
        return await _subscribeOnline();
      }
    } catch (e) {
      debugPrint('[Membership] subscribe error: $e');
      if (mounted) state = state.copyWith(isLoading: false, errorMessage: '下单失败，请重试');
      return null;
    }
  }

  /// IAP 支付流程
  Future<PaymentLaunchResult?> _subscribeIap() async {
    final notifier = _ref.read(paymentProvider.notifier);
    final success = await notifier.iapPurchase(
      productId: state.selectedPlan.productId,
      channel: state.channel,
    );
    if (!mounted) return null;

    if (success) {
      await loadQuota();
      _invalidateGlobalQuota();
      state = state.copyWith(
        isLoading: false,
        successMessage: '订阅成功！已激活${state.selectedPlan.label}',
      );
    } else {
      final error = _ref.read(paymentProvider).error;
      state = state.copyWith(
        isLoading: false,
        errorMessage: error ?? '支付未完成',
      );
    }
    return null;
  }

  /// 在线支付流程
  Future<PaymentLaunchResult?> _subscribeOnline() async {
    final notifier = _ref.read(paymentProvider.notifier);
    final order = await notifier.createOrder(
      channel: state.channel,
      productId: state.selectedPlan.productId,
    );

    _pollOrder(order.orderNo);

    return PaymentLaunchResult(
      payUrl: order.payUrl,
      payParams: order.payParams,
    );
  }

  /// 后台轮询订单状态
  Future<void> _pollOrder(String orderNo) async {
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || _cancelled) return;
      try {
        final updated = await _paymentDs.getOrder(orderNo);
        if (updated.isPaid) {
          await loadQuota();
          _invalidateGlobalQuota();
          state = state.copyWith(
            isLoading: false,
            successMessage: '订阅成功！已激活${state.selectedPlan.label}',
          );
          return;
        }
        if (!updated.isPending) return;
      } catch (e) {
        debugPrint('[Membership] poll order error: $e');
        if (i >= 5) break;
      }
    }
    if (mounted) state = state.copyWith(isLoading: false, errorMessage: '支付确认超时，请稍后查看会员状态');
  }

  /// 恢复购买
  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final notifier = _ref.read(paymentProvider.notifier);
      final orders = await notifier.restorePurchases();
      await loadQuota();
      _invalidateGlobalQuota();

      final restored = orders.where((o) => o.isPaid).length;
      if (!mounted) return;

      if (restored > 0) {
        state = state.copyWith(
          isLoading: false,
          successMessage: '已恢复 $restored 笔购买记录',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '未找到可恢复的购买记录',
        );
      }
    } catch (e) {
      debugPrint('[Membership] restorePurchases error: $e');
      if (mounted) state = state.copyWith(isLoading: false, errorMessage: '恢复购买失败，请重试');
    }
  }

  void _invalidateGlobalQuota() {
    _ref.invalidate(quotaProvider);
  }
}

/// 全局唯一配额状态 — 供 profile/usage 等模块共用
class QuotaState {
  final QuotaInfo? data;
  final bool isLoading;
  final String? error;

  const QuotaState({this.data, this.isLoading = false, this.error});

  QuotaState copyWith({QuotaInfo? data, bool? isLoading, String? error}) {
    return QuotaState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isPro => data?.isPro ?? false;
}

class QuotaNotifier extends StateNotifier<QuotaState> {
  final PaymentDataSource _ds;

  QuotaNotifier(this._ds) : super(const QuotaState()) {
    loadQuota();
  }

  Future<void> loadQuota() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final quota = await _ds.getMyQuota();
      if (!mounted) return;
      state = state.copyWith(data: quota, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadQuota();
  }
}

/// 全局配额 Provider — 统一入口，替代旧 profile/quota_provider 和 payment/quotaProvider
final quotaProvider = StateNotifierProvider<QuotaNotifier, QuotaState>((ref) {
  return QuotaNotifier(PaymentDataSource());
});

final membershipProvider =
    StateNotifierProvider<MembershipNotifier, MembershipState>((ref) {
  final paymentDs = PaymentDataSource();
  return MembershipNotifier(ref, paymentDs);
});
