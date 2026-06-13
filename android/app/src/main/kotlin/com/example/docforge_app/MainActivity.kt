package com.example.docforge_app

import android.content.Context
import android.content.Intent
import android.os.Build
import com.huawei.agconnect.AGConnectInstance
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.docforge.app/iap"
    private var huaweiHandler: HuaweiIapHandler? = null
    private var huaweiUpdateHandler: HuaweiUpdateHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val channel = call.argument<String>("channel") ?: "official"
                val handler = getOrCreateHandler(channel)
                when (call.method) {
                    "getInstallerPackageName" -> {
                        result.success(getInstallerPackageName(applicationContext))
                    }
                    "queryProducts" -> {
                        if (handler != null) {
                            handler.queryProducts(call, result)
                        } else {
                            result.error("NO_HANDLER", "当前渠道不支持 IAP: $channel", null)
                        }
                    }
                    "launchPayFlow" -> {
                        if (handler != null) {
                            handler.launchPayFlow(call, result)
                        } else {
                            result.error("NO_HANDLER", "当前渠道不支持 IAP: $channel", null)
                        }
                    }
                    "consumePurchase" -> {
                        if (handler != null) {
                            handler.consumePurchase(call, result)
                        } else {
                            result.success(false)
                        }
                    }
                    "restorePurchases" -> {
                        if (handler != null) {
                            handler.restorePurchases(call, result)
                        } else {
                            result.success(emptyList<Any>())
                        }
                    }
                    "queryPendingPurchases" -> {
                        if (handler != null) {
                            handler.queryPendingPurchases(call, result)
                        } else {
                            result.success(emptyList<Any>())
                        }
                    }
                    "checkUpdate" -> {
                        if (channel == "huawei") {
                            getOrCreateUpdateHandler()?.checkUpdate(result)
                        } else {
                            result.success(mapOf("hasUpdate" to false))
                        }
                    }
                    "performUpdate" -> {
                        if (channel == "huawei") {
                            getOrCreateUpdateHandler()?.performUpdate(result)
                        } else {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getOrCreateHandler(channel: String): HuaweiIapHandler? {
        if (channel != "huawei") return null
        if (huaweiHandler != null) return huaweiHandler
        return try {
            AGConnectInstance.initialize(applicationContext)
            huaweiHandler = HuaweiIapHandler(this)
            huaweiHandler
        } catch (e: Exception) {
            null
        }
    }

    private fun getOrCreateUpdateHandler(): HuaweiUpdateHandler? {
        if (huaweiUpdateHandler != null) return huaweiUpdateHandler
        return try {
            AGConnectInstance.initialize(applicationContext)
            huaweiUpdateHandler = HuaweiUpdateHandler(this)
            huaweiUpdateHandler
        } catch (e: Exception) {
            null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        huaweiHandler?.onActivityResult(requestCode, resultCode, data)
    }

    private fun getInstallerPackageName(context: Context): String {
        return try {
            val pm = context.packageManager
            val packageName = context.packageName
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                pm.getInstallSourceInfo(packageName).installingPackageName ?: ""
            } else {
                @Suppress("DEPRECATION")
                pm.getInstallerPackageName(packageName) ?: ""
            }
        } catch (e: Exception) {
            ""
        }
    }
}
