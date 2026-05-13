/// 支付模块数据模型 — 对接后端 OrderService

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

  const QuotaInfo({
    required this.planType,
    this.expiresAt,
    this.quotas = const {},
    this.used = const {},
  });

  factory QuotaInfo.fromJson(Map<String, dynamic> json) {
    final quotasRaw = json['quotas'];
    final usedRaw = json['used'];

    Map<String, int> parseMap(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v is int ? v : int.tryParse(v.toString()) ?? 0)));
      }
      return {};
    }

    return QuotaInfo(
      planType: json['plan_type'] as String? ?? 'free',
      expiresAt: json['expires_at'] as String?,
      quotas: parseMap(quotasRaw),
      used: parseMap(usedRaw),
    );
  }

  int remaining(String sceneId) =>
      (quotas[sceneId] ?? 0) - (used[sceneId] ?? 0);

  bool get isYearly => planType == 'yearly';
  bool get isPro => planType != 'free';

  String get planLabel => switch (planType) {
        'free' => '免费版',
        'monthly' => '月度会员',
        'yearly' => '年度会员',
        _ => planType,
      };
}
