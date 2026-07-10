import AppKit
import KubeSwitcherCore
import SwiftUI

@main
@MainActor
final class KubeSwitcherLauncher {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var hotKeyController: HotKeyController?
    private var viewModel: AppViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewModel = AppViewModel.bootstrap()
        self.viewModel = viewModel
        viewModel.onHotKeyPreferenceChanged = { [weak self] preference in
            self?.registerHotKey(preference)
        }
        createStatusItem()
        createWindow(viewModel: viewModel)
        registerHotKey(viewModel.settings.hotKey)
        if let window {
            showWindow(window)
        }
        Task {
            await viewModel.refresh()
            viewModel.startDefaultKubeConfigMonitor()
            registerHotKey(viewModel.settings.hotKey)
        }
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "shippingbox.circle", accessibilityDescription: "KubeSwitcher")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show / Hide", action: #selector(toggleWindowFromStatusItem), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit KubeSwitcher", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func createWindow(viewModel: AppViewModel) {
        let root = KubeSwitcherRootView(viewModel: viewModel)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "KubeSwitcher"
        window.titleVisibility = .hidden
        window.toolbarStyle = .unifiedCompact
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: root)
        self.window = window
    }

    @objc private func toggleWindowFromStatusItem() {
        toggleWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func registerHotKey(_ preference: HotKeyPreference) {
        if let hotKeyController {
            hotKeyController.update(preference: preference)
        } else {
            hotKeyController = HotKeyController(preference: preference) { [weak self] in
                DispatchQueue.main.async {
                    self?.toggleWindow()
                }
            }
        }
        if let error = hotKeyController?.registrationError {
            viewModel?.alertMessage = error
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.terminate(nil)
        return false
    }

    private func toggleWindow() {
        guard let window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showWindow(window)
        }
    }

    private func showWindow(_ window: NSWindow) {
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        if !window.isVisible {
            window.center()
        }
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
