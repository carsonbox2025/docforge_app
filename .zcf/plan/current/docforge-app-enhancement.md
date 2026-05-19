# DocForge App 增强方案 V3 — 二次评审修正版

> 创建时间：2026-05-19
> V1: 6.5 → V2: 7.8 → V3: 目标 8.5+
> 项目：docforge_app (Flutter) + apps/docforge-service (FastAPI)

---

## 二次评审修正摘要

### P0 修正（运行错误）

| # | 问题 | 修正 |
|---|------|------|
| 1 | 通知触发绕过依赖注入 | DocumentService 通过 `_get_notification_service()` 获取已注册的服务实例 |
| 2 | QuotaDataSource URL 模式不一致 | 统一使用 Dio baseUrl 的相对路径，新方法用 `'/quota/stats'` |
| 3 | 图片上传链路断裂 | **移除图片上传功能**，MVP 仅支持文本反馈，images 字段保留但前端不实现上传 |

### P1 修正（设计缺陷）

| # | 问题 | 修正 |
|---|------|------|
| 4 | 任务2 实质无修改 | **移除任务2**，当前代码行为已符合修正后需求 |
| 5 | 法律 URL 常量冲突 | 移除旧 `termsUrl/privacyUrl` 常量，统一使用本地路由 `/legal/:type` |
| 6 | Token 追踪是 TODO | 前端 UI 改为显示**"字数"**而非"Token"，避免误导。stats API 返回 `word_count` 而非 `tokens_used` |
| 7 | autoDispose + 定时器冲突 | 去掉 `autoDispose`，改为全局 `FutureProvider`，ProfilePage dispose 时取消定时器 |
| 8 | 敏感词过滤简陋 | 标注为临时方案，代码中增加 `# TODO: 接入第三方内容审核 API` 注释 |

### P2 修正（体验优化）

| # | 问题 | 修正 |
|---|------|------|
| 9 | 版本号硬编码 | 使用 `package_info_plus` 动态读取 |
| 10 | 反馈入口不显眼 | ProfilePage 中反馈移到"常用"分组，同时文档详情页增加反馈入口（后续迭代） |
| 11 | 通知铃铛仅 Profile 可见 | 在 shell.dart 底部导航"我的"tab 上增加红点提示 |

### 超出本次范围（记录为后续迭代项）

| 项 | 优先级 | 备注 |
|----|--------|------|
| 运营埋点体系 | P1 | 建议接入 Firebase Analytics 或友盟 |
| 崩溃上报 | P1 | 建议 Sentry |
| 推荐有礼/分享微信 | P2 | 增长飞轮，需后端支持 |
| 深色模式 | P3 | 设置页开关已存在，暂隐藏 |
| FCM/APNs 推送 | P2 | push_sent 字段已预留 |

---

## 总览

| 阶段 | 任务 | 类型 | 涉及项目 |
|------|------|------|----------|
| 一 | 任务1/3/5/6 | 纯前端 | docforge_app |
| 二 | 任务4/7/8 后端 | 后端 API + DB | docforge-service |
| 三 | 任务4/7/8 前端 | 前端对接 | docforge_app |

> **任务2 已移除**（当前代码已满足需求）

---

## 阶段一：纯前端快速修复

### 任务3：修复历史文档路由

**文件**：`lib/features/profile/presentation/pages/profile_page.dart` 第46行
```dart
// 前
onTap: () => context.push('/history'),
// 后
onTap: () => context.push('/documents'),
```

---

### 任务1：登录页增加"记住密码"

#### 1. `lib/core/storage/secure_storage.dart` — 新增方法

在 `clearAll()` 后追加：
```dart
static const _savedIdKey = 'saved_identifier';
static const _savedPwdKey = 'saved_password';

Future<void> saveCredentials(String identifier, String password) async {
  await _storage.write(key: _savedIdKey, value: identifier);
  await _storage.write(key: _savedPwdKey, value: password);
}

Future<(String?, String?)> getSavedCredentials() async {
  return (
    await _storage.read(key: _savedIdKey),
    await _storage.read(key: _savedPwdKey),
  );
}

Future<void> clearCredentials() async {
  await _storage.delete(key: _savedIdKey);
  await _storage.delete(key: _savedPwdKey);
}
```

