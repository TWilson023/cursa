import AppKit
import SwiftUI

struct WelcomeView: View {
    @Bindable var appState: AppState
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            VStack(spacing: 6) {
                Text("Welcome to Cursa")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text("Cursor motion presets for screen recordings.")
                    .foregroundStyle(.secondary)
            }

            Text("Cursa drives the system cursor along configurable paths — Circle, Figure-8, and Line. macOS requires Accessibility permission to synthesize mouse events.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            permissionStatus

            actionButton

            if !appState.hasAccessibilityPermission {
                Text("This window will update automatically once permission is granted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(width: 480)
    }

    // MARK: - Subviews

    private var permissionStatus: some View {
        HStack(spacing: 12) {
            Image(systemName: appState.hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(appState.hasAccessibilityPermission ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility Access")
                    .fontWeight(.medium)
                Text(appState.hasAccessibilityPermission ? "Granted" : "Not granted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var actionButton: some View {
        if appState.hasAccessibilityPermission {
            Button("Get Started") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        } else {
            Button("Open System Settings") {
                AccessibilityChecker.openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
