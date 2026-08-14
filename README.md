# Presenter

一个以 **Markdown 为核心**的 macOS 幻灯片创作工具，致敬 [iA Presenter](https://ia.net/presenter) 的核心理念与交互，视觉上采用 **macOS 27 Golden Gate 的 Liquid Glass 语言**：透明、流动、与环境光交互。

> ⚠️ 本项目是**学习与致敬用途的开源实现**，与 iA 官方没有任何关系，不包含 iA 的任何代码、字体或资源。原创代码以 MIT 协议开源。

---

## 设计语言：Liquid Glass × 环境光

**Glass 主题（默认）** —— 幻灯片不再是纯色块：深墨底色缓缓沉入 post-WWDC25 系统色（systemBlue → systemIndigo → systemTeal → systemPurple 逐页流转），白色标题浮在渐变上。另有九个东方传统色主题（敦煌/故宫/青花/汝窑/水墨/江南/五行/茶境/竹青）作为可选风格保留，均带明暗两套版本。

**Color Shift** —— 编辑器光标、幻灯片标题、缩略图与进度条的颜色随演示进度沿**系统色板**渐变：**Blue（冷启动）→ Indigo（预热）→ Red（高潮）→ Orange（收尾）→ Gold（余韵）**。

**Liquid Glass（调研自 Apple HIG 与 hig-mcp 设计令牌）** —— 窗口**默认就是透明的**：macOS 26+ 使用系统原生 `glassEffect`（可着色、可交互），桌面与光线透过半透明墨色水幕折射进来；macOS 11–25 降级为 `NSVisualEffectView`。设计严格遵循已核实的 Liquid Glass 约束：**每屏合成层 ≤4**、软霜雾（大半径软渐变，不做硬模糊）、**对比度按模糊后实测**（浅色幻灯片自动加深玻璃纱幕）、**Reduce Transparency 时自动切换实底**。

**与环境的碰撞** —— 在 Golden Gate 时代，纯色背景不再是答案。流体背景会**采样你桌面壁纸的主色**（与系统玻璃折射的是同一束光，类似 Windows Mica 的桌面取色，但保持流动）：四条水带以 24fps 沿李萨如轨迹漂移，把壁纸的颜色慢慢揉进界面（macOS 12+ `TimelineView`；macOS 11 静态）。读不到壁纸时回退到 macOS Tahoe 官方壁纸的实测色（蔚蓝 `#4A9CEE`、青 `#6AD5F6`、薰衣草 `#AC9CE6`、长春花蓝 `#ACD5F6`）。换壁纸、换屏，应用的"光"就跟着换。

**区域感知的方向键** —— 交互哪个区域，方向键就控制哪个区域：点击缩略图栏或预览后，↑↓ 切换幻灯片（列表自动跟随滚动）；点击编辑器后，↑↓ 依旧移动文字光标。文本输入框永远保留自己的按键。

**演讲者视图（⌥⌘P）** —— 全屏覆盖目标显示器（含菜单栏与 Dock 的 kiosk 层，不依赖不可靠的 toggleFullScreen），左侧观众画面、右侧玻璃提词器。

---

## 快速开始

```bash
# 运行（SwiftUI 窗口直接打开）
swift run Presenter

# 运行测试（50 个，含像素级设计验证与演讲者窗口冒烟）
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
- Liquid Glass 用 `if #available(macOS 26.0, *)` 分流：新系统走系统原生 `glassEffect(.tint()/.interactive())`，旧系统走 `NSVisualEffectView` 近似，两者共享同一套高光描边（`glassRim`）；`FluidBackground` 遵循「≤4 层、软霜雾、模糊后对比、Reduce Transparency 实底」的 HIG 玻璃约束。
- 区域焦点系统：`AppDelegate` 的键盘监视器按「最后交互区域 + 是否文本控件持有焦点」路由方向键，侧栏/预览/编辑器各自独立。
- Core 层不依赖 SwiftUI，50 个测试覆盖分页、解析、内容分离、TurboStart、进度色、时长估算、文档序列化、**像素级的渲染断言**（Glass 系统色渐变/石青/石绿/琉璃金/宫墙红/钴蓝/天青渐变），以及**演讲者窗口可见性**冒烟。

**设计调研来源**：[hig-mcp](https://github.com/aka-kika/hig-mcp)（Apple HIG 结构化设计令牌：post-WWDC25 系统色、Liquid Glass 约束）；macOS Tahoe 系统壁纸实测采样（`/System/Library/Desktop Pictures` 的 Mac Blue / Chroma Blue）；[Apple Liquid Glass 设计发布](https://images.apple.com/om/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)。

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
| ↑ ↓（缩略图栏/预览聚焦时） | 切换幻灯片（编辑器内仍移动光标） |
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
