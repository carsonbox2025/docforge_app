package com.example.docforge_app

import android.app.Activity
import android.util.Log
import android.content.Intent
import com.huawei.hms.iap.Iap
import com.huawei.hms.iap.IapApiException
import com.huawei.hms.iap.IapClient
import com.huawei.hms.iap.entity.ConsumeOwnedPurchaseReq
import com.huawei.hms.iap.entity.OwnedPurchasesReq
import com.huawei.hms.iap.entity.OrderStatusCode
import com.huawei.hms.iap.entity.ProductInfoReq
import com.huawei.hms.iap.entity.ProductInfoResult
import com.huawei.hms.iap.entity.PurchaseIntentReq
import com.huawei.hms.iap.entity.PurchaseIntentResult
import com.huawei.hms.iap.entity.PurchaseResultInfo
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONObject

class HuaweiIapHandler(
    private val activity: Activity,
) {
    private val iapClient: IapClient = Iap.getIapClient(activity)
    private var pendingResult: Result? = null

    companion object {
        private const val REQ_CODE_BUY = 8001
        private const val TAG = "HuaweiIAP"
        private var cachedResult: Map<String, Any>? = null

        fun takeCachedResult(): Map<String, Any>? {
            val r = cachedResult
            cachedResult = null
            return r
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQ_CODE_BUY) return false
        val result = pendingResult
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            val map = mapOf("success" to false, "error" to "用户取消支付")
            if (result != null) {
                result.success(map)
            } else {
                cachedResult = map
            }
            return true
        }

        val purchaseResultInfo: PurchaseResultInfo =
            Iap.getIapClient(activity).parsePurchaseResultInfoFromIntent(data)

        when (purchaseResultInfo.returnCode) {
            OrderStatusCode.ORDER_STATE_SUCCESS -> {
                val purchaseData = purchaseResultInfo.inAppPurchaseData
                val signature = purchaseResultInfo.inAppDataSignature
                val purchaseToken = try {
                    JSONObject(purchaseData).optString("purchaseToken", "")
                } catch (e: Exception) {
                    ""
                }

                if (purchaseToken.isEmpty()) {
                    val map = mapOf("success" to false, "error" to "无法解析 purchaseToken")
                    if (result != null) {
                        result.success(map)
                    } else {
                        cachedResult = map
                    }
                    return true
                }

                val map = mapOf(
                    "success" to true,
                    "receiptData" to purchaseToken,
                    "purchaseData" to purchaseData,
                    "signature" to signature,
                )
                if (result != null) {
                    result.success(map)
                } else {
                    cachedResult = map
                }
            }
            OrderStatusCode.ORDER_STATE_CANCEL -> {
                val map = mapOf("success" to false, "error" to "用户取消")
                if (result != null) {
                    result.success(map)
                } else {
                    cachedResult = map
                }
            }
            else -> {
                val map = mapOf(
                    "success" to false,
                    "error" to "支付失败(code=${purchaseResultInfo.returnCode}): ${purchaseResultInfo.errMsg}",
                )
                if (result != null) {
                    result.success(map)
                } else {
                    cachedResult = map
                }
            }
        }
        return true
    }

    fun queryProducts(call: MethodCall, result: Result) {
        val productIds = call.argument<List<String>>("productIds") ?: emptyList()
        val productType = call.argument<String>("productType") ?: "consumable"
        Log.i(TAG, "queryProducts: ids=$productIds, type=$productType")
        if (productIds.isEmpty()) {
            result.success(emptyList<Any>())
            return
        }

        val req = ProductInfoReq()
        req.priceType = mapPriceType(productType)
        req.productIds = productIds

        iapClient.obtainProductInfo(req)
            .addOnSuccessListener { productInfoResult: ProductInfoResult ->
                val products = productInfoResult.productInfoList?.map { info ->
                    mapOf(
                        "productId" to info.productId,
                        "name" to info.productName,
                        "priceCents" to info.microsPrice.div(10000),
                        "currency" to info.currency,
                    )
                } ?: emptyList()
                result.success(products)
            }
            .addOnFailureListener { e ->
                val msg = if (e is IapApiException) e.message else e.message
                result.error("IAP_ERROR", "查询商品失败: $msg", null)
            }
    }

    fun launchPayFlow(call: MethodCall, result: Result) {
        val cached = takeCachedResult()
        if (cached != null) {
            Log.i(TAG, "launchPayFlow: returning cached result")
            result.success(cached)
            return
        }

        val productId = call.argument<String>("productId") ?: ""
        val orderNo = call.argument<String>("orderNo") ?: ""
        val productType = call.argument<String>("productType") ?: "consumable"
        Log.i(TAG, "launchPayFlow: productId=$productId, orderNo=$orderNo, type=$productType")

        val req = PurchaseIntentReq()
        req.priceType = mapPriceType(productType)
        req.productId = productId
        req.developerPayload = orderNo

        iapClient.createPurchaseIntent(req)
            .addOnSuccessListener { purchaseIntentResult: PurchaseIntentResult ->
                val status = purchaseIntentResult.status
                if (status.hasResolution()) {
                    pendingResult = result
                    try {
                        status.startResolutionForResult(activity, REQ_CODE_BUY)
                    } catch (e: Exception) {
                        pendingResult = null
                        result.error("IAP_ERROR", "无法启动支付页面: ${e.message}", null)
                    }
                } else {
                    result.error("IAP_ERROR", "支付不可用", null)
                }
            }
            .addOnFailureListener { e ->
                if (e is IapApiException) {
                    Log.e(TAG, "launchPayFlow failed: statusCode=${e.statusCode}, msg=${e.message}")
                    when (e.statusCode) {
                        OrderStatusCode.ORDER_PRODUCT_OWNED,
                        60056 -> {
                            // 已购买未消耗 → obtainOwnedPurchases 查未完成订单
                            Log.w(TAG, "ALREADY_OWNED: 用 obtainOwnedPurchases 查询未确认订单...")
                            queryAndReturnOwnedPurchase(req.priceType, result)
                        }
                        OrderStatusCode.ORDER_STATE_CANCEL -> {
                            result.success(mapOf("success" to false, "error" to "用户取消"))
                        }
                        else -> {
                            result.error("IAP_ERROR", "支付失败(${e.statusCode}): ${e.message}", null)
                        }
                    }
                } else {
                    Log.e(TAG, "launchPayFlow error: ${e.message}")
                    result.error("IAP_ERROR", "创建支付意图失败: ${e.message}", null)
                }
            }
    }

    /**
     * ALREADY_OWNED 时：obtainOwnedPurchases 查未确认订单 → obtainOwnedPurchaseRecord 查历史
     */
    private fun queryAndReturnOwnedPurchase(priceType: Int, result: Result) {
        val req = OwnedPurchasesReq()
        req.priceType = priceType
        try {
            iapClient.obtainOwnedPurchases(req)
                .addOnSuccessListener { purchaseResult ->
                    val records = purchaseResult.inAppPurchaseDataList
                    Log.w(TAG, "obtainOwnedPurchases 返回: ${records?.size ?: 0} 条未确认订单")
                    if (!records.isNullOrEmpty()) {
                        val first = records[0]
                        val json = JSONObject(first)
                        val token = json.optString("purchaseToken", "")
                        val pid = json.optString("productId", "")
                        Log.w(TAG, "obtainOwnedPurchases 命中: productId=$pid, token=${token.take(15)}...")
                        if (token.isNotEmpty()) {
                            result.success(mapOf(
                                "success" to true,
                                "receiptData" to token,
                                "purchaseData" to first,
                                "signature" to "",
                                "isRecovered" to true,
                            ))
                        } else {
                            queryOwnedPurchaseRecord(priceType, result)
                        }
                    } else {
                        Log.w(TAG, "obtainOwnedPurchases 无结果，尝试 obtainOwnedPurchaseRecord...")
                        queryOwnedPurchaseRecord(priceType, result)
                    }
                }
                .addOnFailureListener { e ->
                    Log.e(TAG, "obtainOwnedPurchases 失败: ${(e as? IapApiException)?.statusCode} ${e.message}")
                    queryOwnedPurchaseRecord(priceType, result)
                }
        } catch (e: Exception) {
            Log.e(TAG, "obtainOwnedPurchases 异常: ${e.message}")
            queryOwnedPurchaseRecord(priceType, result)
        }
    }

    private fun queryOwnedPurchaseRecord(priceType: Int, result: Result) {
        val req = OwnedPurchasesReq()
        req.priceType = priceType
        iapClient.obtainOwnedPurchaseRecord(req)
            .addOnSuccessListener { ownedResult ->
                val records = ownedResult.inAppPurchaseDataList
                Log.w(TAG, "obtainOwnedPurchaseRecord 返回: ${records?.size ?: 0} 条记录")
                val record = records?.firstOrNull()
                if (record != null) {
                    try {
                        val json = JSONObject(record)
                        val token = json.optString("purchaseToken", "")
                        Log.w(TAG, "obtainOwnedPurchaseRecord 命中: productId=${json.optString("productId")}")
                        if (token.isNotEmpty()) {
                            result.success(mapOf(
                                "success" to true,
                                "receiptData" to token,
                                "purchaseData" to record,
                                "signature" to "",
                                "isRecovered" to true,
                            ))
                        } else {
                            result.error("ALREADY_OWNED", "已购记录中无 purchaseToken", null)
                        }
                    } catch (ex: Exception) {
                        result.error("ALREADY_OWNED", "解析已购记录失败: ${ex.message}", null)
                    }
                } else {
                    result.error("ALREADY_OWNED", "已购买但查询不到购买记录，请在华为钱包中确认", null)
                }
            }
            .addOnFailureListener { queryErr ->
                result.error("ALREADY_OWNED", "查询已购记录失败: ${queryErr.message}", null)
            }
    }

    fun consumePurchase(call: MethodCall, result: Result) {
        val purchaseToken = call.argument<String>("purchaseToken") ?: ""
        Log.i(TAG, "consumePurchase: token=${purchaseToken.take(15)}...")
        if (purchaseToken.isEmpty()) {
            result.success(false)
            return
        }

        val req = ConsumeOwnedPurchaseReq()
        req.purchaseToken = purchaseToken

        iapClient.consumeOwnedPurchase(req)
            .addOnSuccessListener {
                Log.i(TAG, "consumePurchase 成功")
                result.success(true)
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "consumePurchase 失败: ${(e as? IapApiException)?.statusCode} ${e.message}")
                result.success(false)
            }
    }

    /**
     * 查询未确认/未消耗订单（obtainOwnedPurchases） — 恢复购买时优先使用
     */
    fun queryPendingPurchases(call: MethodCall, result: Result) {
        val productType = call.argument<String>("productType") ?: "consumable"
        val priceType = mapPriceType(productType)
        Log.w(TAG, "═══ queryPendingPurchases: productType=$productType, priceType=$priceType")

        val req = OwnedPurchasesReq()
        req.priceType = priceType

        iapClient.obtainOwnedPurchases(req)
            .addOnSuccessListener { purchaseResult ->
                val data = purchaseResult.inAppPurchaseDataList
                Log.w(TAG, "obtainOwnedPurchases OK: ${data?.size ?: 0} 条未确认订单")
                val items = data?.mapNotNull { purchaseDataStr ->
                    parsePurchaseRecord(purchaseDataStr)
                } ?: emptyList()
                result.success(items)
            }
            .addOnFailureListener { e ->
                val code = (e as? IapApiException)?.statusCode ?: -1
                Log.e(TAG, "obtainOwnedPurchases 失败: code=$code, msg=${e.message}")
                result.error("IAP_QUERY_ERROR", "查询未确认订单失败($code): ${e.message}", null)
            }
    }

    fun restorePurchases(call: MethodCall, result: Result) {
        val productType = call.argument<String>("productType") ?: "subscription"
        val priceType = mapPriceType(productType)
        Log.w(TAG, "═══ restorePurchases: productType=$productType, priceType=$priceType")

        val req = OwnedPurchasesReq()
        req.priceType = priceType

        iapClient.obtainOwnedPurchaseRecord(req)
            .addOnSuccessListener { ownedPurchasesResult ->
                val data = ownedPurchasesResult.inAppPurchaseDataList
                Log.w(TAG, "obtainOwnedPurchaseRecord OK: ${data?.size ?: 0} records")
                val items = data?.mapNotNull { purchaseDataStr ->
                    parsePurchaseRecord(purchaseDataStr)
                } ?: emptyList()
                result.success(items)
            }
            .addOnFailureListener { e ->
                if (e is IapApiException) {
                    Log.e(TAG, "obtainOwnedPurchaseRecord failed: statusCode=${e.statusCode}, msg=${e.message}")
                    result.error("IAP_RESTORE_ERROR", "查询已购记录失败(${e.statusCode}): ${e.message}", null)
                } else {
                    Log.e(TAG, "obtainOwnedPurchaseRecord error: ${e.message}")
                    result.error("IAP_RESTORE_ERROR", "查询已购记录失败: ${e.message}", null)
                }
            }
    }

    private fun parsePurchaseRecord(purchaseDataStr: String): Map<String, Any>? {
        return try {
            val json = JSONObject(purchaseDataStr)
            val purchaseToken = json.optString("purchaseToken", "")
            val productId = json.optString("productId", "")
            val purchaseState = json.optInt("purchaseState", -1)
            Log.i(TAG, "  record: productId=$productId, state=$purchaseState, token=${purchaseToken.take(10)}...")
            if (purchaseToken.isNotEmpty() && productId.isNotEmpty()) {
                mapOf(
                    "purchaseToken" to purchaseToken,
                    "productId" to productId,
                    "purchaseData" to purchaseDataStr,
                    "purchaseState" to purchaseState,
                )
            } else null
        } catch (e: Exception) {
            Log.w(TAG, "  parse record failed: ${e.message}")
            null
        }
    }

    private fun mapPriceType(productType: String): Int {
        return when (productType) {
            "consumable" -> IapClient.PriceType.IN_APP_CONSUMABLE
            "non_consumable" -> IapClient.PriceType.IN_APP_NONCONSUMABLE
            "subscription" -> IapClient.PriceType.IN_APP_SUBSCRIPTION
            else -> IapClient.PriceType.IN_APP_CONSUMABLE
        }
    }
}
