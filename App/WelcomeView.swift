import SwiftUI

struct WelcomeView: View {
    @Bindable var model: AppModel
    var onDismiss: (() -> Void)?
    @Environment(\.dismissWindow) private var dismissWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 15) {
                PilotMark(size: 52)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Welcome to LidPilot").font(.title2.weight(.semibold))
                    Text("A small menu-bar utility for study and local work.")
                        .font(.body).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 9) {
                note("Choose a mode", "Follow Lid, Keep Screen On, or Keep Mac Running. The two closed-lid modes need the approved helper.", "laptopcomputer")
                note("Choose when it ends", "Sessions default to one hour. Pick a preset, custom length, end time, or Until I stop.", "timer")
                note("Choose when to prevent locking", "Turn on Prevent automatic lock in the menu bar for computer use. Leave it off for normal macOS locking. The display may stay on; manual Lock still works.", "lock.open")
            }
            Text("Brightness stays under your control. Battery and thermal safeguards can pause a session; keep your Mac ventilated.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Local. Open source. No analytics.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Got It") { model.onboardingComplete = true; if let onDismiss { onDismiss() } else { dismissWindow(id: "welcome") } }
                    .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
            }
        }
        .padding(28).frame(width: 520).fixedSize(horizontal: false, vertical: true).background(.regularMaterial)
    }
    private func note(_ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }
}
