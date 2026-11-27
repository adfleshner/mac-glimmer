// BrightnessKeys.swift — Glimmer
//
// Catches the brightness / keyboard-illumination keys (function row, Touch Bar buttons)
// so they can drive the workaround backends. Only the keys for subsystems that are in
// workaround mode are taken; everything else passes through to macOS untouched.
// Needs Accessibility permission.

import Cocoa
import ApplicationServices

enum BrightnessKey: Int {
    case screenUp = 2, screenDown = 3
    case keyboardUp = 21, keyboardDown = 22, keyboardToggle = 23

    var isScreen: Bool { self == .screenUp || self == .screenDown }
}

final class BrightnessKeys {
    private var tap: CFMachPort?
    private let handler: (BrightnessKey) -> Void
    /// Return true for keys Glimmer should take over.
    var wants: (BrightnessKey) -> Bool = { _ in false }

    var isActive: Bool { tap != nil }

    init(handler: @escaping (BrightnessKey) -> Void) {
        self.handler = handler
    }

    static var hasPermission: Bool { AXIsProcessTrusted() }

    static func requestPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil, BrightnessKeys.hasPermission else { return isActive }
        let mask = CGEventMask(1 << 14)  // NX_SYSDEFINED
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let me = Unmanaged<BrightnessKeys>.fromOpaque(refcon!).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let t = me.tap { CGEvent.tapEnable(tap: t, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8,
                  let key = BrightnessKey(rawValue: (ns.data1 & 0xFFFF_0000) >> 16),
                  me.wants(key) else {
                return Unmanaged.passUnretained(event)
            }
            if ((ns.data1 & 0xFF00) >> 8) == 0xA { me.handler(key) }  // key down
            return nil
        }
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: mask, callback: callback,
                                        userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }
}
