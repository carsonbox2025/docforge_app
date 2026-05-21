/// 套餐类型
enum PlanType {
  monthly('monthly', 'Pro 月度会员', '¥9.9', '/月', 9.9, 1),
  yearly('yearly', 'Pro 年度会员', '¥99', '/年', 99, 12),
  lifetime('lifetime', '终身会员', '¥499', '', 499, -1);

  const PlanType(this.code, this.label, this.price, this.period, this.priceNum, this.months);

  final String code;
  final String label;
  final String price;
  final String period;
  final double priceNum;
  final int months;

  String get displayPrice => '$price$period';
}

/// 权益项
class BenefitItem {
  final String name;
  final String freeValue;
  final String proValue;
  final bool isFreeChecked;
  final bool isProChecked;

  const BenefitItem({
    required this.name,
    required this.freeValue,
    required this.proValue,
    this.isFreeChecked = false,
    this.isProChecked = true,
  });
}

/// 用户会员状态
class MembershipStatus {
  final bool isPro;
  final PlanType currentPlan;
  final String? expireDate;
  final bool isExpired;

  const MembershipStatus({
    this.isPro = false,
    this.currentPlan = PlanType.yearly,
    this.expireDate,
    this.isExpired = false,
  });
}
