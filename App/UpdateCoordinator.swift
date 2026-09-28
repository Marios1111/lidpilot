import AppKit
import Observation
import ServiceManagement
import Sparkle
import LidPilotRuntime

@MainActor protocol UpdateCoordinatorHelper: AnyObject {
    var signed: Bool { get }
    var enabled: Bool { get }
    var status: SMAppService.Status { get }
    func register()
    func unregister() async throws
}

extension HelperManager: UpdateCoordinatorHelper {}

@MainActor protocol UpdateCoordinatorModel: AnyObject {
    var controller: SessionController { get }
    var onboardingComplete: Bool { get }
    var updateMethod: UpdateMethod { get }
    var updateHelper: any UpdateCoordinatorHelper { get }
    func refreshHelper()
}

extension UpdateCoordinatorModel {
    var updateMethod: UpdateMethod { .sparkle }
}

extension AppModel: UpdateCoordinatorModel {
    var updateMethod: UpdateMethod { updateOwnership.method }
    var updateHelper: any UpdateCoordinatorHelper { helper }
}

#if LIDPILOT_TESTING
@MainActor protocol UpdateCoordinatorTestUpdater: AnyObject {
    var canCheckForUpdates: Bool { get }
    var automaticallyChecksForUpdates: Bool { get set }
    func checkForUpdates()
}
#endif

/// Keep one standard Sparkle controller. Update checks are allowed only while LidPilot is Off.
/// The whole install-capable cycle remains gated before Sparkle can present an update.
@MainActor @Observable final class UpdateCoordinator: NSObject, SPUUpdaterDelegate {
    private static let allowedFeedURLs = [
        "https://lidpilot.app/updates/appcast.xml",
        "https://lidpilot.app/rc/appcast.xml",
        "https://marios1111.github.io/lidpilot/rc/appcast.xml"
    ]
    private static let sparkleAutomaticPreferenceKey = "update.sparkle.automaticChecks"

    @ObservationIgnored private weak var model: (any UpdateCoordinatorModel)?
    @ObservationIgnored private var standard: SPUStandardUpdaterController?
    private var preparing = false
    private var prepared = false
    private var installationCommitted = false
    private var restoreHelper = false
    @ObservationIgnored private let defaults: UserDefaults
    private let build: String
    @ObservationIgnored private let lidIsOpen: @MainActor () -> Bool
    @ObservationIgnored private var cycleCleanupScheduled = false
    @ObservationIgnored private var appliedUpdateMethod: UpdateMethod = .sparkle
#if LIDPILOT_TESTING
    @ObservationIgnored private var testUpdater: (any UpdateCoordinatorTestUpdater)?
#endif
    private(set) var configured = false
    private(set) var status = "Updates will be available in publisher-signed releases."
    private(set) var canCheck = false
    @ObservationIgnored private var capabilityObservation: NSKeyValueObservation?

    var isBusy: Bool { preparing || prepared || installationCommitted || cycleCleanupScheduled }

    var automaticChecks: Bool {
        get {
            guard model?.updateMethod == .sparkle else { return false }
            return updaterAutomaticChecks
        }
        set {
            guard model?.updateMethod == .sparkle else { return }
            setUpdaterAutomaticChecks(newValue)
            defaults.set(newValue, forKey: Self.sparkleAutomaticPreferenceKey)
        }
    }

    private var updaterAutomaticChecks: Bool {
#if LIDPILOT_TESTING
        if let testUpdater { return testUpdater.automaticallyChecksForUpdates }
#endif
        return standard?.updater.automaticallyChecksForUpdates ?? false
    }

    private func setUpdaterAutomaticChecks(_ enabled: Bool) {
#if LIDPILOT_TESTING
        if let testUpdater {
            testUpdater.automaticallyChecksForUpdates = enabled
            return
        }
#endif
        standard?.updater.automaticallyChecksForUpdates = enabled
    }

    init(model: AppModel) {
        self.model = model
        defaults = .standard
        appliedUpdateMethod = model.updateMethod
        if model.updateMethod != .sparkle { status = Self.ownershipStatus(model.updateMethod) }
        build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unconfigured"
        lidIsOpen = { SystemPowerSampler().sample().lid == .open }
        super.init()
        guard let configuration = HelperIdentity.applicationConfiguration() else {
            if model.updateMethod == .sparkle { status = "Updates are unavailable for this app identity." }
            return
        }
        guard configuration.isProduction else {
            if model.updateMethod == .sparkle { status = "Updates are disabled in development builds." }
            return
        }
        guard !model.isPreview, let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              Self.allowedFeedURLs.contains(feed),
              let url = URL(string: feed), url.scheme == "https",
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              !feed.contains("REPLACE"),
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32, model.helper.signed else { return }
        configured = true
        standard = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        restoreOrDisableAutomaticChecks(for: model.updateMethod)
        capabilityObservation = standard?.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshCheckAvailability(preserveSparkleStatus: true)
            }
        }
        if defaults.string(forKey: "updatePendingBuild") != nil {
            model.controller.holdInterruptedUpdate()
        }
        standard?.startUpdater()
        refreshCheckAvailability()
        Task { await reconcilePreviousUpdate() }
    }

