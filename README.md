# mdPresenter

<img src="Assets/mdPresenter-icon-1024.png" width="120" align="right" alt="mdPresenter 图标：白底上的蓝色渐变 .> 符号">

以 **Markdown 为核心**的 macOS 幻灯片创作工具，致敬 [iA Presenter](https://ia.net/presenter) 的核心理念与交互，视觉上采用 **macOS 26 Tahoe / 27 Golden Gate 的 Liquid Glass 语言**：透明、流动、与环境光交互。

![MIT](https://img.shields.io/badge/license-MIT-blue)
![macOS](https://img.shields.io/badge/macOS-11%2B%20(Intel%20%26%20Apple%20Silicon)-8E8E93)
![Swift](https://img.shields.io/badge/Swift-5.9-FA7343)
![Tests](https://img.shields.io/badge/tests-76%2F76%20passing-30D158)
![Built with DeepSeek](https://img.shields.io/badge/vibe%20coded%20with-DeepSeek%20Harness-4D6BFE)

> 💙 **这个项目是「vibe」出来的**：全部代码由人类提出需求、在 [DeepSeek Harness](https://github.com/deepseek-ai) 上由 **deepseek-v4-pro** 逐行协作完成——从 Markdown 解析引擎、Liquid Glass 渲染、到 CI 流水线。人类负责品味与验收，DeepSeek 负责实现。详细记录见 [项目数据](#-项目数据)。
>
> ⚠️ 本项目是**学习与致敬用途的开源实现**，与 iA 官方没有任何关系，不包含 iA 的任何代码、字体或资源。原创代码以 MIT 协议开源。

---

## 设计语言：Liquid Glass × 环境光

**Glass 主题（默认）** —— 幻灯片不是纯色块：深墨底色缓缓沉入 post-WWDC25 系统色（systemBlue → systemIndigo → systemTeal → systemPurple 逐页流转），白色标题浮在渐变上；Light 模式是带真实色相的长春花蓝粉彩。另有九个东方传统色主题（敦煌/故宫/青花/汝窑/水墨/江南/五行/茶境/竹青）作为可选风格。

**Color Shift** —— 编辑器光标、幻灯片标题、缩略图与进度条的颜色随演示进度沿**系统色板**渐变：Blue（冷启动）→ Indigo（预热）→ Red（高潮）→ Orange（收尾）→ Gold（余韵）。

**Liquid Glass（调研自 Apple HIG 与 hig-mcp 设计令牌）** —— 窗口默认透明：macOS 26+ 使用系统原生 `glassEffect`（可着色、可交互），macOS 11–25 降级为 `NSVisualEffectView`。遵循已核实的约束：**每屏合成层 ≤4**、软霜雾、**对比度按模糊后实测**、**Reduce Transparency 自动实底降级**。系统色为 post-WWDC25 调色板（`systemBlue #0088FF`）。

**与环境的碰撞** —— 流体背景**采样桌面壁纸主色**（与系统玻璃折射的是同一束光，类似 Windows Mica 的桌面取色但保持流动），四条水带以 24fps 沿李萨如轨迹漂移；读不到壁纸时回退到 Tahoe 壁纸实测色。换壁纸，应用的「光」就跟着换。

**区域感知的方向键** —— 交互哪个区域，方向键就控制哪个区域：缩略图栏/预览聚焦时 ↑↓ 切换幻灯片，编辑器内仍移动光标；文本输入框永远保留按键。

**Keynote 式演讲者视图（⌥⌘P）** —— 幻灯片**占满整屏**；控制区是自动隐藏的玻璃浮层（3 秒无鼠标淡出）；提词器/缩略图抽屉按 `N` 从右侧滑入；确定性全屏（`willUseFullScreenContentSize` + kiosk 兜底），Esc 平滑退出。

---

## 与 iA Presenter 双向兼容

mdPresenter **能直接打开 iA Presenter 的文件**，也能把文稿导出回 iA 格式：

- **打开 `.iapresenter` / `.presenter`**（**目录包或 zip 压缩包**，均含 `text.md` + `info.json` + `assets/`）：
  - `---` 分页、Tab 缩进的可见文本与**可见列表**、裸图片 URL/路径、图片元数据行（`x:` `y:` `size:` `title:` 等）全部正确解析；
  - `assets/` 中的媒体自动导入为幻灯片附件（`/assets/…` → `media://…`）；
  - `~~删除线~~`、`==高亮==` 等 iA 行内语法兼容；
  - 多列布局（多个 `###` 标题 + 缩进文本）自动渲染为并排双列。
- **导出为 `.iapresenter` 包**：`text.md` + `info.json`（version 2）+ `assets/`，可被 iA Presenter 直接打开，往返无损。
- 也支持导入/导出纯 `.md`（TurboStart 自动拆分）、我们的 JSON `.presenter` 格式、PDF 讲义、幻灯片 PDF、PNG 图集。

## 布局、图片与视频（对照 ia.net/presenter/support/visuals/*）

- **布局选择器**：工具栏「+」按钮手动指定当前幻灯片的布局（9 种：标题页/大标题/图文分栏/大图/网格/表格/标题+文本/多列/空白），默认自动分析内容选布局；按元素类型、标题层级与顺序决策。
- **Kicker 与副标题**：Tab 缩进文字在标题上方 = kicker，下方 = 副标题（iA 语义）。
- **网格**：3 个元素自动并排三列，4+ 元素进入网格布局。
- **背景图片**：`background: true` 元数据的图片铺满整屏、内容浮于其上，且不参与布局计算。
- **图片选项**：`size: cover/contain`、`filter: lighten/darken/grayscale/sepia/blur`、`opacity: %` 全部生效；对齐提示已解析。
- **Media Manager（Inspector「媒体」标签）**：列出全部媒体、重命名、删除（同步移除引用）、一键插入当前幻灯片、**添加 YouTube 链接**。
- **格式**：图片 `.png/.jpg/.gif/.webp/.tiff/.svg/.pdf`，视频 `.mp4/.mov/.m4v`，音频常见格式（占位卡片展示）。
- ⚠️ 已知差异：视频内嵌播放、Unsplash 集成、CSS Class 自定义主题未实现；`/Theme/` 主题资源目录不适用（无自定义主题包）。

## Markdown 格式兼容（对照 ia.net/presenter/support/basics/markdown）

| iA 语法 | 支持 | 说明 |
|---|---|---|
| 段落 / 硬换行（行尾 `\` 或两个空格） | ✅ | 无标记的行自动流入同一段落 |
| 标题 `#`–`######` | ✅ | |
| 无序/有序列表（`- + *` / `1.`） | ✅ | 混用标记亦可 |
| **任务列表** `- [ ]` / `- [x]` | ✅ | 渲染为 ☐ / ☑ |
| 嵌套列表 | ⚠️ | 展平渲染（缩进被规范化） |
| 引用 `>`（Tab 前缀 = 可见） | ✅ | |
| **定义列表** `⇥术语` + `⇥: 定义` | ✅ | 渲染为可见文本 |
| 分页 `---` | ✅ | 亦支持三次回车 |
| 粗体 `**`/`__`、斜体 `*`/`_` | ✅ | |
| 删除线 `~~…~~`、高亮 `==…==` | ✅ | 分别渲染为斜体/粗体 |
| **上标** `100m^2` / `y^(a+b)^`、**下标** `x~z` / `x~y,z~` | ✅ | 基线偏移渲染 |
| 行内链接 / **参考式链接** `[t][id]` `[id]:` | ✅ | 定义行自动隐藏 |
| **脚注** `[^text]` / `[^id]:` | ✅ | 行内渲染为 †，定义聚合到备注末尾 |
| `// 注释` | ✅ | 仅演讲者可见（进入备注） |
| 图片 `![alt](ref)` / 裸 URL / 本地路径 | ✅ | 含查询串 URL |
| **HTML 图片标签** `<img src="…">` | ✅ | |
| 图片元数据 `x:` `y:` `size:` `title:` … | ✅ | 归属图片，不泄漏到备注 |
| 表格（对齐提示、**单元格合并** `\|\|`、行内样式） | ✅ | iA 式极简渲染 |
| 围栏代码块 ``` | ✅ | 缩进代码块不支持（与 iA 一致） |
| **数学** `$…$` `$$…$$` `\(…\)` `\[…\]` | ⚠️ | 行内渲染为代码样式、独立公式为代码块；未集成 KaTeX 排版 |

## 功能清单

- **写作即演讲**：三次回车或 `---` 分页；正文 = 演讲备注（观众不可见），标题 = 幻灯片内容，行首 Tab 强制上屏；Focus Mode（⌘D）；TurboStart 粘贴智能拆分。
- **自动设计**：内容驱动的布局引擎（Title/Statement/Split/Media/Grid/Table/Columns），字号二分自适应，7 种画幅比（Responsive/16:9/16:10/4:3/9:16/4:5/1:1）。
- **提词器**：备注中的 `**粗体**` 在演讲者视图以高亮大字提示；计时器、下一张预览、`←→空格` 导航。
- **导出**：幻灯片 PDF、讲义 PDF（可读摘要）、Markdown、PNG 图集、iA Presenter 包。

## 快速开始

```bash
swift run Presenter                       # 运行
swift test                                # 76 个测试
./scripts/make-app.sh                     # 本机架构 .app
UNIVERSAL=1 ./scripts/make-app.sh         # Intel + Apple Silicon 通用 .app
```

要求：macOS 11+，Xcode 12.5+。或直接下载 [Releases](https://github.com/lukethecat/mdPresenter/releases) 中的 DMG。

## 安装（DMG）

1. 双击 DMG，把 **mdPresenter** 拖到 **Applications** 快捷方式上（DMG 内自带）。
2. **首次打开**：本项目是开源软件，使用临时（ad-hoc）签名、未经过 Apple 公证（公证需要付费的 Apple Developer 账号）。macOS 会提示「无法验证开发者」——这是正常现象，任选其一放行：
   - 打开 **系统设置 → 隐私与安全性**，在底部找到「仍要打开」按钮点击确认；或
   - 在终端执行：`xattr -cr /Applications/mdPresenter.app`
3. 校验完整性（可选）：`shasum -a 256 mdPresenter-macOS-universal.dmg` 应与 Releases 附带的 `.sha256` 一致。

> 有 Apple Developer 账号的贡献者：欢迎 PR 接入 `codesign + notarytool` 公证流水线（需要签名证书与公证凭据，不适合放在公开 CI 密钥里）。

## 架构

```
Sources/
├── PresenterCore/            # 纯逻辑引擎（无 UI，100% 可测试）
│   ├── Markdown/             #   解析器（含 iA 语义）、分页器、TurboStart
│   ├── Engine/               #   内容分离、自动布局、Color Shift、时长估算
│   ├── Design/               #   10 主题、Liquid Glass 色板、字体系统
│   ├── Import/               #   iA Presenter 包导入/导出
│   └── Export/               #   PDF 讲义、Markdown
└── Presenter/                # macOS 11+ SwiftUI 应用
    ├── Views/Components      #   Liquid Glass 组件 + 壁纸取色流体背景
    ├── Views/EditorView      #   NSTextView 编辑器（颜料色光标、实时样式）
    ├── Views/SlideCanvas     #   全尺寸自适应渲染器（预览/缩略图/演讲/导出共用）
    └── Views/PresenterWindow #   Keynote 式全屏演讲者视图
```

## 📊 项目数据

| 指标 | 数值 |
|---|---|
| 首次提交 → 发布 | 同一天（2026-08-14），**9+ 个提交全部由人机对话驱动** |
| Swift 文件 / 总行数 | 34 个 / **6,976 行**（引擎 2,245 + 应用 3,933 + 测试 798） |
| 测试 | **76/76 通过**（含像素级设计断言、演讲窗口全屏/退出回归、iA 兼容往返） |
| 主题 | 10 套（1 现代 Glass + 9 东方传统），各带明暗两版 |
| 二进制 | 通用架构（arm64 + x86_64）**5.1 MB**，零第三方依赖 |
| 设计调研 | Apple HIG 令牌（hig-mcp）、Tahoe 壁纸**本机实测采样**、48×27 壁纸降采样取色 |
| 交互细节 | 24fps 流体、1.5s 调色板缓动、3s 浮层自动隐藏、区域感知按键 |

**与 DeepSeek 的协作方式**：每一轮对话都是一次「品控循环」——人类提出设计直觉（如「像水在界面上流动」「感知每一张幻灯片的颜色」），DeepSeek 调研官方文档、提取系统壁纸真实色值、实现并**用像素级断言自我验证**（模型无法看图，就用「石青应是 #2E5F88」「白色标题像素 >1500」这类客观测试代替眼睛）。

## CI / 自动安装包

- **CI**（`.github/workflows/ci.yml`）：每次 push/PR 在 **Apple Silicon（macos-15）与 Intel（macos-13）** 双架构上 `swift build` + `swift test`。
- **Release**（`.github/workflows/release.yml`）：推送 `v*` 标签自动构建 **arm64 + x86_64 通用二进制**、组装 `.app`、打 **DMG**，并作为附件发布到 GitHub Release。

> 说明：本项目是纯 SwiftUI/AppKit 的 macOS 原生应用，「各个终端」对应 Intel 与 Apple Silicon 双架构；Windows/Linux 包不在范围内。

## 开源

- **协议**：MIT（见 [LICENSE](LICENSE)）。
- **贡献**：欢迎 Issue/PR；新主题、自定义主题格式、双屏观众模式、视频内嵌播放都是好方向。
- **边界**：本仓库只含原创代码。iA Presenter 的名称、图标、字体与主题版权归 iA Inc. 所有。

## 快捷键

| 快捷键 | 功能 |
|---|---|
| 回车 ×3 / `---` | 新建幻灯片 |
| Tab ⇥ | 强制文本上屏 |
| ⌘D | 聚焦模式 |
| ⌥⌘I | 检查器 |
| ⌥⌘P | 播放 / 停止演示 |
| N（演示中） | 提词器抽屉 |
| ← → 空格（演示中） | 上一张 / 下一张 |
| Esc（演示中） | 停止演示 |
| ↑ ↓（侧栏/预览聚焦时） | 切换幻灯片 |
| ⌘N / ⇧⌘N / ⌘O / ⌘S / ⌘E | 新建 / 空白 / 打开 / 保存 / 导出 PDF |

## 已知限制

- 远程图片 URL 显示为占位卡片（本地 assets 完全支持）；视频/音频为占位卡片。
- 自定义主题（iA 的 CSS/HTML 机制）未实现。
- 未实现双屏镜像 + 观众屏分离（演讲者视图在目标屏全屏）。
