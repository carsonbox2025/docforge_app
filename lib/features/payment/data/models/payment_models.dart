// 支付模块数据模型 — 对接后端 OrderService

enum PaymentChannel { alipay, wechat }

enum OrderStatus { pending, paid, refunded, expired }

class CreateOrderRequest {
  final String channel;
  final String? sceneId;
  final int? documentId;
  final String orderType; // per_doc / membership

  const CreateOrderRequest({
    required this.channel,
    this.sceneId,
    this.documentId,
    required this.orderType,
  });

  Map<String, dynamic> toJson() => {
        'channel': channel,
        if (sceneId != null) 'scene_id': sceneId,
        if (documentId != null) 'document_id': documentId,
        'order_type': orderType,
      };
}

class OrderRecord {
  final String orderNo;
  final int amountCents;
  final String status;
  final String? paidAt;
  final String? payUrl;

  const OrderRecord({
    required this.orderNo,
    required this.amountCents,
    required this.status,
    this.paidAt,
    this.payUrl,
  });

  factory OrderRecord.fromJson(Map<String, dynamic> json) => OrderRecord(
        orderNo: json['order_no'] as String? ?? '',
        amountCents: json['amount_cents'] as int? ?? 0,
        status: json['status'] as String? ?? 'pending',
        paidAt: json['paid_at'] as String?,
        payUrl: json['pay_url'] as String?,
      );

  String get displayAmount =>
      '¥${(amountCents / 100).toStringAsFixed(amountCents % 100 == 0 ? 0 : 1)}';
  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
}

class QuotaInfo {
  final String planType;
  final String? expiresAt;
  final Map<String, int> quotas;
  final Map<String, int> used;
  final Map<String, int> dailyQuotas;
  final Map<String, int> dailyUsed;

  const QuotaInfo({
    required this.planType,
    this.expiresAt,
    this.quotas = const {},
    this.used = const {},
    this.dailyQuotas = const {},
    this.dailyUsed = const {},
  });

  factory QuotaInfo.fromJson(Map<String, dynamic> json) {
    Map<String, int> parseMap(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v is int ? v : int.tryParse(v.toString()) ?? 0)));
      }
      return {};
    }

    return QuotaInfo(
      planType: json['plan_type'] as String? ?? 'free',
      expiresAt: json['expires_at'] as String?,
      quotas: parseMap(json['quotas']),
      used: parseMap(json['used']),
      dailyQuotas: parseMap(json['daily_quotas']),
      dailyUsed: parseMap(json['daily_used']),
    );
  }

  /// 月配额剩余（-1 = 不限）
  int monthlyRemaining(String sceneId) {
    final limit = quotas[sceneId] ?? 0;
    if (limit == -1) return -1;
    return limit - (used[sceneId] ?? 0);
  }

  /// 日配额剩余（日限不存在 = 不限）
  int dailyRemaining(String sceneId) {
    final limit = dailyQuotas[sceneId];
    if (limit == null) return -1; // 无日限
    return limit - (dailyUsed[sceneId] ?? 0);
  }

  /// 综合剩余 = min(日剩余, 月剩余)，任一为 -1 则取另一个
  int remaining(String sceneId) {
    final dr = dailyRemaining(sceneId);
    final mr = monthlyRemaining(sceneId);
    if (dr == -1) return mr;
    if (mr == -1) return dr;
    return dr < mr ? dr : mr;
  }

  /// 日配额是否耗尽
  bool isDailyExhausted(String sceneId) {
    final dr = dailyRemaining(sceneId);
    return dr != -1 && dr <= 0;
  }

  /// 月配额是否耗尽
  bool isMonthlyExhausted(String sceneId) {
    final mr = monthlyRemaining(sceneId);
    return mr != -1 && mr <= 0;
  }

  bool get isYearly => planType == 'yearly';
  bool get isPro => planType != 'free';

  String get planLabel => switch (planType) {
        'free' => '免费版',
        'monthly' => '月度会员',
        'yearly' => '年度会员',
        _ => planType,
      };

  Map<String, dynamic> toJson() => {
        'plan_type': planType,
        'expires_at': expiresAt,
        'quotas': quotas,
        'used': used,
        'daily_quotas': dailyQuotas,
        'daily_used': dailyUsed,
      };
}
