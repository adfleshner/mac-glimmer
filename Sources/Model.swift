// Model.swift — Glimmer
//
// Picks a backend for the screen and the keyboard light (native when macOS can do it,
// workaround when it can't), and keeps the panel and the keys in sync.

import Foundation
import Combine

final class GlimmerModel: ObservableObject {
    private(set) var screenBackend: ScreenBrightness
    private(set) var keyboardBackend: KeyboardBacklight?
    private let defaults = UserDefaults.standard

    @Published var screen: Double = 1 { didSet { screenChanged(oldValue) } }
    @Published var keyboard: Double = 0.75 { didSet { keyboardChanged(oldValue) } }
    @Published var keysActive = false
    @Published private(set) var screenWorkaround = false
    @Published private(set) var keyboardWorkaround = false
    @Published private(set) var hasKeyboard = false

    var needsKeys: Bool { screenWorkaround || keyboardWorkaround }
    private var syncing = false

    init() {
        screenBackend = makeScreenBrightness()
        keyboardBackend = makeKeyboardBacklight()
        detect()
    }

    /// (Re)choose backends — called at launch and after wake, in case macOS recovered.
    func detect() {
        screenBackend = makeScreenBrightness()
        keyboardBackend = makeKeyboardBacklight()
        screenWorkaround = screenBackend.isWorkaround
        keyboardWorkaround = keyboardBackend?.isWorkaround ?? false
        hasKeyboard = keyboardBackend != nil

        syncing = true
        if screenWorkaround {
            // Safety: never start dim (e.g. after restarting while turned down).
            screen = max(defaults.object(forKey: "screen") as? Double ?? 1, 0.5)
        } else {
            screen = screenBackend.currentLevel() ?? 1
        }
        if keyboardWorkaround {
            keyboard = defaults.object(forKey: "keyboard") as? Double ?? 0.75
        } else {
            keyboard = keyboardBackend?.currentLevel() ?? keyboard
        }
        syncing = false
        reapply()
    }

    /// Pull the current levels from macOS for native backends (it may have changed them).
    func refreshFromSystem() {
        syncing = true
        if !screenWorkaround, let v = screenBackend.currentLevel() { screen = v }
        if !keyboardWorkaround, let v = keyboardBackend?.currentLevel() { keyboard = v }
        syncing = false
    }

    func reapply() {
        if screenWorkaround { screenBackend.reapply(screen) }
        if keyboardWorkaround { keyboardBackend?.set(keyboard, animated: true) }
    }

    func enforce() {
        if keyboardWorkaround { keyboardBackend?.enforce(keyboard) }
        if screenWorkaround, screen < 0.999 { screenBackend.reapply(screen) }
    }

    func restore() { screenBackend.restore() }

    // MARK: Changes

    private func screenChanged(_ old: Double) {
        let v = min(max(screen, screenBackend.floor), 1)
        if v != screen { screen = v; return }
        guard !syncing, v != old else { return }
        screenBackend.set(v)
        if screenWorkaround { defaults.set(v, forKey: "screen") }
    }

    private func keyboardChanged(_ old: Double) {
        let v = keyboard < 0.02 ? 0 : min(keyboard, 1)
        if v != keyboard { keyboard = v; return }
        guard !syncing, v != old else { return }
        keyboardBackend?.set(v, animated: false)
        if keyboardWorkaround { defaults.set(v, forKey: "keyboard") }
    }

    // MARK: Keys (workaround subsystems only)

    func handle(_ key: BrightnessKey) {
        let step = 1.0 / 16
        switch key {
        case .screenUp:
            screen += step
        case .screenDown:
            if screen <= screenBackend.floor + 0.001 { sleepDisplayNow() } else { screen -= step }
        case .keyboardUp:
            keyboard = min(1, keyboard + step)
        case .keyboardDown:
            keyboard = max(0, keyboard - step)
        case .keyboardToggle:
            keyboard = keyboard > 0 ? 0 : 0.5
        }
    }

    func wantsKey(_ key: BrightnessKey) -> Bool {
        key.isScreen ? screenWorkaround : keyboardWorkaround
    }
}
