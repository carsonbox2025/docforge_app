# HMS IAP SDK transitive dependencies
-keep class com.huawei.hms.iap.** {*;}
-keep class com.huawei.hms.support.** {*;}
-keep class com.huawei.hms.common.** {*;}
-keep class com.huawei.hms.api.** {*;}
-keep class com.huawei.hms.adapter.** {*;}
-keep class com.huawei.hms.core.** {*;}
-keep class com.huawei.hms.utils.** {*;}
-keep class com.huawei.hms.activity.** {*;}
-keep class com.huawei.hms.security.** {*;}
-keep class com.huawei.hms.base.** {*;}
-keep class com.huawei.hianalytics.** {*;}
-keep class com.huawei.updatesdk.** {*;}

# HMS App Update SDK (AppGallery checkUpdate 审核必需)
-keep class com.huawei.hms.jos.** {*;}
-keep class com.huawei.hms.plugin.** {*;}
-keep class com.huawei.updatesdk.service.** {*;}

# HMS optional runtime dependencies
-dontwarn com.huawei.hms.iapfull.**
-dontwarn com.huawei.hianalytics.**
-dontwarn com.huawei.android.os.**
-dontwarn com.huawei.libcore.io.**
-dontwarn org.bouncycastle.**
