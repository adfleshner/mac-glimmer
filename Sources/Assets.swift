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

/// Background of the disk-image window (660×400 pt). Finder draws the Glimmer icon at
/// (165, 200) and the Applications folder at (495, 200) on top of it — see scripts/dmg-settings.py.
struct DMGBackground: View {
    var body: some View {
        let ink = Color(red: 0.16, green: 0.14, blue: 0.32)
        let warmTop = Color(red: 1.00, green: 0.80, blue: 0.42)
        let warmBottom = Color(red: 0.98, green: 0.52, blue: 0.22)
        ZStack {
            LinearGradient(colors: [Color(red: 0.995, green: 0.975, blue: 0.945),
                                    Color(red: 0.935, green: 0.915, blue: 0.975)],
                           startPoint: .top, endPoint: .bottom)
            // soft glow behind the arrow
            Rectangle()
                .fill(RadialGradient(colors: [warmTop.opacity(0.26), warmTop.opacity(0.08), .clear],
                                     center: UnitPoint(x: 0.5, y: 0.49), startRadius: 0, endRadius: 210))

            VStack(spacing: 6) {
                Text("Drag Glimmer into Applications")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink)
                Text("Then open it from Applications and look for the ☀︎ in your menu bar.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(ink.opacity(0.6))
            }
            .position(x: 330, y: 62)

            // Arrow from the app to Applications
            HStack(spacing: 0) {
                Capsule()
                    .fill(LinearGradient(colors: [warmTop, warmBottom], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 112, height: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(warmBottom)
                    .offset(x: -14)
            }
            .shadow(color: warmBottom.opacity(0.35), radius: 6)
            .position(x: 336, y: 196)

            // Sparkles
            Sparkle().fill(warmTop).frame(width: 18, height: 18).position(x: 300, y: 158)
            Sparkle().fill(warmBottom.opacity(0.8)).frame(width: 11, height: 11).position(x: 374, y: 236)
            Sparkle().fill(ink.opacity(0.18)).frame(width: 14, height: 14).position(x: 60, y: 330)
            Sparkle().fill(ink.opacity(0.14)).frame(width: 10, height: 10).position(x: 612, y: 120)

            Text("macOS blocked it on first launch?  System Settings → Privacy & Security → Open Anyway")
                .font(.system(size: 10.5))
                .foregroundStyle(ink.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(width: 560)
                .position(x: 330, y: 362)
        }
        .frame(width: 660, height: 400)
        .environment(\.colorScheme, .light)
    }
}

/// README preview of the disk-image window: Finder chrome + background + the two icons.
struct DMGWindowShot: View {
    var body: some View {
        let folder: NSImage = {
            let icon = NSWorkspace.shared.icon(forFile: "/Applications")
            icon.size = NSSize(width: 512, height: 512)   // pick the large representation
            let rep = icon.bestRepresentation(for: NSRect(x: 0, y: 0, width: 512, height: 512), context: nil, hints: nil)
            guard let cg = rep?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return icon }
            return NSImage(cgImage: cg, size: NSSize(width: 512, height: 512))
        }()
        VStack(spacing: 0) {
            // Title bar
            ZStack {
                Color(red: 0.93, green: 0.93, blue: 0.94)
                HStack(spacing: 8) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25)).frame(width: 12, height: 12)
                    Spacer()
                }
                .padding(.leading, 12)
                HStack(spacing: 5) {
                    GlimmerIcon().frame(width: 1024, height: 1024).scaleEffect(16.0 / 1024).frame(width: 16, height: 16)
                    Text("Glimmer").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(white: 0.3))
                }
            }
            .frame(height: 28)
            ZStack {
                DMGBackground()
                GlimmerIcon().frame(width: 1024, height: 1024).scaleEffect(112.0 / 1024).frame(width: 112, height: 112)
                    .position(x: 165, y: 200)
                Image(nsImage: folder).resizable().frame(width: 112, height: 112)
                    .position(x: 495, y: 200)
                Text("Glimmer").font(.system(size: 13)).foregroundStyle(.black).position(x: 165, y: 272)
                Text("Applications").font(.system(size: 13)).foregroundStyle(.black).position(x: 495, y: 272)
            }
            .frame(width: 660, height: 400)
        }
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.28), radius: 22, y: 12)
        .padding(36)
        .environment(\.colorScheme, .light)
    }
}

