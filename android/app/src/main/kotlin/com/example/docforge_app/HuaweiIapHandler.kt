package com.example.docforge_app

import android.app.Activity
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
            cachedResult = map
            result?.success(map)
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
                    cachedResult = map
                    result?.success(map)
                    return true
                }

                val map = mapOf(
                    "success" to true,
                    "receiptData" to purchaseToken,
                    "purchaseData" to purchaseData,
                    "signature" to signature,
                )
                cachedResult = map
                result?.success(map)
            }
            OrderStatusCode.ORDER_STATE_CANCEL -> {
                val map = mapOf("success" to false, "error" to "用户取消")
                cachedResult = map
                result?.success(map)
            }
            else -> {
                val map = mapOf(
                    "success" to false,
                    "error" to "支付失败(code=${purchaseResultInfo.returnCode}): ${purchaseResultInfo.errMsg}",
                )
                cachedResult = map
                result?.success(map)
            }
        }
        return true
    }

    fun queryProducts(call: MethodCall, result: Result) {
        val productIds = call.argument<List<String>>("productIds") ?: emptyList()
        val productType = call.argument<String>("productType") ?: "consumable"
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
        // 如果有缓存的支付结果（Activity 重建场景），直接返回
        val cached = takeCachedResult()
        if (cached != null) {
            result.success(cached)
            return
        }

        val productId = call.argument<String>("productId") ?: ""
        val orderNo = call.argument<String>("orderNo") ?: ""
        val productType = call.argument<String>("productType") ?: "consumable"

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
                    when (e.statusCode) {
                        OrderStatusCode.ORDER_PRODUCT_OWNED,
                        60056 -> {
                            // 60051: 已购买非消耗品; 60056: 已订阅
                            result.error("ALREADY_OWNED", "您已购买此商品，请点击\"恢复购买\"完成激活", null)
                        }
                        OrderStatusCode.ORDER_STATE_CANCEL -> {
                            result.success(mapOf("success" to false, "error" to "用户取消"))
                        }
                        else -> {
                            result.error("IAP_ERROR", "支付失败(${e.statusCode}): ${e.message}", null)
                        }
                    }
                } else {
                    result.error("IAP_ERROR", "创建支付意图失败: ${e.message}", null)
                }
            }
    }

    fun consumePurchase(call: MethodCall, result: Result) {
        val purchaseToken = call.argument<String>("purchaseToken") ?: ""
        if (purchaseToken.isEmpty()) {
            result.success(false)
            return
        }

        val req = ConsumeOwnedPurchaseReq()
        req.purchaseToken = purchaseToken

        iapClient.consumeOwnedPurchase(req)
            .addOnSuccessListener { result.success(true) }
            .addOnFailureListener { result.success(false) }
    }

    fun restorePurchases(call: MethodCall, result: Result) {
        val productType = call.argument<String>("productType") ?: "subscription"

        val req = OwnedPurchasesReq()
        req.priceType = mapPriceType(productType)

        iapClient.obtainOwnedPurchaseRecord(req)
            .addOnSuccessListener { ownedPurchasesResult ->
                val items = ownedPurchasesResult.inAppPurchaseDataList?.mapNotNull { purchaseDataStr ->
                    try {
                        val json = JSONObject(purchaseDataStr)
                        val purchaseToken = json.optString("purchaseToken", "")
                        val productId = json.optString("productId", "")
                        val purchaseState = json.optInt("purchaseState", -1)
                        if (purchaseToken.isNotEmpty() && productId.isNotEmpty()) {
                            mapOf(
                                "purchaseToken" to purchaseToken,
                                "productId" to productId,
                                "purchaseData" to purchaseDataStr,
                                "purchaseState" to purchaseState,
                            )
                        } else null
                    } catch (e: Exception) {
                        null
                    }
                } ?: emptyList()
                result.success(items)
            }
            .addOnFailureListener { e ->
                val msg = if (e is IapApiException) "obtainOwnedPurchaseRecord failed(${e.statusCode}): ${e.message}" else e.message
                result.error("IAP_RESTORE_ERROR", msg, null)
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
