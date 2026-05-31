# 华为IAP cachedResult 幂等bug修复

**创建时间**: 2026-05-29 10:00:39
**任务**: 修复 HuaweiIapHandler.kt 中 cachedResult 无条件缓存导致第二次支付不弹出支付页面的bug

## 根因

`onActivityResult` 中每次支付结果都无条件 `cachedResult = map`，即使已通过 `pendingResult.success()` 成功返回。
下一次 `launchPayFlow` 调用 `takeCachedResult()` 时读到了过期结果，直接返回给 Flutter，跳过了支付页面。

## 执行步骤

### 步骤 1：修改 onActivityResult 的5个分支

**文件**: `android/app/src/main/kotlin/com/example/docforge_app/HuaweiIapHandler.kt`
**位置**: `onActivityResult` 方法 (行 39-95)

**改动模式**（每个分支相同）：

```kotlin
// 改前
cachedResult = map
result?.success(map)

// 改后
if (result != null) {
    result.success(map)
} else {
    cachedResult = map
}
```

**5个分支列表**:
1. 用户取消支付 (resultCode != RESULT_OK) — 行 45-48
2. ORDER_STATE_SUCCESS + 无法解析 purchaseToken — 行 64-68
3. ORDER_STATE_SUCCESS — 行 71-78
4. ORDER_STATE_CANCEL — 行 80-83
5. else (其他错误) — 行 85-92

### 步骤 2：验证

- 重新构建 APK，安装到手机
- 沙箱测试：连续进行2次购买，确认第2次能正常弹出支付页面
- 确认第1次支付成功/失败后，第2次支付不受影响

## 预期结果

- 每次 `launchPayFlow` 调用都正常弹出华为支付页面
- `cachedResult` 仅在 Activity 重建等异常场景生效（容错保留）
- 不影响正常支付流程的其他环节

## 附加修复：CI 签名配置

**文件**: `.github/workflows/ci.yml`
**位置**: `build-android` job

CI 只解码了 keystore 文件，但缺少三个签名密码环境变量，导致 Gradle 签名时密码为空。

修复：在 `flutter build apk` step 注入三个 secrets：
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

**前置条件**：需在 GitHub 仓库 Settings → Secrets → Actions 中添加这三个 secret。