#### 2. `lib/features/auth/presentation/pages/login_page.dart`

新增 import：
```dart
import '../../../../core/storage/secure_storage.dart';
```

新增状态 + initState：
```dart
bool _rememberMe = false;

@override
void initState() {
  super.initState();
  _loadSavedCredentials();
}

Future<void> _loadSavedCredentials() async {
  final (identifier, password) = await SecureStorage.instance.getSavedCredentials();
  if (identifier != null && password != null) {
    _identifierController.text = identifier;
    _passwordController.text = password;
    if (mounted) setState(() => _rememberMe = true);
  }
}
```

在 `_buildPasswordForm()` 的登录按钮前插入 Checkbox：
```dart
Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Row(children: [
    SizedBox(
      width: 18, height: 18,
      child: Checkbox(
        value: _rememberMe,
        onChanged: (v) => setState(() => _rememberMe = v ?? false),
        activeColor: AppColors.primary,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    ),
    const SizedBox(width: 8),
    GestureDetector(
      onTap: () => setState(() => _rememberMe = !_rememberMe),
      child: Text('记住密码', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
    ),
  ]),
),
```

在 `ref.listen` 回调中，登录成功后保存凭据：
```dart
ref.listen<AuthState>(authProvider, (prev, next) {
  if (next.status == AuthStatus.authenticated) {
    _persistCredentials();
    context.go('/');
  } else if (next.status == AuthStatus.error && next.errorMessage != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
  }
});
```

```dart
Future<void> _persistCredentials() async {
  if (_rememberMe && !_showSmsLogin) {
    final id = _identifierController.text.trim();
    final pwd = _passwordController.text;
    if (id.isNotEmpty && pwd.isNotEmpty) {
      await SecureStorage.instance.saveCredentials(id, pwd);
    }
  } else {
    await SecureStorage.instance.clearCredentials();
  }
}
```

---

### 任务5：关于稿搭子页面

#### 1. 新建 `lib/features/profile/presentation/pages/about_page.dart`

页面内容：App Logo、名称、版本号（`package_info_plus` 动态读取）、功能介绍、联系方式（从 AppConstants）、法律条款入口。

```dart
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});
  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    } catch (_) {
      if (mounted) setState(() => _version = AppConstants.appVersion);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('关于${AppConstants.appName}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          const SizedBox(height: 32),
          // Logo
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppColors.primary,
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: const Center(child: Icon(Icons.bolt, color: Colors.white, size: 36)),
          ),
          const SizedBox(height: 16),
          Text(AppConstants.appName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('版本 $_version', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 24),
          // 功能介绍卡片
          _buildInfoCard([
            _InfoRow(Icons.auto_awesome, '智能生成', 'AI 驱动，一键生成专业文档'),
            _InfoRow(Icons.auto_fix_high, '文档精修', '润色优化，提升文本质量'),
            _InfoRow(Icons.translate, '多语翻译', '支持中英日韩等多种语言'),
          ]),
          const SizedBox(height: 12),
          // 联系方式卡片
          _buildInfoCard([
            _InfoRow(Icons.language, '官网', AppConstants.officialWebsite),
            _InfoRow(Icons.email_outlined, '邮箱', AppConstants.supportEmail),
            _InfoRow(Icons.chat_outlined, '微信', AppConstants.wechatAccount),
          ]),
          const SizedBox(height: 12),
          // 法律条款
          _buildInfoCard([
            _InfoRow(Icons.description_outlined, '用户协议', null, onTap: () => context.push('/legal/terms')),
            _InfoRow(Icons.privacy_tip_outlined, '隐私协议', null, onTap: () => context.push('/legal/privacy')),
          ]),
          const SizedBox(height: 32),
          Text('© 2026 ${AppConstants.appName} All Rights Reserved',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _buildInfoCard(List<_InfoRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        for (int i = 0; i < rows.length; i++) ...[
          _buildInfoRow(rows[i]),
          if (i < rows.length - 1)
            Padding(padding: const EdgeInsets.only(left: 48), child: Container(height: 0.5, color: AppColors.borderLight)),
        ],
      ]),
    );
  }

  Widget _buildInfoRow(_InfoRow row) {
    return InkWell(
      onTap: row.onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(row.icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(row.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text))),
          if (row.subtitle != null)
            Text(row.subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          if (row.onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ]),
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _InfoRow(this.icon, this.title, this.subtitle, {this.onTap});
}
```

