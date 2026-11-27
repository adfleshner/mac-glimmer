// main.swift — Glimmer
//
// Menu bar app: sun icon → Control Center–style panel. Uses macOS's own brightness
// controls when they work and steps in with workarounds when they don't.

import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = GlimmerModel()
    private lazy var keys = BrightnessKeys { [weak self] key in self?.model.handle(key) }
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "Glimmer")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel(_:))

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PanelView(model: model, enableKeys: { [weak self] in self?.enableKeys() }))

        keys.wants = { [weak self] key in self?.model.wantsKey(key) ?? false }
        startKeysIfNeeded()

        // Workaround backends need re-asserting: macOS keeps forcing the keyboard light off,
        // and gamma tables reset on wake and display changes.
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.model.enforce()
            self.startKeysIfNeeded()
        }
        RunLoop.main.add(timer, forMode: .common)

        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.model.reapply()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.model.detect()
                    self.startKeysIfNeeded()
                }
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self?.model.reapply() }
        }
    }

    func applicationWillTerminate(_ note: Notification) {
        model.restore()
    }

    private func startKeysIfNeeded() {
        if model.needsKeys, !keys.isActive { keys.start() }
        model.keysActive = keys.isActive
    }

    private func enableKeys() {
        BrightnessKeys.requestPermission()
        startKeysIfNeeded()
    }

    @objc private func togglePanel(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            model.refreshFromSystem()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
