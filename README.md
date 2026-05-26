# DocForge 稿搭子

> **AI 驱动的智能文档创作平台** — 让文档创作变得简单

稿搭子（DocForge）是一款基于 AI 的跨平台智能文档创作应用，支持从一句话需求到专业文档的完整生成流程。覆盖合同、标书、公文、论文、商业计划等 50+ 文档类型，内置智能润色、多语翻译、模板库、术语管理等专业工具。

---

## 核心功能

### 智能生成
AI 驱动的一键文档生成。选择场景或直接输入需求描述，AI 在几分钟内完成初稿创作。生成流程分为四个阶段：
- **需求输入**：选择文档场景，描述创作需求
- **AI 规划**：智能分析需求，规划文档结构与章节
- **内容生成**：流式输出文档内容，实时查看进度
- **审核微调**：预览生成结果，支持手动调整和再生成

支持 50+ 文档类型：合同、标书、公文、简历、论文、报告、会议纪要、商业提案等。

### 文档精修
AI 智能润色与优化。自动识别并修正语法错误、优化措辞表达、改善文档结构。支持逐段精修和全文优化两种模式，让文档专业度显著提升。

### 多语翻译
支持中、英、日、韩、法、德等语言互译。保留原文排版风格和格式，结合术语表确保专业术语翻译准确。支持整篇翻译和逐段对照。

### 模板库
1000+ 精选专业模板，覆盖商务、法律、学术、工程等领域。支持模板预览、收藏和一键套用，生成标准化专业文档。

### 场景化创作
覆盖求职、投标、学术、政务等 20+ 创作场景。每个场景提供智能引导和结构化输入表单，降低创作门槛。支持封面信息、场景参数等定制化配置。

### 术语管理
专业术语库管理工具。支持自定义术语条目，翻译时自动匹配专业表达，确保文档用词统一规范。适用于法律、医学、工程等专业领域。

---

## 技术架构

| 层级 | 技术选型 | 说明 |
|------|---------|------|
| **框架** | Flutter 3.11+ | 跨平台 UI 框架 |
| **状态管理** | flutter_riverpod | 声明式、编译安全的响应式状态管理 |
| **路由** | go_router | 声明式路由，支持 StatefulShellRoute 嵌套导航 |
| **网络层** | dio | HTTP 客户端，支持拦截器和流式响应（SSE） |
| **序列化** | freezed + json_serializable | 不可变数据模型与 JSON 序列化 |
| **本地存储** | flutter_secure_storage + hive | 安全凭据存储 + 轻量键值缓存 |
| **后端** | FastAPI (Python) | 高性能异步 API 服务 |
| **监控** | Sentry + 友盟 | 崩溃上报 + 运营分析 |
| **支付** | IAP (App Store) + vivo/小米 SDK | 多渠道路由与发货策略 |

### 项目结构

```
lib/
├── app/                    # 应用入口、路由、导航壳
│   ├── app.dart            # MaterialApp 配置
│   ├── router.dart         # GoRouter 路由定义（含认证守卫）
│   └── shell.dart          # 底部导航栏壳（5 Tab）
├── core/                   # 基础设施层
│   ├── connectivity/       # 网络连接监测
│   ├── constants/          # 应用常量（颜色、配置、API 路径）
│   ├── iap/                # IAP 内购服务与收据队列
│   ├── network/            # Dio HTTP 客户端与拦截器
│   ├── providers/          # 全局 Provider
│   ├── sse/                # SSE 流式客户端
│   ├── storage/            # 本地安全存储
│   └── theme/              # 主题与间距系统
├── features/               # 功能模块（DDD 分层）
│   ├── auth/               # 认证（登录/注册/忘记密码/资料补全/引导页）
│   ├── document/           # 文档中心与详情
│   ├── feedback/           # 用户反馈
│   ├── generate/           # 智能生成（多阶段流程）
│   ├── glossary/           # 术语管理
│   ├── home/               # 首页（轮播/快捷操作/最近文档）
│   ├── membership/         # 会员订阅
│   ├── notification/       # 消息通知
│   ├── payment/            # 支付与付费墙
│   ├── polish/             # 文档精修
│   ├── profile/            # 个人中心（设置/用量/关于）
│   ├── scene/              # 场景管理
│   ├── search/             # 全局搜索
│   ├── template/           # 模板库与预览
│   └── translate/          # 多语翻译
└── shared/                 # 跨模块共享
    ├── models/             # DSL 文档模型与导出格式
    ├── utils/              # 工具函数（章节编号/文件导出/校验）
    └── widgets/            # 通用组件（DSL 渲染器/支付卡片/反馈报告）
```

