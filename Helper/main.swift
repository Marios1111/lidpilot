import Foundation
import LidPilotRuntime

do {
    let team = try HelperIdentity.ownTeam()
    let clock = SystemClock()
    let journal = try RecoveryJournal.privileged()
    let engine = HelperEngine(driver: try journal.makePowerDriver(), sampler: SystemPowerSampler(clock: clock),
                              journal: journal, clock: clock,
                              build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unconfigured")
    let delegate = try HelperService(engine: engine, team: team)
    let listener = NSXPCListener(machServiceName: HelperIdentity.helperID)
    listener.delegate = delegate
    delegate.startWatchdog()
    listener.resume()
    withExtendedLifetime((delegate, listener)) { RunLoop.current.run() }
} catch {
    // launchd retains the failure status. Never enable sleep prevention with an invalid identity/journal.
    FileHandle.standardError.write(Data("LidPilot helper could not initialize: \(error.localizedDescription)\n".utf8))
    exit(EXIT_FAILURE)
}
