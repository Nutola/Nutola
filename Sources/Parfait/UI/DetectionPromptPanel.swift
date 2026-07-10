import AppKit
import Combine
import SwiftUI

/// A borderless, non-activating floating panel so the "Record this meeting?" card can appear on
/// its own (SwiftUI's MenuBarExtra popover can't be opened programmatically) without stealing
/// focus from whatever the user is doing. canBecomeKey stays true so the SwiftUI buttons inside
/// react to clicks; nonactivatingPanel keeps the app itself from coming forward.
private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Shows/hides the floating detection prompt in lockstep with `AppState.detectedAppName`.
/// Owned by the AppDelegate for the app's lifetime.
@MainActor
final class DetectionPromptController {
    private var panel: FloatingPanel?
    private var shownName: String?
    private var cancellable: AnyCancellable?

    init() {
        // detectedAppName is only ever non-nil while detection is on and auto-record is off, and
        // it clears on record/dismiss/mic-release — so binding the panel straight to it needs no
        // extra state. removeDuplicates avoids rebuilding the card on redundant re-publishes.
        cancellable = AppState.shared.$detectedAppName
            .removeDuplicates()
            .sink { [weak self] name in self?.update(appName: name) }
    }

    private func update(appName: String?) {
        guard let appName else {
            shownName = nil
            panel?.orderOut(nil)
            return
        }
        let panel = ensurePanel()
        if appName != shownName {
            shownName = appName
            let host = NSHostingController(rootView: DetectionPromptView(
                appName: appName,
                onRecord: { Task { await AppState.shared.acceptDetection() } },
                onDismiss: { AppState.shared.dismissDetection() }))
            panel.contentViewController = host
            panel.setContentSize(host.view.fittingSize)
        }
        position(panel)
        panel.orderFrontRegardless() // show without activating the app
    }

    private func ensurePanel() -> FloatingPanel {
        if let panel { return panel }
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        // Meeting apps are often full-screen; ride along over them and across every Space.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false // the card draws its own rounded shadow
        self.panel = panel
        return panel
    }

    /// Top-right, just under the menu bar. The +8 nudges account for the card's transparent
    /// shadow padding so the visible card hugs the corner rather than floating off it.
    private func position(_ panel: FloatingPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: visible.maxX - size.width + 8,
            y: visible.maxY - size.height + 8))
    }
}

private struct DetectionPromptView: View {
    let appName: String
    let onRecord: () -> Void
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "record.circle.fill").foregroundStyle(Theme.raspberry)
                Text("Record this meeting?")
                    .font(.parfait(15, .semibold))
                    .foregroundStyle(Theme.ink(scheme))
            }
            Text("\(appName) is using your microphone.")
                .font(.parfait(12))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button(action: onRecord) {
                    Text("Record")
                        .font(.parfait(13, .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.raspberry)
                Button("Dismiss", action: onDismiss)
                    .font(.parfait(13))
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
        .background(Theme.surface(scheme), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        .padding(20) // transparent margin so the shadow isn't clipped by the panel bounds
    }
}