---

## 支持的文档类型

| 类别 | 文档类型 |
|------|---------|
| 商务 | 合同、协议、商业计划书、项目提案、尽职调查报告 |
| 政务 | 公文、通知、请示报告、会议纪要、工作总结 |
| 学术 | 论文、开题报告、文献综述、实验报告、研究计划 |
| 求职 | 简历、求职信、作品集说明、离职申请 |
| 工程 | 标书、技术方案、需求规格书、验收报告 |
| 法律 | 律师函、法律意见书、诉讼文书、合同审查意见 |

---

## 平台支持

| 平台 | 状态 | 下载方式 |
|------|------|---------|
| iOS | 已支持 | App Store |
| Android | 已支持 | Google Play / 应用宝 / 各厂商商店 |
| Windows | 已支持 | 官网下载 .exe 安装包 |
| macOS | 已支持 | 官网下载 .dmg 安装包 |
| Web | 已支持 | 浏览器直接访问 |

---

## 快速开始

### 环境要求

- Flutter SDK >= 3.11.5
- Dart SDK >= 3.11.0
- Android Studio / Xcode（按目标平台）
- 后端服务运行中（见 `apps/docforge-service/` 项目）

### 本地开发

```bash
# 1. 克隆项目
git clone <repo-url> && cd docforge_app

# 2. 安装依赖
flutter pub get

# 3. 生成代码（freezed/json_serializable）
dart run build_runner build --delete-conflicting-outputs

# 4. 启动后端（另开终端，参考 docforge-service 项目）
# cd ../apps/docforge-service && uvicorn main:app --reload

# 5. 运行应用
flutter run -d chrome        # Web 模式（开发调试首选）

# 或指定模拟器/设备
flutter run -d ios           # iOS 模拟器
flutter run -d android       # Android 模拟器
flutter run -d windows       # Windows 桌面
flutter run -d macos         # macOS 桌面
```

### 多环境配置

```bash
# 通过 dart-define 覆盖后端地址
flutter run -d windows --dart-define=API_HOST=http://192.168.1.100:8000

# Release 模式自动指向生产服务器
flutter build apk --release
```

### 生成 App 图标

```bash
dart run flutter_launcher_icons
```

---

## 支付系统

支持多渠道支付，自动检测运行环境选择最优通道：

| 渠道 | 平台 | 说明 |
|------|------|------|
| vivo 支付 | Android (vivo) | vivo 应用商店 SDK |
| 小米支付 | Android (Xiaomi) | 小米应用商店 SDK |
| 支付宝 | Web | 扫码支付 |
| 微信支付 | Web | 扫码支付 |
| IAP | iOS | App Store 内购 |

支付流程包含：商品查询 → 下单 → 支付 → 发货验证 → 掉单恢复 的完整链路。

---

## 联系方式

| 渠道 | 信息 |
|------|------|
| 官网 | [http://61.132.52.22:8084/aistudio/service/docforge/web/](http://61.132.52.22:8084/aistudio/service/docforge/web/) |
| 邮箱 | docforge@126.com (BVpQFuTbCXKDvmxA)|
| 微信 | DocForge_AI |

---

## 许可证

Copyright 2026 DocForge. All rights reserved.