/// README "Support Glimmer" hero button (Buy Me a Coffee).
struct SupportCoffeeButton: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.white.opacity(0.22)).frame(width: 40, height: 40)
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 19, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Buy me a coffee")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                Text("Support Glimmer")
                    .font(.system(size: 11.5, weight: .semibold))
                    .opacity(0.85)
            }
            Spacer(minLength: 4)
            Image(systemName: "heart.fill").font(.system(size: 16, weight: .bold)).opacity(0.9)
        }
        .foregroundStyle(Color(red: 0.24, green: 0.10, blue: 0.04))
        .padding(.leading, 12).padding(.trailing, 20).padding(.vertical, 10)
        .frame(width: 300)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.88, blue: 0.45),
                                              Color(red: 1.0, green: 0.66, blue: 0.25),
                                              Color(red: 0.98, green: 0.47, blue: 0.36)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Capsule().strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.2))
                .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.25).opacity(0.55), radius: 14, y: 4))
        .overlay(alignment: .topTrailing) {
            Sparkle().fill(Color.white).frame(width: 16, height: 16)
                .shadow(color: .white, radius: 4).offset(x: -34, y: -4)
        }
        .padding(18)
        .environment(\.colorScheme, .light)
    }
}

/// Smaller brand-coloured support pill (Venmo / Cash App / Revolut).
struct SupportPill: View {
    let label: String
    let symbol: String
    let top: Color
    let bottom: Color
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 14, weight: .bold))
            Text(label).font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .frame(width: 140, height: 42)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                .shadow(color: bottom.opacity(0.4), radius: 6, y: 2))
        .padding(8)
    }
}

/// README "Download" button.
struct DownloadButton: View {
    var body: some View {
        HStack(spacing: 12) {
            GlimmerIcon().frame(width: 1024, height: 1024).scaleEffect(40.0 / 1024).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("Download Glimmer")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text("for macOS · Apple Silicon & Intel · Free")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.75)
            }
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .padding(.leading, 6)
        }
        .foregroundStyle(.white)
        .padding(.leading, 10).padding(.trailing, 18).padding(.vertical, 9)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [Color(red: 0.24, green: 0.20, blue: 0.52),
                                              Color(red: 0.11, green: 0.09, blue: 0.27)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)))
        .padding(6)
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

    // Disk-image window background (1x + 2x, combined into a HiDPI TIFF by the script)
    writePNG(DMGBackground(), to: out.appendingPathComponent("dmg-background.png"), scale: 1)
    writePNG(DMGBackground(), to: out.appendingPathComponent("dmg-background@2x.png"), scale: 2)
    writePNG(DMGWindowShot(), to: out.appendingPathComponent("dmg-window.png"), scale: 2)

    // README download button
    writePNG(DownloadButton(), to: out.appendingPathComponent("download-button.png"), scale: 2)

    // README "Support Glimmer" buttons
    writePNG(SupportCoffeeButton(), to: out.appendingPathComponent("support-bmc.png"), scale: 2)
    writePNG(SupportPill(label: "Venmo", symbol: "v.circle.fill",
                         top: Color(red: 0.25, green: 0.62, blue: 1.0), bottom: Color(red: 0.0, green: 0.45, blue: 0.9)),
             to: out.appendingPathComponent("support-venmo.png"), scale: 2)
    writePNG(SupportPill(label: "Cash App", symbol: "dollarsign.circle.fill",
                         top: Color(red: 0.2, green: 0.88, blue: 0.35), bottom: Color(red: 0.0, green: 0.68, blue: 0.2)),
             to: out.appendingPathComponent("support-cashapp.png"), scale: 2)
    writePNG(SupportPill(label: "Revolut", symbol: "r.circle.fill",
                         top: Color(white: 0.28), bottom: Color(white: 0.06)),
             to: out.appendingPathComponent("support-revolut.png"), scale: 2)

    // Panel screenshots
    let demo = GlimmerModel(previewScreen: 0.72, keyboard: 0.6, workaround: true)
    writePNG(PanelShot(model: demo, dark: true), to: out.appendingPathComponent("panel-dark.png"))
    writePNG(PanelShot(model: demo, dark: false), to: out.appendingPathComponent("panel-light.png"))
    let keysOff = GlimmerModel(previewScreen: 0.72, keyboard: 0.6, workaround: true)
    keysOff.keysActive = false
    writePNG(PanelShot(model: keysOff, dark: true), to: out.appendingPathComponent("panel-keys-off.png"))
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