#### 2. `lib/core/constants/app_constants.dart` — 新增/修改

```dart
// 新增
static const String appVersion = '1.0.0';
static const String officialWebsite = 'https://docforge.app';
static const String supportEmail = 'support@docforge.app';
static const String wechatAccount = 'DocForge_AI';

// 移除旧常量（或标记 deprecated）
// static const String termsUrl = 'https://docforge.app/terms';   ← 删除
// static const String privacyUrl = 'https://docforge.app/privacy'; ← 删除
```

#### 3. `pubspec.yaml` — 新增依赖

```yaml
package_info_plus: ^8.0.0
```

#### 4. `lib/app/router.dart` — 新增路由

```dart
import '../features/profile/presentation/pages/about_page.dart';

GoRoute(path: '/about', pageBuilder: (_, _) => _fastFadePage(const AboutPage(), const ValueKey('about'))),
```

#### 5. `profile_page.dart` 第85行 — 关于导航

```dart
onTap: () => context.push('/about'),
```

#### 6. `settings_page.dart` 第79行 — 关于导航

```dart
onTap: () => context.push('/about'),
```

---

### 任务6：注册页增加隐私协议

#### 后端法律文本 API

1. **新建 `apps/docforge-service/docforge/routers/legal.py`**

```python
from fastapi import APIRouter

router = APIRouter()

_LEGAL_CONTENTS = {
    "terms": {
        "title": "用户协议",
        "content": "# 用户协议\n\n## 1. 服务条款\n\n...（待法务审核替换）...\n",
        "updated_at": "2026-05-19",
    },
    "privacy": {
        "title": "隐私协议",
        "content": "# 隐私协议\n\n## 1. 信息收集\n\n...（待法务审核替换）...\n",
        "updated_at": "2026-05-19",
    },
}

@router.get("/{doc_type}")
async def get_legal_document(doc_type: str):
    doc = _LEGAL_CONTENTS.get(doc_type)
    if not doc:
        return {"code": 404, "message": "文档不存在", "data": None}
    return {"code": 200, "message": "success", "data": doc}
```

2. **`docforge_service_routers.py`** — 挂载

```python
from docforge.routers import legal as legal_router
app.include_router(legal_router.router, prefix="/docforge/legal", tags=["DF-Legal"])
```

#### 前端法律页面

3. **新建 `lib/features/auth/presentation/pages/legal_page.dart`**

```dart
class LegalPage extends ConsumerStatefulWidget {
  final String type;
  const LegalPage({super.key, required this.type});
  @override
  ConsumerState<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends ConsumerState<LegalPage> {
  String _content = '';
  String _title = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final response = await ApiClient.instance.get('/legal/${widget.type}');
      final data = response.data['data'] as Map<String, dynamic>?;
      if (mounted && data != null) {
        setState(() {
          _title = data['title'] ?? '';
          _content = data['content'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '加载失败，请检查网络'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(_title.isEmpty ? '加载中...' : _title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadContent, child: const Text('重试')),
                ]))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: MarkdownBody(data: _content),
                ),
    );
  }
}
```

> **注意**：使用相对路径 `/legal/${widget.type}`，由 Dio baseUrl 拼接为完整 URL。

#### 注册页修改

4. **`lib/features/auth/presentation/pages/register_page.dart`**

新增状态变量：
```dart
bool _agreedToTerms = false;
```

