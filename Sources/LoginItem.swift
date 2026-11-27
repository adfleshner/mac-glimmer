// LoginItem.swift — Glimmer
//
// "Open at login" through macOS's own login-items service (System Settings → General →
// Login Items), so installing is just dragging Glimmer into Applications.

import Foundation
import ServiceManagement

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    @discardableResult
    static func set(_ on: Bool) -> Bool {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Glimmer: login item \(on ? "register" : "unregister") failed: \(error.localizedDescription)")
        }
        return isEnabled
    }

    /// Turn "Open at login" on the first time Glimmer runs — that's what people install it for.
    static func enableOnFirstLaunch() {
        let key = "loginItemConfigured"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        set(true)
        UserDefaults.standard.set(true, forKey: key)
    }
}
