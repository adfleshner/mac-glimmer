// ScreenBrightness.swift — Glimmer
//
//  • Native:     real backlight control through DisplayServices, used when macOS can change
//                the built-in display's brightness.
//
//  • Workaround: when the backlight driver doesn't recognise the panel (it reports
//                "can't change brightness"), dim the picture through the display's gamma table.
//                It can only go darker than the fixed backlight level. For safety it never
//                goes fully black: the lowest level stays readable, and one more "down"
//                turns the screen off (display sleep), which any key or touch wakes.

import Foundation
import CoreGraphics

protocol ScreenBrightness: AnyObject {
    var isWorkaround: Bool { get }
    /// Lowest level the slider / keys may set.
    var floor: Double { get }
    func currentLevel() -> Double?
    func set(_ level: Double)
    /// Re-apply after wake / display changes (gamma tables get reset).
    func reapply(_ level: Double)
    func restore()
}

func builtInDisplay() -> CGDirectDisplayID? {
    var ids = [CGDirectDisplayID](repeating: 0, count: 16)
    var n: UInt32 = 0
    CGGetOnlineDisplayList(16, &ids, &n)
    return ids.prefix(Int(n)).first { CGDisplayIsBuiltin($0) != 0 }
}

// MARK: - Native (DisplayServices)

final class NativeScreenBrightness: ScreenBrightness {
    private typealias CanChange = @convention(c) (CGDirectDisplayID) -> Bool
    private typealias Get = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Set = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let display: CGDirectDisplayID
    private let get: Get
    private let setF: Set
    let isWorkaround = false
    let floor = 0.0

    /// Returns nil unless macOS can really change the built-in display's brightness.
    init?() {
        guard let d = builtInDisplay(),
              let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
              let pc = dlsym(h, "DisplayServicesCanChangeBrightness"),
              let pg = dlsym(h, "DisplayServicesGetBrightness"),
              let ps = dlsym(h, "DisplayServicesSetBrightness") else { return nil }
        let can = unsafeBitCast(pc, to: CanChange.self)
        display = d
        get = unsafeBitCast(pg, to: Get.self)
        setF = unsafeBitCast(ps, to: Set.self)
        guard can(d), currentLevel() != nil else { return nil }
    }

    func currentLevel() -> Double? {
        var v: Float = -1
        return get(display, &v) == 0 && v >= 0 ? Double(v) : nil
    }

    func set(_ level: Double) { _ = setF(display, Float(min(max(level, 0), 1))) }
    func reapply(_ level: Double) {}
    func restore() {}
}

// MARK: - Workaround (gamma dimming)

final class GammaScreenBrightness: ScreenBrightness {
    let isWorkaround = true
    let floor = 1.0 / 16
    private var level = 1.0

    func currentLevel() -> Double? { level }

    func set(_ level: Double) {
        self.level = min(max(level, floor), 1)
        reapply(self.level)
    }

    func reapply(_ level: Double) {
        guard let id = builtInDisplay() else { return }
        if level >= 0.999 {
            CGDisplayRestoreColorSyncSettings()
            return
        }
        // Dim the whites AND deepen the shadows so it reads as "darker", not a grey veil.
        let l = max(floor, level)
        let t = (l - floor) / (1 - floor)          // 0 at lowest, 1 at full
        let white = Float(0.08 + 0.92 * t * t)
        let gamma = Float(1.0 + 0.8 * (1 - t))
        CGSetDisplayTransferByFormula(id, 0, white, gamma, 0, white, gamma, 0, white, gamma)
    }

    func restore() { CGDisplayRestoreColorSyncSettings() }
}

func makeScreenBrightness() -> ScreenBrightness {
    NativeScreenBrightness() ?? GammaScreenBrightness()
}

/// Turn the panel off; any key or trackpad touch wakes it.
func sleepDisplayNow() {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    p.arguments = ["displaysleepnow"]
    try? p.run()
}