在注册按钮之前插入协议勾选：
```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(
      width: 18, height: 18,
      child: Checkbox(
        value: _agreedToTerms,
        onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
        activeColor: AppColors.primary,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    ),
    const SizedBox(width: 8),
    Expanded(child: Wrap(children: [
      Text('我已阅读并同意', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      GestureDetector(
        onTap: () => context.push('/legal/terms'),
        child: Text('《用户协议》', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
      ),
      Text('和', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      GestureDetector(
        onTap: () => context.push('/legal/privacy'),
        child: Text('《隐私协议》', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
      ),
    ])),
  ],
),
const SizedBox(height: 24),
```

注册按钮增加验证：
```dart
onPressed: (authState.isLoading || !_agreedToTerms) ? null : _register,
```

5. **`lib/app/router.dart`** — 新增路由

```dart
import '../features/auth/presentation/pages/legal_page.dart';

GoRoute(
  path: '/legal/:type',
  pageBuilder: (_, state) {
    final type = state.pathParameters['type'] ?? 'terms';
    return _fastFadePage(LegalPage(type: type), ValueKey('legal-$type'));
  },
),
```

---

## 阶段二：后端 API 开发

### 任务8-后端：用量统计 API

#### 数据库

`docforge_documents` 新增 `tokens_used` 列（预留，初期不写入）：
```sql
ALTER TABLE docforge_documents ADD COLUMN IF NOT EXISTS tokens_used INTEGER DEFAULT 0;
```

> **评审修正**：前端 UI 改为显示"字数"而非"Token"，避免不准确的数据误导用户。`tokens_used` 列保留为后续真实追踪的预留。

#### 修改文件

1. **`apps/docforge-service/docforge/models/quota.py`** — 新增 UserStats

```python
class UserStats(BaseModel):
    generate_count: int = 0
    polish_count: int = 0
    translate_count: int = 0
    total_word_count: int = 0    # 改为字数而非 Token
    word_count_display: str = "0"
    remaining_quota: int = 0
    total_quota: int = -1
```

2. **`apps/docforge-service/docforge/services/quota_service.py`** — 新增方法

```python
async def get_user_stats(self, user_id: str, workshop_id: int | None = None) -> dict:
    db = self._get_db()
    stats_row = db.execute_query(
        """
        SELECT
            COUNT(*) FILTER (WHERE source_type = 'generate' AND status = 'completed') AS generate_count,
            COUNT(*) FILTER (WHERE source_type = 'polish' AND status = 'completed') AS polish_count,
            COUNT(*) FILTER (WHERE source_type = 'translate' AND status = 'completed') AS translate_count,
            COALESCE(SUM(word_count), 0) AS total_word_count
        FROM docforge_documents
        WHERE user_id = %s
        """,
        (user_id,), fetch_one=True,
    )
    quota_row = db.execute_query(
        "SELECT used_count, quota_limit FROM docforge_quotas "
        "WHERE user_id = %s AND quota_type = 'generate'",
        (user_id,), fetch_one=True,
    )

    gen = stats_row.get("generate_count", 0) if stats_row else 0
    polish = stats_row.get("polish_count", 0) if stats_row else 0
    translate = stats_row.get("translate_count", 0) if stats_row else 0
    words = stats_row.get("total_word_count", 0) if stats_row else 0

    if quota_row:
        limit = quota_row.get("quota_limit", -1)
        used = quota_row.get("used_count", 0)
        remaining = max(0, limit - used) if limit > 0 else -1
    else:
        limit, remaining = -1, -1

    return {
        "generate_count": gen, "polish_count": polish, "translate_count": translate,
        "total_word_count": words,
        "word_count_display": self._format_count(words),
        "remaining_quota": remaining, "total_quota": limit,
    }

@staticmethod
def _format_count(n: int) -> str:
    if n >= 10_000: return f"{n / 10_000:.1f}万"
    if n >= 1_000: return f"{n / 1_000:.0f}k"
    return str(n)
```

3. **`apps/docforge-service/docforge/routers/quota.py`** — 新增端点

```python
@router.get("/stats")
async def get_user_stats(
    user: dict = Depends(get_current_user),
    service=Depends(get_quota_service),
    workshop_id: int = Depends(get_workshop_id),
):
    result = await service.get_user_stats(user_id=user["userid"], workshop_id=workshop_id)
    return {"code": 200, "message": "success", "data": result}
```

