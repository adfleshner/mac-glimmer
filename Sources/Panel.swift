// Panel.swift — Glimmer
//
// The menu bar panel, styled after Control Center's Display / Keyboard Brightness modules.

import SwiftUI

struct CapsuleSlider: View {
    @Binding var value: Double
    var minValue: Double = 0
    let symbol: String

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            let frac = max(0, min(1, (value - minValue) / (1 - minValue)))
            let fillW = h + (w - h) * CGFloat(frac)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.13))
                Capsule().fill(Color.white).frame(width: fillW)
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.28), radius: 1.5, y: 0.5)
                    .frame(width: h, height: h)
                    .offset(x: fillW - h)
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(white: 0.42))
                    .frame(width: h, height: h)
            }
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let f = min(max((g.location.x - h / 2) / (w - h), 0), 1)
                value = minValue + (1 - minValue) * Double(f)
            })
        }
        .frame(height: 22)
        .accessibilityElement()
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
        .accessibilityAdjustableAction { dir in
            let step = (1 - minValue) / 16
            value = min(1, max(minValue, value + (dir == .increment ? step : -step)))
        }
    }
}

struct Card<Content: View>: View {
    let title: String
    let badge: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                        .help("macOS can't control this on its own here, so Glimmer is driving it directly.")
                }
            }
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.06)))
    }
}

/// Small Control Center–style pill button (pure SwiftUI, so it also renders in screenshots).
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.18 : 0.09)))
            .contentShape(Capsule())
    }
}

/// Small on/off switch (pure SwiftUI, so it also renders in screenshots).
struct PillSwitch: View {
    @Binding var isOn: Bool
    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(isOn ? Color.accentColor : Color.primary.opacity(0.18))
            Circle().fill(Color.white).padding(2).shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
        }
        .frame(width: 30, height: 17)
        .contentShape(Capsule())
        .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { isOn.toggle() } }
        .accessibilityElement()
        .accessibilityLabel("Open at login")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

struct PanelView: View {
    @ObservedObject var model: GlimmerModel
    let enableKeys: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Card(title: "Display", badge: model.screenWorkaround ? "Glimmer mode" : nil) {
                CapsuleSlider(value: $model.screen, minValue: model.screenBackend.floor, symbol: "sun.max.fill")
            }
            if model.hasKeyboard {
                Card(title: "Keyboard Brightness", badge: model.keyboardWorkaround ? "Glimmer mode" : nil) {
                    CapsuleSlider(value: $model.keyboard, symbol: "light.max")
                }
            }
            HStack {
                Text("Open at login").font(.system(size: 12))
                Spacer()
                PillSwitch(isOn: $model.openAtLogin)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.06)))
            HStack(spacing: 8) {
                if !model.needsKeys {
                    Label("Using macOS controls", systemImage: "checkmark.circle")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else if model.keysActive {
                    Label("Keys on", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    Button("Enable brightness keys…", action: enableKeys).buttonStyle(PillButtonStyle())
                }
                Spacer()
                Button("Support ♥") {
                    NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/adfleshner")!)
                }
                .buttonStyle(PillButtonStyle())
                .help("Buy me a coffee — keeps Glimmer free and maintained")
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(PillButtonStyle())
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
        .padding(10)
        .frame(width: 300)
    }
}
