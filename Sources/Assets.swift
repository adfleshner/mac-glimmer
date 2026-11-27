// Assets.swift — Glimmer
//
// `Glimmer --render-assets <dir>` draws the app icon, README screenshots and an animated
// preview straight from the real SwiftUI views (no hardware access, no screen recording),
// so the images always match the app. Used by scripts/render-assets.sh.

import Cocoa
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// MARK: - Preview backends (never touch the hardware)

final class PreviewScreen: ScreenBrightness {
    let isWorkaround: Bool
    let floor: Double
    init(isWorkaround: Bool) {
        self.isWorkaround = isWorkaround
        floor = isWorkaround ? 1.0 / 16 : 0
    }
    func currentLevel() -> Double? { nil }
    func set(_ level: Double) {}
    func reapply(_ level: Double) {}
    func restore() {}
}

final class PreviewKeyboard: KeyboardBacklight {
    let isWorkaround: Bool
    init(isWorkaround: Bool) { self.isWorkaround = isWorkaround }
    func currentLevel() -> Double? { nil }
    func set(_ level: Double, animated: Bool) {}
    func enforce(_ level: Double) {}
}

// MARK: - Icon

/// Four-pointed sparkle.
struct Sparkle: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let pinch = min(r.width, r.height) * 0.12
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: c.y), control: CGPoint(x: c.x + pinch, y: c.y - pinch))
        p.addQuadCurve(to: CGPoint(x: c.x, y: r.maxY), control: CGPoint(x: c.x + pinch, y: c.y + pinch))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: c.y), control: CGPoint(x: c.x - pinch, y: c.y + pinch))
        p.addQuadCurve(to: CGPoint(x: c.x, y: r.minY), control: CGPoint(x: c.x - pinch, y: c.y - pinch))
        return p
    }
}

/// The app icon, drawn on Apple's 1024-pt macOS icon grid (824-pt body).
struct GlimmerIcon: View {
    var body: some View {
        let warmTop = Color(red: 1.00, green: 0.90, blue: 0.55)
        let warmBottom = Color(red: 1.00, green: 0.58, blue: 0.22)
        ZStack {
            // Body: deep night-blue squircle
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.16, green: 0.15, blue: 0.38),
                                              Color(red: 0.07, green: 0.06, blue: 0.18)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.04)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 5))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 12)

            // Soft glow
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1, green: 0.72, blue: 0.3).opacity(0.55), .clear],
                                     center: .center, startRadius: 40, endRadius: 360))
                .frame(width: 720, height: 720)

            // Keyboard-key hint: a glowing key cap under the sun
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(warmTop.opacity(0.55), lineWidth: 6))
                .frame(width: 500, height: 84)
                .shadow(color: warmBottom.opacity(0.7), radius: 24)
                .offset(y: 300)

            // Sun rays
            ForEach(0..<8) { i in
                Capsule()
                    .fill(LinearGradient(colors: [warmTop, warmBottom], startPoint: .top, endPoint: .bottom))
                    .frame(width: 42, height: 104)
                    .offset(y: -212)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            .offset(y: -40)

            // Sun core
            Circle()
                .fill(LinearGradient(colors: [warmTop, warmBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 270, height: 270)
                .shadow(color: warmBottom.opacity(0.75), radius: 34)
                .offset(y: -40)

            // Glimmer sparkles
            Sparkle().fill(Color.white).frame(width: 118, height: 118)
                .shadow(color: .white.opacity(0.8), radius: 14)
                .offset(x: 232, y: -268)
            Sparkle().fill(Color.white.opacity(0.85)).frame(width: 58, height: 58)
                .shadow(color: .white.opacity(0.7), radius: 8)
                .offset(x: 300, y: -165)
            Sparkle().fill(Color.white.opacity(0.7)).frame(width: 44, height: 44)
                .offset(x: -262, y: -250)
        }
        .frame(width: 1024, height: 1024)
    }
}

// MARK: - Screenshot views

/// The panel inside a popover-like card (what you see under the ☀︎).
struct PanelShot: View {
    let model: GlimmerModel
    let dark: Bool
    var body: some View {
        PanelView(model: model, enableKeys: {})
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(dark ? Color(red: 0.17, green: 0.17, blue: 0.19) : Color(red: 0.94, green: 0.94, blue: 0.95))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(dark ? 0.12 : 0.6), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8))
            .padding(28)
            .environment(\.colorScheme, dark ? .dark : .light)
    }
}