---

### 任务4-后端：消息通知系统

#### 数据库

```sql
CREATE TABLE IF NOT EXISTS docforge_notifications (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    type VARCHAR(30) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    action_label VARCHAR(50),
    action_route VARCHAR(200),
    document_id INTEGER,
    push_sent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_notif_user ON docforge_notifications(user_id, is_read, created_at DESC);
```

#### 新建文件

1. **`apps/docforge-service/docforge/models/notification.py`**

```python
class NotificationRecord(BaseModel):
    id: int
    user_id: str
    type: str
    title: str
    description: Optional[str] = None
    is_read: bool = False
    action_label: Optional[str] = None
    action_route: Optional[str] = None
    document_id: Optional[int] = None
    push_sent: bool = False
    created_at: Optional[datetime] = None

class NotificationCreate(BaseModel):
    type: str
    title: str
    description: Optional[str] = None
    action_label: Optional[str] = None
    action_route: Optional[str] = None
    document_id: Optional[int] = None
```

2. **`apps/docforge-service/docforge/services/notification_service.py`**

核心方法：`create()` / `list_notifications()` / `mark_as_read()` / `mark_all_as_read()` / `get_unread_count()`
（实现同 V2，此处省略重复）

3. **`apps/docforge-service/docforge/routers/notification.py`**

端点：`GET /list` / `GET /unread-count` / `POST /{id}/read` / `POST /read-all`

4. **`apps/docforge-service/docforge/dependencies.py`** — 注册

```python
from .services.notification_service import NotificationService
_services["notification"] = NotificationService()

async def get_notification_service():
    await _ensure_services()
    return _services["notification"]
```

5. **`apps/docforge-service/docforge_service_routers.py`** — 挂载

```python
from docforge.routers import notification as notification_router
app.include_router(notification_router.router, prefix="/docforge/notifications", tags=["DF-Notifications"])
```

#### 通知触发（使用依赖注入）

> **P0 修正**：不再直接 `NotificationService()` 创建实例。

6. **`apps/docforge-service/docforge/services/document_service.py`** — 修改通知方法

```python
async def _get_notification_service(self):
    """获取已注册的 NotificationService 实例"""
    try:
        from ..dependencies import get_notification_service
        import asyncio
        return await get_notification_service()
    except Exception:
        return None

async def _notify_completion(self, doc_id, doc_type, result):
    user_id = self._doc_user_map.get(doc_id, "")

    # JPush 推送（保持不变）
    try:
        push = self._get_push_service()
        if push:
            await push.send_task_notification(doc_id, doc_type, success=True, result=result, user_id=user_id)
    except Exception as e:
        logger.warning(f"[DocService] 完成推送失败: {e}")

    # 应用内通知（通过依赖注入）
    try:
        ns = await self._get_notification_service()
        if ns:
            from ..models.notification import NotificationCreate
            type_map = {"generate": "doc_generated", "polish": "doc_polished", "translate": "doc_translated"}
            title_map = {"generate": "文档生成完成", "polish": "文档精修完成", "translate": "翻译任务完成"}
            doc_type_str = doc_type.value if hasattr(doc_type, 'value') else str(doc_type)
            await ns.create(
                user_id=user_id,
                data=NotificationCreate(
                    type=type_map.get(doc_type_str, "system"),
                    title=title_map.get(doc_type_str, "任务完成"),
                    description=f"文档《{result.get('title', '')}》已处理完毕" if result else "任务已处理完毕",
                    action_label="查看文档",
                    action_route=f"/documents/{doc_id}",
                    document_id=doc_id,
                ),
            )
    except Exception as e:
        logger.warning(f"[DocService] 通知创建失败: {e}")
```

同样修改 `_notify_failure` 创建失败通知。

---

### 任务7-后端：用户反馈 API

#### 数据库

```sql
CREATE TABLE IF NOT EXISTS docforge_feedbacks (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    type VARCHAR(20) NOT NULL DEFAULT 'suggestion',
    content TEXT NOT NULL,
    images TEXT,
    contact VARCHAR(100),
    status VARCHAR(20) DEFAULT 'pending',
    admin_reply TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_feedbacks_user ON docforge_feedbacks(user_id, created_at DESC);
```