#if LIDPILOT_TESTING
    init(testing model: any UpdateCoordinatorModel, defaults: UserDefaults, build: String,
         updater: any UpdateCoordinatorTestUpdater, lidIsOpen: @escaping @MainActor () -> Bool) {
        self.model = model
        self.defaults = defaults
        self.build = build
        self.testUpdater = updater
        self.lidIsOpen = lidIsOpen
        super.init()
        appliedUpdateMethod = model.updateMethod
        configured = true
        restoreOrDisableAutomaticChecks(for: model.updateMethod)
        refreshCheckAvailability()
        if defaults.string(forKey: "updatePendingBuild") != nil {
            model.controller.holdInterruptedUpdate()
        }
    }

    func reconcilePreviousUpdateForTesting() async {
        await reconcilePreviousUpdate()
    }

    func authorizeUpdateCheckForTesting(_ kind: SPUUpdateCheck) throws {
        try authorizeUpdateCheck(kind)
    }

    func commitInstallationForTesting() {
        commitInstallation()
    }

    func finishUpdateCycleForTesting(error: (any Error)?) {
        finishUpdateCycle(error: error)
    }

    func waitForUpdateCycleCleanupForTesting() async {
        while cycleCleanupScheduled { await Task.yield() }
    }
#endif

    private var updaterCanCheck: Bool {
#if LIDPILOT_TESTING
        if let testUpdater { return testUpdater.canCheckForUpdates }
#endif
        return standard?.updater.canCheckForUpdates ?? false
    }

    private func refreshCheckAvailability(preserveSparkleStatus: Bool = false) {
        guard let model else {
            canCheck = false
            return
        }
        switch model.updateMethod {
        case .sparkle:
            canCheck = configured && updaterCanCheck
            if configured && !preserveSparkleStatus { status = "Signed updates. Manual installation." }
        case .homebrew:
            canCheck = false
            status = Self.ownershipStatus(.homebrew)
        case .manual:
            canCheck = false
            status = Self.ownershipStatus(.manual)
        }
    }

    private static func ownershipStatus(_ method: UpdateMethod) -> String {
        switch method {
        case .sparkle: "Signed updates. Manual installation."
        case .homebrew: "Updates are managed by Homebrew. Sparkle checks are off."
        case .manual: "Updates are managed manually. Sparkle checks are off."
        }
    }

    private func restoreOrDisableAutomaticChecks(for method: UpdateMethod) {
        guard method != .sparkle else {
            if let saved = defaults.object(forKey: Self.sparkleAutomaticPreferenceKey) as? Bool {
                setUpdaterAutomaticChecks(saved)
            } else {
                defaults.set(updaterAutomaticChecks, forKey: Self.sparkleAutomaticPreferenceKey)
            }
            return
        }

        if defaults.object(forKey: Self.sparkleAutomaticPreferenceKey) == nil {
            defaults.set(updaterAutomaticChecks, forKey: Self.sparkleAutomaticPreferenceKey)
        }
        setUpdaterAutomaticChecks(false)
    }

    /// Reapplies ownership without replacing the existing Sparkle updater instance.
    /// Call after the user selects a method and only when no update cycle is active.
    @discardableResult
    func refreshUpdateOwnership() -> Bool {
        guard let model else { return false }
        let method = model.updateMethod
        guard method != appliedUpdateMethod else {
            refreshCheckAvailability()
            return true
        }
        guard !isBusy else {
            status = "Finish or cancel the current update activity before changing update ownership."
            return false
        }

        if appliedUpdateMethod == .sparkle && method != .sparkle {
            defaults.set(updaterAutomaticChecks, forKey: Self.sparkleAutomaticPreferenceKey)
        }
        restoreOrDisableAutomaticChecks(for: method)
        appliedUpdateMethod = method
        refreshCheckAvailability()
        return true
    }

    private func checkForUpdates() {
#if LIDPILOT_TESTING
        if let testUpdater {
            testUpdater.checkForUpdates()
            return
        }
#endif
        standard?.checkForUpdates(nil)
    }

    func check() {
        guard let model else { return }
        guard model.updateMethod == .sparkle else {
            refreshCheckAvailability()
            return
        }
        guard configured, !preparing, !installationCommitted, updaterCanCheck else { return }
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
                let helper = model.updateHelper
                restoreHelper = restoreHelper || helper.enabled || defaults.bool(forKey: "updateRestoreHelper")
                defaults.set(restoreHelper, forKey: "updateRestoreHelper")
                defaults.set(build, forKey: "updatePendingBuild")
                try await helper.unregister()
                model.refreshHelper()
                guard lidIsOpen() else {
                    throw RuntimeFailure.unavailable("Keep the lid open to update LidPilot.")
                }
                prepared = true
                status = "LidPilot is Off while the update window is open."
                checkForUpdates()
            } catch {
                status = error.localizedDescription
                await finishPreparation(error: status)
            }
        }
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        try authorizeUpdateCheck(updateCheck)
    }

    private func authorizeUpdateCheck(_ updateCheck: SPUUpdateCheck) throws {
        guard model?.updateMethod == .sparkle else {
            refreshCheckAvailability()
            throw updateError("Sparkle is not the selected update method.")
        }
        guard model?.onboardingComplete == true else {
            throw updateError("Finish the welcome screen before checking for updates.")
        }
        guard model?.controller.hasSession == false else {
            throw updateError("Turn LidPilot Off before checking for updates.")
        }
    }

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate updateItem: SUAppcastItem, updateCheck: SPUUpdateCheck) throws {
        guard let model else { throw updateError("LidPilot is unavailable for this update.") }
        guard model.updateMethod == .sparkle else {
            refreshCheckAvailability()
            throw updateError("Sparkle is not the selected update method.")
        }
        guard prepared, model.controller.updateBarrier, !model.controller.hasSession,
              model.controller.assertions == .off, lidIsOpen(),
              model.updateHelper.status == .notRegistered || model.updateHelper.status == .notFound else {
            status = "An update is available. Turn LidPilot Off, then choose Check for Updates to install."
            throw updateError(status)
        }
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        commitInstallation()
    }

    private func commitInstallation() {
        guard model?.updateMethod == .sparkle else {
            refreshCheckAvailability()
            return
        }
        // The pre-download gate already holds the barrier and the helper has been unregistered.
        installationCommitted = true
        status = "Update ready. LidPilot will restart Off."
    }

    func updater(_ updater: SPUUpdater, userDidMake choice: SPUUserUpdateChoice, forUpdate updateItem: SUAppcastItem, state: SPUUserUpdateState) {
        if state.stage == .installing { commitInstallation() }
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
        finishUpdateCycle(error: error)
    }

    private func finishUpdateCycle(error: (any Error)?) {
        guard prepared || preparing else { return }
        // A staged install can survive dismissing the dialog and install on quit. Keep its barrier.
        guard !installationCommitted, !cycleCleanupScheduled else { return }
        cycleCleanupScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { cycleCleanupScheduled = false }
            await finishPreparation(error: error?.localizedDescription)
        }
    }

    var canTerminate: Bool {
        guard let model, model.updateMethod == .sparkle else { return false }
        guard model.controller.updateBarrier else { return true }
        return prepared && !model.controller.hasSession && model.controller.assertions == .off &&
            lidIsOpen() &&
            (model.updateHelper.status == .notRegistered || model.updateHelper.status == .notFound)
    }

    private func reconcilePreviousUpdate() async {
        guard let model else { return }
        restoreHelper = defaults.bool(forKey: "updateRestoreHelper")
        guard let previous = defaults.string(forKey: "updatePendingBuild") else {
            if restoreHelper { status = "Approve or repair the helper in Settings after the previous update." }
            return
        }
        if previous == build {
            if model.updateMethod != .sparkle {
                await finishPreparation(error: "The interrupted Sparkle update was cleaned up because updates are managed by \(model.updateMethod.title).")
                return
            }
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
        let helper = model.updateHelper
        if restoreHelper {
            helper.register()
            model.refreshHelper()
        }
        defaults.removeObject(forKey: "updatePendingBuild")
        // Keep this repair hint until registration succeeds, including after a failed update.
        if !restoreHelper || helper.enabled {
            defaults.removeObject(forKey: "updateRestoreHelper")
            restoreHelper = false
        }
        model.controller.endUpdate(error: error)
        await model.controller.refreshWhileOff()
        if let error {
            status = error
        } else if restoreHelper {
            status = "Update finished. Approve or repair the helper in Settings."
        } else {
            refreshCheckAvailability()
        }
    }

    private func updateError(_ message: String) -> NSError {
        NSError(domain: "com.lidpilot.update", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
