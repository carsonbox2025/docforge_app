import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/membership_models.dart';

class MembershipState {
  final MembershipStatus status;
  final PlanType selectedPlan;
  final bool isLoading;
  final List<BenefitItem> benefits;

  const MembershipState({
    this.status = const MembershipStatus(
      isPro: true,
      currentPlan: PlanType.yearly,
      expireDate: '2026-12-31',
      isExpired: false,
    ),
    this.selectedPlan = PlanType.yearly,
    this.isLoading = false,
    this.benefits = const [
      BenefitItem(name: '生成次数', freeValue: '3次/月', proValue: '∞', isFreeChecked: true, isProChecked: true),
      BenefitItem(name: '模板库', freeValue: '基础模板', proValue: '50+模板', isFreeChecked: true, isProChecked: true),
      BenefitItem(name: '文档精修', freeValue: '1次/月', proValue: '∞', isFreeChecked: true, isProChecked: true),
      BenefitItem(name: '多语言翻译', freeValue: '—', proValue: '6种语言', isFreeChecked: false, isProChecked: true),
      BenefitItem(name: '合规检查', freeValue: '—', proValue: '√', isFreeChecked: false, isProChecked: true),
      BenefitItem(name: '导出格式', freeValue: 'Word', proValue: 'Word/PDF/HTML', isFreeChecked: true, isProChecked: true),
      BenefitItem(name: 'AI响应速度', freeValue: '标准', proValue: '优先', isFreeChecked: true, isProChecked: true),
      BenefitItem(name: '专属客服', freeValue: '—', proValue: '7×24h', isFreeChecked: false, isProChecked: true),
    ],
  });

  String get ctaLabel => '立即续费 · ${selectedPlan.price}/年';
  String get ctaPrice => selectedPlan.price;

  MembershipState copyWith({
    MembershipStatus? status,
    PlanType? selectedPlan,
    bool? isLoading,
  }) {
    return MembershipState(
      status: status ?? this.status,
      selectedPlan: selectedPlan ?? this.selectedPlan,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class MembershipNotifier extends StateNotifier<MembershipState> {
  MembershipNotifier() : super(const MembershipState());

  void selectPlan(PlanType plan) {
    state = state.copyWith(selectedPlan: plan);
  }

  Future<void> subscribe() async {
    state = state.copyWith(isLoading: true);
    // Simulate payment flow
    await Future.delayed(const Duration(seconds: 2));
    state = state.copyWith(isLoading: false);
  }
}

final membershipProvider =
    StateNotifierProvider<MembershipNotifier, MembershipState>((ref) {
  return MembershipNotifier();
});