#### 新建文件

1. **`apps/docforge-service/docforge/models/feedback.py`**

```python
class FeedbackCreate(BaseModel):
    type: str = "suggestion"
    content: str
    images: Optional[List[str]] = None
    contact: Optional[str] = None

class FeedbackRecord(BaseModel):
    id: int
    user_id: str
    type: str
    content: str
    images: Optional[List[str]] = None
    contact: Optional[str] = None
    status: str = "pending"
    admin_reply: Optional[str] = None
    created_at: Optional[datetime] = None
```

2. **`apps/docforge-service/docforge/services/feedback_service.py`**

含防滥用逻辑：
- 每用户每天最多 5 条
- 基础敏感词过滤（临时方案，`# TODO: 接入第三方内容审核 API`）

3. **`apps/docforge-service/docforge/routers/feedback.py`**

端点：`POST /` / `GET /list`

4. **`dependencies.py`** — 注册
5. **`docforge_service_routers.py`** — 挂载

（实现同 V2，此处省略重复）

---

## 阶段三：前端数据对接

### 任务8-前端：用量数据接入

> **P1 修正**：前端显示"字数"而非"Token"。

#### 修改文件

1. **`lib/core/constants/app_constants.dart`** — 新增 URL

```dart
// 新增（使用相对路径，与现有 getQuotaUsage 一致）
static const String quotaStatsUrl = '/quota/stats';
```

2. **`lib/features/profile/data/quota_data_source.dart`** — 增量扩展

保留现有 `getQuotaUsage()` 不变，追加：
```dart
Future<UserStats> getStats() async {
  final response = await ApiClient.instance.get(AppConstants.quotaStatsUrl);
  final data = response.data['data'] as Map<String, dynamic>?;
  if (data == null) throw Exception('统计数据为空');
  return UserStats.fromJson(data);
}
```

新增模型（文件末尾）：
```dart
class UserStats {
  final int generateCount;
  final int polishCount;
  final int translateCount;
  final int totalWordCount;
  final String wordCountDisplay;
  final int remainingQuota;
  final int totalQuota;

  const UserStats({
    required this.generateCount, required this.polishCount,
    required this.translateCount, required this.totalWordCount,
    required this.wordCountDisplay, required this.remainingQuota,
    required this.totalQuota,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
    generateCount: json['generate_count'] as int? ?? 0,
    polishCount: json['polish_count'] as int? ?? 0,
    translateCount: json['translate_count'] as int? ?? 0,
    totalWordCount: json['total_word_count'] as int? ?? 0,
    wordCountDisplay: json['word_count_display'] as String? ?? '0',
    remainingQuota: json['remaining_quota'] as int? ?? 0,
    totalQuota: json['total_quota'] as int? ?? -1,
  );
}
```

3. **`lib/features/profile/domain/providers/quota_provider.dart`** — 扩展

```dart
class QuotaState {
  final QuotaUsage? data;
  final UserStats? stats;
  final bool isLoading;
  final String? error;

  const QuotaState({this.data, this.stats, this.isLoading = false, this.error});

  QuotaState copyWith({QuotaUsage? data, UserStats? stats, bool? isLoading, String? error}) =>
      QuotaState(data: data ?? this.data, stats: stats ?? this.stats,
        isLoading: isLoading ?? this.isLoading, error: error);

  bool get isPro => data?.isPro ?? false;
}
```

`loadQuota()` 中同时加载 stats。

4. **`lib/features/profile/presentation/pages/profile_page.dart`** — 真实数据 + 三态

Stats 行改为显示"字数"：
```dart
_buildStatItem('${stats?.generateCount ?? 0}', '生成文档'),
_buildStatDivider(),
_buildStatItem('${stats?.polishCount ?? 0}', '精修次数'),
_buildStatDivider(),
_buildStatItem(stats?.wordCountDisplay ?? '0', '字数'),  // 改为"字数"
```

