// KeyboardBacklight.swift — Glimmer
//
// Two ways to drive the keyboard backlight:
//
//  • Native:     macOS's own brightness service (CoreBrightness `KeyboardBrightnessClient`).
//                Used whenever it actually knows about the keyboard.
//
//  • Workaround: talk to the "Keyboard Backlight" HID device directly (feature report 3
//                = on/off, report 1 = level + fade time). Used when the brightness service
//                has lost the keyboard — which happens when it fails to set up the built-in
//                display (for example after a screen from another model year is fitted). In
//                that state macOS forces the keyboard light to 0 at login and ignores the keys,
//                so Glimmer also re-asserts the chosen level.

import Foundation
import IOKit
import IOKit.hid
import ObjectiveC

protocol KeyboardBacklight: AnyObject {
    var isWorkaround: Bool { get }
    /// 0...1
    func currentLevel() -> Double?
    func set(_ level: Double, animated: Bool)
    /// Called periodically; workaround backends use it to undo macOS forcing the light off.
    func enforce(_ level: Double)
}

// MARK: - Native (CoreBrightness)

final class NativeKeyboardBacklight: KeyboardBacklight {
    private let client: NSObject
    private let keyboardID: UInt64
    let isWorkaround = false

    private typealias GetF = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias SetF = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool

    /// Returns nil unless the brightness service reports a real level for a keyboard.
    init?() {
        guard Bundle(path: "/System/Library/PrivateFrameworks/CoreBrightness.framework")?.load() == true,
              let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else { return nil }
        let c = cls.init()
        let idsSel = NSSelectorFromString("copyKeyboardBacklightIDs")
        guard c.responds(to: idsSel),
              let ids = c.perform(idsSel)?.takeRetainedValue() as? [NSNumber],
              let id = ids.map(\.uint64Value).first(where: { NativeKeyboardBacklight.level(c, $0) != nil })
        else { return nil }
        client = c
        keyboardID = id
    }

    private static func level(_ client: NSObject, _ id: UInt64) -> Double? {
        let sel = NSSelectorFromString("brightnessForKeyboard:")
        guard client.responds(to: sel) else { return nil }
        let f = unsafeBitCast(client.method(for: sel), to: GetF.self)
        let v = f(client, sel, id)
        return v < 0 ? nil : Double(v)
    }

    func currentLevel() -> Double? { NativeKeyboardBacklight.level(client, keyboardID) }

    func set(_ level: Double, animated: Bool) {
        let sel = NSSelectorFromString("setBrightness:forKeyboard:")
        guard client.responds(to: sel) else { return }
        let f = unsafeBitCast(client.method(for: sel), to: SetF.self)
        _ = f(client, sel, Float(min(max(level, 0), 1)), keyboardID)
    }

    func enforce(_ level: Double) {}
}

// MARK: - Workaround (direct HID)

final class HIDKeyboardBacklight: KeyboardBacklight {
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var device: IOHIDDevice?
    private let minRaw: Double
    private let maxRaw: Double
    let isWorkaround = true

    /// Returns nil if this Mac has no "Keyboard Backlight" HID device.
    init?() {
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDPrimaryUsagePageKey: 0xff00,
            kIOHIDPrimaryUsageKey: 0x0f,
        ] as CFDictionary)
        let p = HIDKeyboardBacklight.driverParameters()
        minRaw = p.min
        maxRaw = p.max
        findDevice()
        if device == nil { return nil }
    }

    private func findDevice() {
        device = nil
        guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return }
        for d in set where (IOHIDDeviceGetProperty(d, kIOHIDProductKey as CFString) as? String) == "Keyboard Backlight" {
            if IOHIDDeviceOpen(d, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess {
                device = d
                return
            }
        }
    }

    private func raw(for level: Double) -> UInt32 {
        level <= 0 ? 0 : UInt32((minRaw + (maxRaw - minRaw) * min(level, 1)).rounded())
    }

    func currentLevel() -> Double? {
        guard let r = HIDKeyboardBacklight.driverRaw() else { return nil }
        return r < Int(minRaw) ? 0 : (Double(r) - minRaw) / (maxRaw - minRaw)
    }

    func set(_ level: Double, animated: Bool) {
        if device == nil { findDevice() }
        guard let d = device else { return }
        var enable: [UInt8] = [3, level > 0 ? 1 : 0, 0, 0, 0, 0]
        var report = [UInt8](repeating: 0, count: 9)
        report[0] = 1
        let fade: UInt32 = animated ? 250 : 0
        withUnsafeBytes(of: raw(for: level).littleEndian) { for i in 0..<4 { report[1 + i] = $0[i] } }
        withUnsafeBytes(of: fade.littleEndian) { for i in 0..<4 { report[5 + i] = $0[i] } }
        let a = IOHIDDeviceSetReport(d, kIOHIDReportTypeFeature, 3, &enable, enable.count)
        let b = IOHIDDeviceSetReport(d, kIOHIDReportTypeFeature, 1, &report, report.count)
        if a != kIOReturnSuccess || b != kIOReturnSuccess { device = nil }
    }

    func enforce(_ level: Double) {
        guard let hw = HIDKeyboardBacklight.driverRaw() else { return }
        if abs(hw - Int(raw(for: level))) > 16 { set(level, animated: false) }
    }

    // MARK: Keyboard driver (AppleHIDKeyboardEventDriverV2) properties

    private static func driverService() -> io_service_t {
        IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleHIDKeyboardEventDriverV2"))
    }

    static func driverRaw() -> Int? {
        let s = driverService()
        guard s != 0 else { return nil }
        defer { IOObjectRelease(s) }
        return IORegistryEntryCreateCFProperty(s, "KeyboardBacklightBrightness" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Int
    }

    /// The keyboard's own on-range (e.g. 32...512), read from the driver; falls back to 32...512.
    static func driverParameters() -> (min: Double, max: Double) {
        let s = driverService()
        guard s != 0 else { return (32, 512) }
        defer { IOObjectRelease(s) }
        let p = IORegistryEntryCreateCFProperty(s, "KeyboardBacklightParameters" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? [String: Any]
        let lo = (p?["KeyboardBacklightMinOn"] as? Double) ?? 32
        let hi = (p?["KeyboardBacklightMaxOn"] as? Double) ?? 512
        return hi > lo ? (lo, hi) : (32, 512)
    }
}

/// Picks the native backend when macOS can drive the keyboard light, else the workaround.
func makeKeyboardBacklight() -> KeyboardBacklight? {
    NativeKeyboardBacklight() ?? HIDKeyboardBacklight()
}
