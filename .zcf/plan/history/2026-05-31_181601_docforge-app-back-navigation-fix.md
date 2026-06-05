# DocForge App — 返回导航与UI修复

## 任务
1. Tab 页返回退出 App → 禁用预测性返回 + WidgetsBindingObserver 拦截
2. 退出登录对话框按钮改为等宽左右布局
3. 法律页面 MarkdownBody → Markdown 修复卡死

## 状态：已完成

## 最终方案

### Issue 1: Tab 页返回退出 App
- **根因**：GoRouter 14.8.1 的 `_findCurrentNavigator()` 对单页分支导航器 `canPop()` 返回 false，跳过分支导航器，`PopScope` 永远不会被调用
- **方案**：
  1. `AndroidManifest.xml` 添加 `android:enableOnBackInvokedCallback="false"` 禁用 Android 13+ 预测性手势返回
  2. `app.dart` 的 `DocForgeApp` 转为 `ConsumerStatefulWidget` + `WidgetsBindingObserver`
  3. `initState()` 立即注册 observer，确保在 GoRouter 的 `RootBackButtonDispatcher` 之前
  4. `didPopRoute()` 中：首页 Tab 弹出退出确认对话框，其他 Tab 导航回首页

### Issue 2: 退出登录对话框按钮布局
- `profile_page.dart` 的 `_showLogoutDialog` 添加 `actionsAlignment: MainAxisAlignment.spaceBetween`
- 两个按钮等宽：`(MediaQuery.of(context).size.width - 96) / 2`

### Issue 3: 法律页面卡死
- `legal_page.dart` 中 `MarkdownBody` 替换为 `Markdown`（自带滚动视图）
- 添加 padding 和 MarkdownStyleSheet 样式