空态引导（新用户数据全为0时）：
```dart
if (stats == null || (stats.generateCount == 0 && stats.polishCount == 0))
  return _buildEmptyStatsGuide();
```

```dart
Widget _buildEmptyStatsGuide() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    child: Center(
      child: GestureDetector(
        onTap: () => context.go('/generate'),
        child: Text('开始你的第一篇文档 →',
          style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
      ),
    ),
  );
}
```

---

### 任务4-前端：消息通知对接 + 未读徽标

#### 新建文件

1. **`lib/features/notification/data/notification_data_source.dart`**

```dart
class NotificationDataSource {
  Future<Map<String, dynamic>> getNotifications({
    String category = 'all', int page = 1, int pageSize = 20,
  }) async {
    final response = await ApiClient.instance.get(
      '/notifications/list',
      queryParameters: {'category': category, 'page': page, 'page_size': pageSize},
    );
    return response.data['data'] as Map<String, dynamic>? ?? {};
  }

  Future<int> getUnreadCount() async {
    final response = await ApiClient.instance.get('/notifications/unread-count');
    return response.data['data']['unread_count'] as int? ?? 0;
  }

  Future<void> markAsRead(int id) async {
    await ApiClient.instance.post('/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await ApiClient.instance.post('/notifications/read-all');
  }
}
```

> **P0 修正**：所有 URL 使用相对路径（如 `/notifications/list`），由 Dio baseUrl 拼接。

#### 修改文件

2. **`lib/features/notification/data/models/notification_models.dart`** — 新增 fromApi

（同 V2，此处省略）

3. **`lib/features/notification/domain/providers/notification_provider.dart`** — 替换 mock

```dart
// P1 修正：去掉 autoDispose，改为全局 provider
final unreadCountProvider = FutureProvider<int>((ref) async {
  final ds = NotificationDataSource();
  return ds.getUnreadCount();
});

final notificationProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(NotificationDataSource());
});
```

所有 API 调用都有 try-catch 降级。

4. **`lib/features/profile/presentation/pages/profile_page.dart`** — 未读徽标

通知铃铛增加红色未读数量徽标（Stack + Positioned 实现）。

刷新策略：
- 进入 Profile 页时：`ref.watch(unreadCountProvider)` 自动触发
- 从通知页返回后：`ref.invalidate(unreadCountProvider)` 刷新
- 60s 定时器：在 `_ProfilePageState` 中 `initState` 启动，`dispose` 取消

5. **`lib/app/shell.dart`** — "我的"tab 增加红点

> **P2 修正**：在底部导航"我的"图标上增加红点提示，用户在其他 Tab 也能感知到未读消息。

在 `AppNavigationShell` 中消费 `unreadCountProvider`，当 `unreadCount > 0` 时给"我的"tab 的 icon 外层包一个 `Badge`：

```dart
// shell.dart 需要改为 ConsumerWidget 才能使用 ref
class AppNavigationShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppNavigationShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider).maybeWhen(
      data: (c) => c, orElse: () => 0,
    );
    // ... 构建 BottomNavigationBar 时
    // "我的" tab 的 icon 使用 Badge 包裹：
    items: [
      // ... 其他 tabs
      BottomNavigationBarItem(
        icon: Badge(
          isLabelVisible: unreadCount > 0,
          label: Text('$unreadCount', style: TextStyle(fontSize: 9)),
          child: Icon(Icons.person_outline, size: 22),
        ),
        activeIcon: Icon(Icons.person, size: 22),
        label: '我的',
      ),
    ],
  }
}
```

---

### 任务7-前端：用户反馈页面

> **P0 修正**：移除图片上传功能，MVP 仅支持文本反馈。

#### 新建文件

1. `lib/features/feedback/data/models/feedback_models.dart`
2. `lib/features/feedback/data/feedback_data_source.dart`
3. `lib/features/feedback/domain/providers/feedback_provider.dart`
4. `lib/features/feedback/presentation/pages/feedback_page.dart`

