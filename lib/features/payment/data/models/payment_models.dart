// 支付模块数据模型 — 对接后端统一支付模块 (modules/payment)

enum PaymentChannel {
  huawei,
  xiaomi,
  oppo,
  vivo,
  honor,
  alipay,
  wechat;

  bool get isIap =>
      this == huawei ||
      this == xiaomi ||
      this == oppo ||
      this == vivo ||
      this == honor;
}

enum OrderStatus { pending, verifying, paid, delivered, cancelled, refunded, expired, closed }

enum ProductType { consumable, nonConsumable, subscription }

class Product {
  final String productId;
  final String productType;
  final String name;
  final int priceCents;
  final String currency;
  final String? period; // monthly / yearly

  const Product({
    required this.productId,
    required this.productType,
    required this.name,
    required this.priceCents,
    this.currency = 'CNY',
    this.period,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        productId: json['product_id'] as String? ?? '',
        productType: json['product_type'] as String? ?? 'consumable',
        name: json['name'] as String? ?? '',
        priceCents: json['price_cents'] as int? ?? 0,
        currency: json['currency'] as String? ?? 'CNY',
        period: json['period'] as String?,
      );

  String get periodLabel => switch (period) {
        'monthly' => '/月',
        'yearly' => '/年',
        _ => priceCents >= 5000 ? '/年' : '/月',
      };

  String get displayPrice =>
      '¥${(priceCents / 100).toStringAsFixed(2)}';
}

class CreateOrderRequest {
  final String appKey;
  final String channel;
  final String productId;
  final bool sandbox;

  const CreateOrderRequest({
    required this.appKey,
    required this.channel,
    required this.productId,
    this.sandbox = false,
  });

  Map<String, dynamic> toJson() => {
        'app_key': appKey,
        'channel': channel,
        'product_id': productId,
        'sandbox': sandbox,
      };
}

class VerifyRequest {
  final String appKey;
  final String receiptData;

  const VerifyRequest({required this.appKey, required this.receiptData});

  Map<String, dynamic> toJson() => {
        'app_key': appKey,
        'receipt_data': receiptData,
      };
}

class OrderRecord {
  final String orderNo;
  final String productId;
  final String productType;
  final int amountCents;
  final String status;
  final String channel;
  final String? payUrl;
  final Map<String, String>? payParams;
  final String? paidAt;
  final String? createdAt;

  const OrderRecord({
    required this.orderNo,
    this.productId = '',
    this.productType = 'consumable',
    required this.amountCents,
    required this.status,
    this.channel = 'alipay',
    this.payUrl,
    this.payParams,
    this.paidAt,
    this.createdAt,
  });

  factory OrderRecord.fromJson(Map<String, dynamic> json) => OrderRecord(
        orderNo: json['order_no'] as String? ?? '',
        productId: json['product_id'] as String? ?? '',
        productType: json['product_type'] as String? ?? 'consumable',
        amountCents: json['amount_cents'] as int? ?? 0,
        status: json['status'] as String? ?? 'pending',
        channel: json['channel'] as String? ?? 'alipay',
        payUrl: json['pay_url'] as String?,
        payParams: (json['pay_params'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())),
        paidAt: json['paid_at'] as String?,
        createdAt: json['created_at'] as String?,
      );

  String get displayAmount =>
      '¥${(amountCents / 100).toStringAsFixed(2)}';
  bool get isPaid => status == 'paid' || status == 'delivered';
  bool get isPending => status == 'pending' || status == 'verifying';
  bool get isVerifying => status == 'verifying';
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
        return raw.map((k, v) =>
            MapEntry(k.toString(), (v is int ? v : int.tryParse(v.toString()) ?? 0)));
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

  int monthlyRemaining(String sceneId) {
    final limit = quotas[sceneId] ?? 0;
    if (limit == -1) return -1;
    return limit - (used[sceneId] ?? 0);
  }

  int dailyRemaining(String sceneId) {
    final limit = dailyQuotas[sceneId];
    if (limit == null) return -1;
    return limit - (dailyUsed[sceneId] ?? 0);
  }

  int remaining(String sceneId) {
    final dr = dailyRemaining(sceneId);
    final mr = monthlyRemaining(sceneId);
    if (dr == -1) return mr;
    if (mr == -1) return dr;
    return dr < mr ? dr : mr;
  }

  bool isDailyExhausted(String sceneId) {
    final dr = dailyRemaining(sceneId);
    return dr != -1 && dr <= 0;
  }

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
        'lifetime' => '终身会员',
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
