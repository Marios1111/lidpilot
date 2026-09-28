import SwiftUI

struct WelcomeView: View {
    @Bindable var model: AppModel
    var onDismiss: (() -> Void)?
    @Environment(\.dismissWindow) private var dismissWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PilotMark(size: 54)
            VStack(alignment: .leading, spacing: 8) {
                Text("A little more time awake.").font(.system(size: 29, weight: .semibold))
                Text("Set a session for a lecture or a long task. LidPilot takes care of the keep-awake controls.").font(.body).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 16) {
                note("You choose when it starts", "LidPilot always opens Off. Set a duration and start a session.", "power")
                note("Closed-lid support is optional", "The helper needs your approval. Keep Screen On works without it.", "lock.shield")
                note("Brightness stays yours", "Use your brightness keys as usual. Keeping the screen awake can also prevent idle dimming.", "sun.max")
            }
            Text("Battery and thermal safeguards can pause a session. Keep your Mac ventilated. Automatic update checks use GitHub; installation is always manual.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("Local. Open source. No analytics.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Got It") { model.onboardingComplete = true; if let onDismiss { onDismiss() } else { dismissWindow(id: "welcome") } }
                    .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
            }
        }
        .padding(32).frame(width: 520).fixedSize(horizontal: false, vertical: true).background(.regularMaterial)
    }
    private func note(_ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon).font(.title3).foregroundStyle(.tint).frame(width: 25)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