反馈页面结构（无图片上传）：
```
Scaffold (AppBar: "问题反馈")
├── TabBar: [提交反馈 | 反馈历史]
├── 提交反馈 Tab:
│   ├── 类型选择（3 pill）
│   ├── 反馈内容 TextField（多行，500字限制，字数计数）
│   ├── 联系方式 TextField（可选）
│   └── 提交按钮（loading + 成功 toast）
├── 反馈历史 Tab:
│   ├── Loading 态
│   ├── 空状态
│   ├── Error 态 + 重试
│   └── ListView of FeedbackCard
```

#### 修改文件

5. `lib/core/constants/app_constants.dart` — 新增 URL
```dart
static const String feedbackSubmitUrl = '/feedbacks';
static const String feedbackListUrl = '/feedbacks/list';
```

6. `lib/app/router.dart` — 新增路由

7. `lib/features/profile/presentation/pages/profile_page.dart` — 反馈入口

反馈入口放在"常用"分组（而非"设置"分组）：
```dart
_buildMenuSection('常用', [
  _MenuItem(icon: Icons.history, title: '历史文档', badge: '128',
    onTap: () => context.push('/documents')),
  _MenuItem(icon: Icons.drafts_outlined, title: '草稿箱',
    onTap: () => context.push('/drafts')),
  _MenuItem(icon: Icons.bookmark_outline, title: '收藏模板',
    onTap: () => context.push('/templates')),
  _MenuItem(icon: Icons.feedback_outlined, title: '问题反馈',  // 新增，在常用分组
    onTap: () => context.push('/feedback')),
]),
```

---

## 文件变更汇总

### 新建文件（13个）

| # | 文件 | 项目 |
|---|------|------|
| 1 | `docforge_app/lib/features/profile/presentation/pages/about_page.dart` | 前端 |
| 2 | `docforge_app/lib/features/auth/presentation/pages/legal_page.dart` | 前端 |
| 3 | `docforge_app/lib/features/notification/data/notification_data_source.dart` | 前端 |
| 4 | `docforge_app/lib/features/feedback/data/models/feedback_models.dart` | 前端 |
| 5 | `docforge_app/lib/features/feedback/data/feedback_data_source.dart` | 前端 |
| 6 | `docforge_app/lib/features/feedback/domain/providers/feedback_provider.dart` | 前端 |
| 7 | `docforge_app/lib/features/feedback/presentation/pages/feedback_page.dart` | 前端 |
| 8 | `docforge-service/docforge/routers/legal.py` | 后端 |
| 9 | `docforge-service/docforge/models/notification.py` | 后端 |
| 10 | `docforge-service/docforge/models/feedback.py` | 后端 |
| 11 | `docforge-service/docforge/services/notification_service.py` | 后端 |
| 12 | `docforge-service/docforge/services/feedback_service.py` | 后端 |
| 13 | `docforge-service/docforge/routers/notification.py` | 后端 |
| 14 | `docforge-service/docforge/routers/feedback.py` | 后端 |

### 修改文件（17个）

| # | 文件 | 修改内容 |
|---|------|---------|
| 1 | `profile_page.dart` | 路由修复+关于+反馈+徽标+真实数据+空态+shell红点 |
| 2 | `login_page.dart` | 记住密码 |
| 3 | `secure_storage.dart` | 凭据存取 |
| 4 | `app/router.dart` | 新增3个路由 |
| 5 | `register_page.dart` | 隐私协议 |
| 6 | `settings_page.dart` | 关于导航 |
| 7 | `app_constants.dart` | 常量+URL+移除旧常量 |
| 8 | `quota_data_source.dart` | 增量扩展 |
| 9 | `quota_provider.dart` | stats 状态 |
| 10 | `notification_models.dart` | fromApi |
| 11 | `notification_provider.dart` | 替换 mock+全局 provider |
| 12 | `pubspec.yaml` | package_info_plus |
| 13 | `app/shell.dart` | ConsumerWidget + 红点 |
| 14 | `document_service.py` | 依赖注入通知 |
| 15 | `quota_service.py` + `quota.py` + `quota router` | get_user_stats |
| 16 | `dependencies.py` | 注册2个服务 |
| 17 | `docforge_service_routers.py` | 挂载3个路由 |
