package com.example.docforge_app

import android.app.Activity
import android.content.Intent
import android.util.Log
import com.huawei.hms.jos.AppUpdateClient
import com.huawei.hms.jos.JosApps
import com.huawei.updatesdk.service.appmgr.bean.ApkUpgradeInfo
import com.huawei.updatesdk.service.otaupdate.CheckUpdateCallBack
import com.huawei.updatesdk.service.otaupdate.UpdateKey
import io.flutter.plugin.common.MethodChannel.Result

class HuaweiUpdateHandler(private val activity: Activity) {

    companion object {
        private const val TAG = "HuaweiUpdate"
    }

    private val appUpdateClient: AppUpdateClient = JosApps.getAppUpdateClient(activity)

    fun checkUpdate(result: Result) {
        Log.i(TAG, "checkUpdate: start")
        appUpdateClient.checkAppUpdate(activity, object : CheckUpdateCallBack {
            override fun onUpdateInfo(intent: Intent?) {
                if (intent == null) {
                    Log.i(TAG, "checkUpdate: intent is null")
                    result.success(mapOf("hasUpdate" to false))
                    return
                }

                val status = intent.getIntExtra(UpdateKey.STATUS, -99)
                val failCode = intent.getIntExtra(UpdateKey.FAIL_CODE, -99)
                val failReason = intent.getStringExtra(UpdateKey.FAIL_REASON) ?: ""
                val isMustUpdate = intent.getBooleanExtra(UpdateKey.MUST_UPDATE, false)

                Log.i(TAG, "checkUpdate: status=$status, failCode=$failCode, reason=$failReason, isMustUpdate=$isMustUpdate")

                if (status != 0) {
                    result.success(mapOf("hasUpdate" to false, "error" to "status=$status: code=$failCode $failReason"))
                    return
                }

                val info = intent.getSerializableExtra(UpdateKey.INFO)
                if (info !is ApkUpgradeInfo) {
                    Log.i(TAG, "checkUpdate: no ApkUpgradeInfo")
                    result.success(mapOf("hasUpdate" to false))
                    return
                }

                Log.i(TAG, "checkUpdate: update found, version=${info.getVersion_()}, isMustUpdate=$isMustUpdate")
                result.success(mapOf(
                    "hasUpdate" to true,
                    "isForce" to isMustUpdate,
                    "versionName" to (info.getVersion_() ?: ""),
                    "size" to info.getSize_(),
                    "newFeatures" to (info.getNewFeatures_() ?: ""),
                ))
            }

            override fun onMarketInstallInfo(intent: Intent?) {
                Log.i(TAG, "checkUpdate: onMarketInstallInfo")
            }

            override fun onMarketStoreError(code: Int) {
                Log.e(TAG, "checkUpdate: onMarketStoreError code=$code")
                result.success(mapOf("hasUpdate" to false, "error" to "marketStore: code=$code"))
            }

            override fun onUpdateStoreError(code: Int) {
                Log.e(TAG, "checkUpdate: onUpdateStoreError code=$code")
                result.success(mapOf("hasUpdate" to false, "error" to "updateStore: code=$code"))
            }
        })
    }

    fun performUpdate(result: Result) {
        Log.i(TAG, "performUpdate: start")
        appUpdateClient.checkAppUpdate(activity, object : CheckUpdateCallBack {
            override fun onUpdateInfo(intent: Intent?) {
                if (intent == null) {
                    result.success(false)
                    return
                }

                val status = intent.getIntExtra(UpdateKey.STATUS, -99)
                if (status != 0) {
                    result.success(false)
                    return
                }

                val info = intent.getSerializableExtra(UpdateKey.INFO)
                if (info !is ApkUpgradeInfo) {
                    result.success(false)
                    return
                }

                try {
                    appUpdateClient.showUpdateDialog(activity, info, false)
                    Log.i(TAG, "performUpdate: dialog shown")
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "showUpdateDialog failed: ${e.message}")
                    result.success(false)
                }
            }

            override fun onMarketInstallInfo(intent: Intent?) {}
            override fun onMarketStoreError(code: Int) {
                Log.e(TAG, "performUpdate: onMarketStoreError code=$code")
                result.success(false)
            }
            override fun onUpdateStoreError(code: Int) {
                Log.e(TAG, "performUpdate: onUpdateStoreError code=$code")
                result.success(false)
            }
        })
    }
}
