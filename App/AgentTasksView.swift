import SwiftUI
import LidPilotCore
import LidPilotRuntime

/// The same switch and status in Settings and the menu bar. Turning it off only
/// withdraws agent requests; manual sessions and supervised commands keep running.
struct AgentTaskControl: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Agent Tasks", systemImage: "bolt.circle")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Toggle("Keep awake for agent tasks", isOn: Binding(get: { model.controller.integrationsArmed }, set: { model.armTasks($0) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .disabled(model.changingAgentTasks || (!model.controller.integrationsArmed && !model.canEnableAgentTasks))
            }
            Text(model.agentTaskStatus).font(.system(size: 11, weight: .medium))
                .foregroundStyle(model.controller.protectedWorkloads.contains { $0.source != .command } ? Color.green : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(model.agentTaskHint).font(.system(size: 10.5)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let error = model.controlError, model.cliEnabled {
                Text(error).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct WorkloadActivityView: View {
    let model: AppModel
    var agents = true
    var limit = 3

    private var protectedIDs: Set<String> { Set(model.controller.protectedWorkloads.map(\.id)) }
    private var records: [WorkloadRecord] {
        let held = protectedIDs
        return model.controller.workloads.records.filter { ($0.source != .command) == agents }.sorted {
            if held.contains($0.id) != held.contains($1.id) { return held.contains($0.id) }
            return $0.updatedAt.continuousSeconds > $1.updatedAt.continuousSeconds
        }
    }
    var body: some View {
        ForEach(Array(records.prefix(limit))) { record in
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: protectedIDs.contains(record.id) ? "bolt.fill" : (record.state == .unknown ? "questionmark.circle" : "circle"))
                    .foregroundStyle(record.state == .unknown ? Color.orange : .secondary)
                    .accessibilityHidden(true)
                Text(record.source.agentTitle + (record.taskID == nil ? "" : " · subtask"))
                Spacer(minLength: 4)
                Text(stateLabel(record)).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }.font(.system(size: 11)).accessibilityElement(children: .combine)
        }
        if records.count > limit {
            Text("\(records.count - limit) more · all task details in Diagnostics")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
    private func stateLabel(_ record: WorkloadRecord) -> String {
        let held = protectedIDs.contains(record.id)
        switch record.state {
        case .working: return held ? "Working · awake" : "Not protected"
        case .waiting: return held ? "Waiting · grace period" : "Waiting · released"
        case .idle: return held ? "Turn ending · awake" : "Turn ended"
        case .finished: return "Ended"
        case .failed: return "Failed"
        case .unknown: return "Unknown · released"
        }
    }
}

struct AgentTasksSettings: View {
    @Bindable var model: AppModel
    private var configurationLocked: Bool { model.controller.integrationsArmed || model.controller.hasSession || model.controller.updateBarrier }

    var body: some View {
        Section {
            AgentTaskControl(model: model)
            Toggle("Show Agent Tasks in the menu bar", isOn: $model.showAgentControls)
            Text("Hidden controls reappear while Agent Tasks is on. Switching off agent protection keeps manual sessions and command tasks running.")
                .font(.caption).foregroundStyle(.secondary)
            if let message = model.agentSetupMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
        }
        Section("Connect Codex") {
            connection(.codex)
        }
        Section("Task behavior") {
            Picker("While an agent works", selection: $model.workloadMode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.title).tag($0) }
            }.disabled(configurationLocked)
            Text("Turn on Agent Tasks before starting a new turn. Launch, Turn Off All Requests, and safety pauses switch it off again.")
                .font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("Waiting & missing events") {
                Picker("Release after waiting", selection: $model.waitingGrace) {
                    ForEach([30.0, 60, 120, 300, 600], id: \.self) { Text($0 < 60 ? "30 seconds" : "\(Int($0 / 60)) minutes").tag($0) }
                }.disabled(model.controller.hasSession)
                Picker("If events go missing", selection: $model.staleAfter) {
                    ForEach([60.0, 300, 900, 1800], id: \.self) { Text("\(Int($0 / 60)) minutes").tag($0) }
                }.disabled(model.controller.hasSession)
                Text("Missing events are marked unknown, never finished. Turns settle for 3 seconds; each task has an 8-hour maximum.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        Section {
            DisclosureGroup("Claude Code") { connection(.claude) }
        }
    }

    @ViewBuilder private func connection(_ source: WorkloadSource) -> some View {
        let installation = model.hookInstallations[source] ?? .missing
        HStack {
            Label(model.hookSetupErrors[source] != nil ? "Cannot read configuration" : (installation == .installed ? "Hooks installed" : (installation == .needsRepair ? "Connection needs repair" : "Not set up in this folder")),
                  systemImage: installation == .installed ? "checkmark.circle" : "circle.dashed")
            Spacer()
            Text("Experimental").font(.caption).foregroundStyle(.secondary)
            Button("Refresh") { model.refreshHookSetup() }.controlSize(.small)
        }
        if let date = model.lastHookReceived[source] {
            LabeledContent("Last event received") { Text(date, style: .time).monospacedDigit() }
        } else {
            Text("No event received in this monitoring period.").font(.caption).foregroundStyle(.secondary)
        }
        if let error = model.hookSetupErrors[source] { Text(error).font(.caption).foregroundStyle(.orange) }
        HStack {
            if installation == .installed && !model.cliEnabled {
                Button("Enable Local Connection") { model.cliEnabled = true }
            }
            Button(installation == .installed ? "Repair Connection" : "Connect \(source.agentTitle)") { model.configureAgent(source, install: true) }
            if installation != .missing {
                Button("Remove Connection") { model.configureAgent(source, install: false) }
            }
        }.disabled(configurationLocked || model.isPreview)
        Text("Connect adds LidPilot's hooks and lets programs running as your Mac user control LidPilot. Other hooks stay unchanged. Protection starts with the switch above.")
            .font(.caption).foregroundStyle(.secondary)
        if source == .codex {
            Text("Next: review and trust the new hooks in Codex, then turn on Agent Tasks above and start a new local turn. Until an event arrives, delivery is unconfirmed.")
                .font(.caption).foregroundStyle(.secondary)
            Link("Codex hook review instructions ↗", destination: URL(string: "https://developers.openai.com/codex/hooks/#review-and-trust-hooks")!)
                .font(.caption)
        } else {
            Text("Restart Claude Code after connecting. Some turn endings cannot be matched safely, so protection may continue until the missing-event limit.")
                .font(.caption).foregroundStyle(.secondary)
        }
        DisclosureGroup("Configuration & compatibility") {
            Text((model.hookConfigURL(source).path as NSString).abbreviatingWithTildeInPath)
                .font(.caption.monospaced()).textSelection(.enabled)
            Button("Choose Config Folder…") { model.chooseHookConfig(source) }.disabled(configurationLocked || model.isPreview)
            Text("Experimental · \(source.agentTitle) adapter \(HookSignal.versions[source] ?? "unknown"). Local tasks only; cloud and remote tasks are not monitored. Prompts and transcripts are never stored.")
                .font(.caption).foregroundStyle(.secondary)
            if source == .codex {
                Text("If your desktop build has no hook review, use /hooks in Codex CLI with this same configuration. LidPilot never changes Codex's trust or permission settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

extension WorkloadSource {
    var agentTitle: String {
        switch self { case .codex: "Codex"; case .claude: "Claude Code"; case .command: "Command" }
    }
}
