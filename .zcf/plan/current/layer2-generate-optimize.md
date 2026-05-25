# Layer2 长文档生成优化

## 任务描述
DocForge 项目中，生成长文档 Layer2 时的 6 个优化点。

## 执行计划

### 步骤1：问题2 — 状态保护防跳回
- 文件：`generate_provider.dart`
- 新增 `_hasEnteredGenerating` 标志
- `_handlePlanningEvent` 中条件保护，不再回退 status

### 步骤2：问题6 — 章节延迟渲染
- 文件：`generating_stage.dart`
- `_buildDslContent` 中过滤 `pending` 状态章节

### 步骤3：问题3 — 折叠按钮
- 文件：`generating_stage.dart`
- 新增 `_isOutlineCollapsed` 状态
- 重构 `_buildDslLayout` 布局

### 步骤4：问题4 — 大纲点击定位
- 文件：`generating_stage.dart`
- GlobalKey + Scrollable.ensureVisible

### 步骤5：问题1 — 规划大纲过滤
- 新建 `plan_content_parser.dart`
- 修改 `planning_stage.dart`

### 步骤6：问题5 — 无小结过滤
- 后端 `chapter_prompt_builder.py` Prompt 优化
- 前端 `generating_stage.dart` 正则兜底过滤
