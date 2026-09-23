import AppKit
import Observation
import Sparkle
import LidPilotRuntime

/// Keep one standard Sparkle controller. Gate the whole install-capable cycle before presenting it.
/// Background checks may discover updates during a session; they cannot enter the install path.
@MainActor @Observable final class UpdateCoordinator: NSObject, SPUUpdaterDelegate {
    private weak var model: AppModel?
    private var standard: SPUStandardUpdaterController?
    private var preparing = false
    private var prepared = false
    private var installationCommitted = false
    private var restoreHelper = false
    private let defaults = UserDefaults.standard
    private let build: String
    private(set) var configured = false
    private(set) var status = "Updates will be available in publisher-signed releases."
    private(set) var canCheck = false
    private var capabilityObservation: NSKeyValueObservation?

    var automaticChecks: Bool {
        get { standard?.updater.automaticallyChecksForUpdates ?? false }
        set { standard?.updater.automaticallyChecksForUpdates = newValue }
    }

    init(model: AppModel) {
        self.model = model
        build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unconfigured"
        super.init()
        guard !model.isPreview, let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed), url.scheme == "https", url.host?.hasSuffix(".github.io") == true,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              !feed.contains("REPLACE"),
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32, model.helper.signed else { return }
        configured = true
        standard = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        capabilityObservation = standard?.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            let value = updater.canCheckForUpdates
            Task { @MainActor in self?.canCheck = value }
        }
        if defaults.string(forKey: "updatePendingBuild") != nil {
            model.controller.holdInterruptedUpdate()
        }
        standard?.startUpdater()
        status = "Signed updates. Manual installation."
        Task { await reconcilePreviousUpdate() }
    }

    func check() {
        guard configured, let standard, let model, !preparing, !installationCommitted,
              standard.updater.canCheckForUpdates else { return }
        // Sparkle can show a synchronous error alert after shouldProceed rejects an update.
        // Its modal loop can delay our assertion renewal task until the alert is dismissed.
        guard !model.controller.hasSession else {
            status = "Turn LidPilot Off before checking for updates."
            return
        }
        preparing = true
        Task { @MainActor in
            defer { preparing = false }
            do {
                if model.controller.updateBarrier { model.controller.endUpdate() }
                try await model.controller.beginUpdate()
                model.refreshHelper()
                restoreHelper = restoreHelper || model.helper.enabled || defaults.bool(forKey: "updateRestoreHelper")
                defaults.set(restoreHelper, forKey: "updateRestoreHelper")
                defaults.set(build, forKey: "updatePendingBuild")
                try await model.helper.unregister()
                model.refreshHelper()
                guard SystemPowerSampler().sample().lid == .open else {
                    throw RuntimeFailure.unavailable("Keep the lid open to update LidPilot.")
                }
                prepared = true
                status = "LidPilot is Off while the update window is open."
                standard.checkForUpdates(nil)
            } catch {
                status = error.localizedDescription
                await finishPreparation(error: status)
            }
        }
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard model?.onboardingComplete == true else {
            throw updateError("Finish the welcome screen before checking for updates.")
        }
        guard model?.controller.hasSession == false else {
            throw updateError("Turn LidPilot Off before checking for updates.")
        }
    }

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate updateItem: SUAppcastItem, updateCheck: SPUUpdateCheck) throws {
        guard let model, prepared, model.controller.updateBarrier, !model.controller.hasSession,
              model.controller.assertions == .off, SystemPowerSampler().sample().lid == .open,
              model.helper.status == .notRegistered || model.helper.status == .notFound else {
            status = "An update is available. Turn LidPilot Off, then choose Check for Updates to install."
            throw updateError(status)
        }
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        // The pre-download gate already holds the barrier and the helper has been unregistered.
        installationCommitted = true
        status = "Update ready. LidPilot will restart Off."
    }

    func updater(_ updater: SPUUpdater, userDidMake choice: SPUUserUpdateChoice, forUpdate updateItem: SUAppcastItem, state: SPUUserUpdateState) {
        if state.stage == .installing { installationCommitted = true }
    }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
                 untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard canTerminate else {
            status = "Open the lid to finish the update."
            Task { @MainActor in
                while self.prepared && !self.canTerminate {
                    try? await Task.sleep(for: .seconds(2))
                }
                if self.prepared { installHandler() }
            }
            return true
        }
        return false
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        guard prepared || preparing else { return }
        // A staged install can survive dismissing the dialog and install on quit. Keep its barrier.
        guard !installationCommitted else { return }
        Task { await finishPreparation(error: error?.localizedDescription) }
    }

    var canTerminate: Bool {
        guard let model, model.controller.updateBarrier else { return true }
        return prepared && !model.controller.hasSession && model.controller.assertions == .off &&
            SystemPowerSampler().sample().lid == .open &&
            (model.helper.status == .notRegistered || model.helper.status == .notFound)
    }

    private func reconcilePreviousUpdate() async {
        guard let model else { return }
        restoreHelper = defaults.bool(forKey: "updateRestoreHelper")
        guard let previous = defaults.string(forKey: "updatePendingBuild") else {
            if restoreHelper { status = "Approve or repair the helper in Settings after the previous update." }
            return
        }
        if previous == build {
            // An interrupted staged update must be resolved before new sessions are permitted.
            model.controller.holdInterruptedUpdate()
            status = "A previous update was interrupted. Choose Check for Updates to finish it."
        } else {
            await finishPreparation(error: nil)
        }
    }

    private func finishPreparation(error: String?) async {
        guard let model else { return }
        prepared = false
        if restoreHelper {
            model.helper.register()
            model.refreshHelper()
        }
        defaults.removeObject(forKey: "updatePendingBuild")
        // Keep this repair hint until registration succeeds, including after a failed update.
        if !restoreHelper || model.helper.enabled {
            defaults.removeObject(forKey: "updateRestoreHelper")
            restoreHelper = false
        }
        model.controller.endUpdate(error: error)
        await model.controller.refreshWhileOff()
        status = error ?? (restoreHelper ? "Update finished. Approve or repair the helper in Settings." : "Signed updates. Manual installation.")
    }

    private func updateError(_ message: String) -> NSError {
        NSError(domain: "com.lidpilot.update", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
