import Foundation
import LidPilotRuntime

do {
    guard let configuration = HelperIdentity.helperConfiguration() else {
        throw RuntimeFailure.unavailable("The helper bundle identity is not recognized; privileged service startup is disabled.")
    }
    let team = try HelperIdentity.ownTeam()
    let clock = SystemClock()
    let journal = try RecoveryJournal.privileged()
    let engine = HelperEngine(driver: try journal.makePowerDriver(), sampler: SystemPowerSampler(clock: clock),
                              journal: journal, clock: clock,
                              build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unconfigured")
    let delegate = try HelperService(engine: engine, configuration: configuration, team: team)
    let listener = NSXPCListener(machServiceName: configuration.serviceIdentifier)
    listener.delegate = delegate
    delegate.startWatchdog()
    listener.resume()
    withExtendedLifetime((delegate, listener)) { RunLoop.current.run() }
} catch {
    // launchd retains the failure status. Never enable sleep prevention with an invalid identity/journal.
    FileHandle.standardError.write(Data("LidPilot helper could not initialize: \(error.localizedDescription)\n".utf8))
    exit(EXIT_FAILURE)
}