/// README hero: a desktop with the menu bar, the ☀︎ icon and the open panel.
struct HeroShot: View {
    let model: GlimmerModel
    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.10, green: 0.09, blue: 0.26),
                                    Color(red: 0.33, green: 0.16, blue: 0.42),
                                    Color(red: 0.86, green: 0.45, blue: 0.32)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            // Menu bar
            HStack(spacing: 16) {
                Image(systemName: "apple.logo").font(.system(size: 14, weight: .medium))
                Text("Finder").font(.system(size: 13, weight: .bold))
                ForEach(["File", "Edit", "View", "Go", "Window", "Help"], id: \.self) {
                    Text($0).font(.system(size: 13))
                }
                Spacer()
                Image(systemName: "sun.max")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.25)))
                Image(systemName: "wifi").font(.system(size: 13))
                Image(systemName: "battery.75percent").font(.system(size: 15))
                Image(systemName: "switch.2").font(.system(size: 13))
                Text("Thu 9:41 PM").font(.system(size: 13))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(height: 26)
            .background(Color.black.opacity(0.28))

            // Title block
            HStack(spacing: 22) {
                GlimmerIcon().frame(width: 1024, height: 1024).scaleEffect(150.0 / 1024).frame(width: 150, height: 150)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Glimmer").font(.system(size: 54, weight: .bold, design: .rounded))
                    Text("A glimmer of hope for every\nMacBook left in the dark.")
                        .font(.system(size: 21, weight: .semibold))
                    Text("Brightness and keyboard light, back —\neven after a screen swap.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .foregroundStyle(.white)
            }
            .offset(x: 48, y: 230)

            // Open panel under the ☀︎
            PanelShot(model: model, dark: true)
                .offset(x: 960 - 300 - 28 - 160, y: 2)
        }
        .frame(width: 960, height: 470)
        .clipped()
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Rendering

@MainActor
private func cgImage<V: View>(_ view: V, scale: CGFloat) -> CGImage? {
    let r = ImageRenderer(content: view)
    r.scale = scale
    return r.cgImage
}

@MainActor
private func writePNG<V: View>(_ view: V, to url: URL, scale: CGFloat = 2) {
    guard let img = cgImage(view, scale: scale),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("✗ \(url.lastPathComponent)"); return
    }
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
    print("✓ \(url.lastPathComponent)  \(img.width)×\(img.height)")
}

@MainActor
private func writeGIF(frames: [CGImage], delay: Double, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil)
    else { return }
    CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary
    for f in frames { CGImageDestinationAddImage(dest, f, frameProps) }
    CGImageDestinationFinalize(dest)
    print("✓ \(url.lastPathComponent)  \(frames.count) frames")
}

/// Ease in/out between keyframes.
private func keyframes(_ points: [(Double, Double)], frames: Int) -> [Double] {
    (0..<frames).map { i in
        let t = Double(i) / Double(frames - 1) * Double(points.count - 1)
        let k = min(Int(t), points.count - 2)
        let u = t - Double(k)
        let e = u * u * (3 - 2 * u)
        return points[k].1 + (points[k + 1].1 - points[k].1) * e
    }
}

@MainActor
func renderAssets(to dir: String) {
    let out = URL(fileURLWithPath: dir, isDirectory: true)
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

    // Icon: 1024 PNG + full .iconset for iconutil
    writePNG(GlimmerIcon(), to: out.appendingPathComponent("icon-1024.png"), scale: 1)
    let iconset = out.appendingPathComponent("AppIcon.iconset", isDirectory: true)
    try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    for base in [16, 32, 128, 256, 512] {
        for mult in [1, 2] {
            let px = CGFloat(base * mult)
            let name = mult == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
            writePNG(GlimmerIcon().scaleEffect(px / 1024).frame(width: px, height: px),
                     to: iconset.appendingPathComponent(name), scale: 1)
        }
    }

    // Panel screenshots
    let demo = GlimmerModel(previewScreen: 0.72, keyboard: 0.6, workaround: true)
    writePNG(PanelShot(model: demo, dark: true), to: out.appendingPathComponent("panel-dark.png"))
    writePNG(PanelShot(model: demo, dark: false), to: out.appendingPathComponent("panel-light.png"))
    writePNG(HeroShot(model: demo), to: out.appendingPathComponent("hero.png"))

    // Animated preview: keyboard light up, screen dims and comes back
    let n = 72
    let kb = keyframes([(0, 0.1), (1, 0.95), (2, 0.95), (3, 0.55)], frames: n)
    let sc = keyframes([(0, 0.9), (1, 0.9), (2, 0.35), (3, 0.8)], frames: n)
    var frames: [CGImage] = []
    for i in 0..<n {
        let m = GlimmerModel(previewScreen: sc[i], keyboard: kb[i], workaround: true)
        if let img = cgImage(PanelShot(model: m, dark: true), scale: 1.5) { frames.append(img) }
    }
    writeGIF(frames: frames, delay: 0.045, to: out.appendingPathComponent("panel.gif"))
}
