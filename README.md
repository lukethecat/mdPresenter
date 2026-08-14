# Presenter

一个以 **Markdown 为核心**的 macOS 幻灯片创作工具，致敬 [iA Presenter](https://ia.net/presenter) 的核心理念与交互，并赋予它**东方传统美学**的配色体系与 **macOS Liquid Glass** 的视觉表现。

> ⚠️ 本项目是**学习与致敬用途的开源实现**，与 iA 官方没有任何关系，不包含 iA 的任何代码、字体或资源。原创代码以 MIT 协议开源。

---

## 设计语言：东方传统色 × Liquid Glass

**配色** —— 九大内置主题取材于中国传统美学，每个主题都带明暗两套版本，颜色随幻灯片推进而轮换：

| 主题 | 灵感 | 气质 |
|---|---|---|
| **敦煌 Dunhuang**（默认） | 壁画矿物颜料 | 石青、石绿、朱砂、赭石、土黄逐页轮换，饱和而内敛 |
| **故宫 Forbidden City** | 宫墙红 · 琉璃金 | 金红交替，庄重热烈 |
| **青花 Blue & White** | 钴蓝白瓷 | 瓷白与钴蓝交替，素净典雅 |
| **汝窑 Ru Kiln** | 「雨过天青云破处」 | 天青渐变、大量留白、内容居中 |
| **水墨 Ink Wash** | 墨分五色 · 计白当黑 | 宣纸与松烟，楷体书写 |
| **江南 Jiangnan** | 粉墙黛瓦 | 月白、藕荷、竹青、米白烟雨粉彩 |
| **五行 Five Elements** | 青赤黄白黑 | 五色周而复始，天生兼具明暗 |
| **茶境 Tea** | 茶汤温润 | 茶汤、熟褐、岩茶的暖调 |
| **竹青 Bamboo** | 竹影清风 | 竹青与新竹的绿意 |

**Color Shift** —— 编辑器光标、幻灯片标题、缩略图与进度条的颜色随演示进度沿传统颜料渐变：**靛青（冷启动）→ 黛紫（预热）→ 朱砂（高潮）→ 琥珀（收尾）→ 鎏金（余韵）**。

**Liquid Glass** —— 窗口**默认就是透明的**：没有黑色底板，macOS 26+ 上使用系统原生的 `glassEffect`（可着色、可交互，与 Apple 新版 iWork 套件同款），桌面与光线从玻璃后面透进来；macOS 11–25 自动降级为 `NSVisualEffectView` 模糊玻璃。缩略图、预览、检查器、状态栏、TurboStart 横幅、工具栏按钮、编辑器本体与演讲者视图侧栏全部浮在玻璃上。

**流动的生命感** —— 窗口背景**本身就是当前幻灯片的颜料色**：一层着色水幕 + 五团纯净颜料光斑（纯色、提亮、加深三种水样变体），以 24fps 沿缓慢的李萨如轨迹漂移，像水在玻璃界面上流动（macOS 12+ `TimelineView` 驱动；macOS 11 为静态色场）。翻页或切换主题时整套调色板用 1.5 秒缓动融为一体，水幕的渐变方向也在缓慢旋转。玻璃面板会**感知幻灯片明暗**：浅色幻灯片（瓷白、琉璃金）自动加深玻璃保证文字可读，深色幻灯片（石青、宫墙红）保持清澈透亮。演讲者视图的舞台同样随幻灯片底色呼吸。颜色从来不是静态皮肤，而是内容的一部分。

---

## 快速开始

```bash
# 运行（SwiftUI 窗口直接打开）
swift run Presenter

# 运行测试（47 个，含像素级设计验证）
swift test

# 打包成可双击的 .app（生成于 .build/release/Presenter.app）
./scripts/make-app.sh
```

要求：macOS 11+，Xcode 12.5+（Swift 5.4+）。在 Xcode 中直接打开 `Package.swift` 也可以运行。

## 功能清单

### ✍️ 写作与拆分（Write it）
- **纯文本编辑器**：iA Writer 风格的深夜配色，检测到 iA Writer 字体时自动启用；Markdown 标记（`#`、`**`、`*`、`` ` ``、列表、引用）实时着色，标记符号淡化为灰色。
- **幻灯片分页**：**连续三个回车**（两行空行）或一行 **`---`** 即创建新幻灯片；删除分隔符即合并。编辑器左侧行号槽以彩色圆形标出每张幻灯片，点击即可跳转。
- **TurboStart**：粘贴大段无分页文本时弹出玻璃横幅，一键按段落+首句启发式自动拆分；导入 `.md`/`.txt` 时同样自动转换。
- **Focus Mode（⌘D）**：隐藏一切干扰，只聚焦当前幻灯片，其余内容变暗。

### 🎬 内容与展示分离（Show it）
- **正文 = 演讲备注**：普通段落只出现在提词器和 Inspector 的 Speech 区，观众永远看不到。
- **标题 = 幻灯片内容**：`#` `##` `###` 标题直接上屏；第一张幻灯片自动成为标题页（主标题 + 副标题）。
- **行首 Tab ⇥** 可强制一段文字上屏（iA 的「Text on Slide」）。
- 拖拽/粘贴**图片、视频、音频**成为幻灯片媒体（`.png .jpg .gif .webp .tiff .svg .pdf .mp4 .mov .m4v .mp3 .m4a .wav .aac .aiff .flac .au`）；Markdown **表格**自动渲染为整洁的数据表。
- **自动布局**：引擎分析每张幻灯片的内容，自动选择 Title / Statement / Split / Media / Grid / Table 布局。

### 🎨 自动化设计与自适应（Shape it）
- **响应式画布**：同一渲染器适配任意尺寸——缩略图、预览、手机竖屏、投影仪。比例可选 **Responsive / 16:9 / 16:10 / 4:3 / 9:16 / 4:5 / 1:1**。
- **东方传统色主题**：九个主题（见上表），全部支持 Light/Dark；可自定义标题字体（含**宋体/楷体**，检测系统安装）、强调色、页眉、页脚与页码。
- **Color Shift**：靛青→黛紫→朱砂→琥珀→鎏金的进度色贯穿编辑器光标、行号槽、缩略图、状态栏与演讲者进度条。

### 🎤 演讲与导出（Rock it & Technologic）
- **演讲者视图（⌥⌘P）**：独立屏幕/窗口，左屏给观众，右侧是玻璃提词器；**备注中的 `**粗体**` 以高亮大字显示**作为对话提示。支持 **备注模式 / 缩略图模式**、下一张预览、进度条、可重置计时器、`←→空格` 导航、自动检测横竖屏。
- **导出**：幻灯片 **PDF**、**讲义 PDF**（标题 + 每页标题与备注的可读摘要，标题以进度颜料着色）、**Markdown**、摘要 Markdown、全套 **PNG 图片**。
- **实时时长估算**：编辑器右下角按 150 词/分钟（拉丁）与 240 字/分钟（中文）估算演讲时长，每张幻灯片单独显示。

## 架构

```
Sources/
├── PresenterCore/            # 纯逻辑引擎（无 UI，100% 可测试）
│   ├── Markdown/             #   MarkdownParser（块级+行内解析器）
│   │                         #   SlideSplitter（--- 与三回车分页）
│   │                         #   TurboStart（粘贴文本自动拆分）
│   ├── Model/                #   Slide/Block AST、DocumentFile（.presenter JSON + 媒体）
│   ├── Engine/               #   ContentResolver（内容/备注分离）
│   │                         #   LayoutEngine（自动布局 + 字号自适应）
│   │                         #   ProgressColorEngine（传统颜料 Color Shift）
│   │                         #   SpeechTimer（时长估算）
│   ├── Design/               #   Theme（九大东方主题）、Typography、Colors
│   └── Export/               #   HandoutPDFExporter（CoreText 排版）、MarkdownExporter
└── Presenter/                # macOS 11+ SwiftUI 应用
    ├── State/AppState        # 单一数据源：文本 → 防抖解析 → Deck
    ├── Views/EditorView      # NSTextView：行号槽、颜料色光标、Markdown 实时样式
    ├── Views/Components      # Liquid Glass 组件（glassEffect + 旧系统降级）
    ├── Views/SlideCanvas     # 全尺寸自适应的幻灯片渲染器（预览/缩略图/演讲/导出共用）
    ├── Views/PresenterWindow # 演讲者视图（玻璃提词器 + 计时器 + 导航）
    ├── Views/InspectorView   # Text / Design 双标签检查器（⌥⌘I）
    └── Export/ExportCoordinator # 打开/保存/五种导出
```

**数据流**：编辑器文本 →（120ms 防抖）→ `SlideSplitter` → `MarkdownParser` → `ContentResolver` → `Deck` → 所有面板从同一份 `Deck` 渲染。文本永远是唯一的事实来源，删掉分隔符就合并幻灯片，无需任何同步逻辑。

**核心设计决策**：
- 幻灯片渲染器 `SlideCanvas` 的所有尺寸都从画布几何推导（百分比 + 二分搜索字号自适应），因此同一视图可从 120pt 缩略图无缝放大到投影仪与 PDF 页面。
- 编辑器用 `NSLayoutManager` 的临时属性做语法着色，不改动底层纯文本存储，撤销/保存始终干净。
- Liquid Glass 用 `if #available(macOS 26.0, *)` 分流：新系统走系统原生 `glassEffect(.tint()/.interactive())`，旧系统走 `NSVisualEffectView` 近似，两者共享同一套高光描边（`glassRim`）。
- Core 层不依赖 SwiftUI，47 个测试覆盖分页、解析、内容分离、TurboStart、进度色、时长估算、文档序列化，以及**像素级的传统色渲染断言**（石青/石绿/琉璃金/宫墙红/钴蓝/天青渐变）。

## 快捷键

| 快捷键 | 功能 |
|---|---|
| 回车 ×3 / `---` | 新建幻灯片 |
| Tab ⇥ | 强制文本上屏 |
| ⌘D | 聚焦模式 |
| ⌥⌘I | 检查器 |
| ⌥⌘P | 播放 / 停止演示 |
| ← → 空格（演示中） | 上一张 / 下一张 |
| Esc（演示中） | 停止演示 |
| ⌘N / ⇧⌘N / ⌘O / ⌘S / ⌘E | 新建 / 空白 / 打开 / 保存 / 导出 PDF |

## 开源

- **协议**：MIT（见 [LICENSE](LICENSE)）。欢迎提 Issue / PR；改动前请先阅读下方「已知限制」。
- **CI**：GitHub Actions（`macos-15`）在每次 push/PR 上运行 `swift build` 与 `swift test`。
- **贡献方向**：新的东方主题、自定义主题格式、双屏演讲模式、视频/音频内嵌播放、数学公式渲染。
- **边界**：本仓库只包含原创代码。iA Presenter 的名称、图标、字体与主题版权归 iA Inc. 所有，请勿混入。

## 已知限制

- 自定义主题（iA 的 CSS/HTML 主题机制）未实现，主题以 Swift 原生定义。
- 视频/音频在幻灯片上以占位卡片显示（不支持内嵌播放）；不支持 Unsplash 集成。
- 演讲者视图为单窗口，未实现双屏镜像 + 观众屏分离。
- 数学公式、任务列表等 Markdown 扩展不在范围内。
