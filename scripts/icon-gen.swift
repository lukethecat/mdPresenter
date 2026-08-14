// mdPresenter 应用图标生成器
//
// iA Writer 式极简：纯白圆角底 + 一个彩色的 ".>" 符号
//   • 圆点   = Markdown 列表符（写作）
//   • 右尖括 = 前进到下一张幻灯片（演讲）
// 渐变取 post-WWDC25 系统色 systemBlue #0088FF → systemTeal #00C3D0。
//
// 用法: swift scripts/icon-gen.swift <输出.png>

import AppKit

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write("usage: swift scripts/icon-gen.swift <output.png>\n".data(using: .utf8)!)
    exit(1)
}
let outPath = CommandLine.arguments[1]

let S: CGFloat = 1024
// 显式 1024×1024 位图上下文（避免 Retina 下 lockFocus 产生 2x 尺寸）。
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

// 1. 纯白圆角底（Big Sur 风格 squircle 半径）。
let margin: CGFloat = 64
let bgRect = CGRect(x: margin, y: margin, width: S - margin * 2, height: S - margin * 2)
let bg = CGPath(roundedRect: bgRect, cornerWidth: 180, cornerHeight: 180, transform: nil)
ctx.saveGState()
ctx.addPath(bg)
ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
ctx.fillPath()
ctx.restoreGState()

// 2. 液态玻璃渐变（横向）。
let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
    colors: [
        CGColor(srgbRed: 0, green: 0x88 / 255.0, blue: 1, alpha: 1),          // #0088FF systemBlue
        CGColor(srgbRed: 0, green: 0xC3 / 255.0, blue: 0xD0 / 255.0, alpha: 1), // #00C3D0 systemTeal
    ] as CFArray,
    locations: [0, 1]
)!
let gradStart = CGPoint(x: 160, y: 512)
let gradEnd = CGPoint(x: 864, y: 512)

func paint(_ path: CGPath) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: gradStart, end: gradEnd, options: [])
    ctx.restoreGState()
}

// 3a. 圆点（Markdown 句点）——像文本里的句号：缩小、沉到基线位置，
//     与 ">" 组成终端字符般的 ".>" 符号。
let dotR: CGFloat = 88
// 注意：NSBitmapImageRep 上下文非翻转（y 向上），y=318 才是视觉上的下三分之一。
let dotCenter = CGPoint(x: 292, y: 318)
let dotRect = CGRect(x: dotCenter.x - dotR, y: dotCenter.y - dotR, width: dotR * 2, height: dotR * 2)
paint(CGPath(ellipseIn: dotRect, transform: nil))

// 3b. 右尖括 ">"（下一张幻灯片），粗圆头描边。向左收紧、贴近圆点，
//     整体光学居中，右缘留足安全距离（不会被圆角吃掉）。
let halfH: CGFloat = 235
let chevron = CGMutablePath()
chevron.move(to: CGPoint(x: 462, y: 512 - halfH))
chevron.addLine(to: CGPoint(x: 762, y: 512))
chevron.addLine(to: CGPoint(x: 462, y: 512 + halfH))
let stroked = chevron.copy(strokingWithWidth: 128, lineCap: .round, lineJoin: .round, miterLimit: 10)
paint(stroked)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: outPath))
print("✅ 图标已生成: \(outPath)")
