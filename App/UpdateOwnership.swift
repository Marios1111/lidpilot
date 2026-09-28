import Foundation
import Observation

enum UpdateMethod: String, CaseIterable, Identifiable {
    case sparkle
    case homebrew
    case manual

    var id: Self { self }

    var title: String {
        switch self {
        case .sparkle: "Sparkle"
        case .homebrew: "Homebrew"
        case .manual: "Manual"
        }
    }
}

@MainActor @Observable final class UpdateOwnership {
    private static let methodKey = "update.ownership.method"

    private(set) var method: UpdateMethod
    private(set) var isExplicitChoice: Bool
    private(set) var detectedHomebrew = false

    @ObservationIgnored private let defaults: UserDefaults

    var selectionDescription: String {
        if isExplicitChoice { return "Selected by you" }
        return detectedHomebrew ? "Detected from Homebrew installation evidence" : "Automatic default"
    }

    init(defaults: UserDefaults = .standard, bundleURL: URL = Bundle.main.bundleURL) {
        self.defaults = defaults
        if let stored = defaults.string(forKey: Self.methodKey), let method = UpdateMethod(rawValue: stored) {
            self.method = method
            isExplicitChoice = true
            detectedHomebrew = false
        } else {
            let detected = Self.hasHomebrewInstallationEvidence(bundleURL: bundleURL)
            method = detected ? .homebrew : .sparkle
            isExplicitChoice = false
            detectedHomebrew = detected
        }
    }

    func select(_ method: UpdateMethod) {
        self.method = method
        isExplicitChoice = true
        defaults.set(method.rawValue, forKey: Self.methodKey)
    }

    /// Uses only local install-path and Homebrew receipt evidence; it is a hint, not a guarantee.
    static func hasHomebrewInstallationEvidence(bundleURL: URL, fileManager: FileManager = .default) -> Bool {
        let resolvedBundle = bundleURL.resolvingSymlinksInPath().standardizedFileURL
        let roots = [
            URL(fileURLWithPath: "/opt/homebrew/Caskroom/lidpilot", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/Caskroom/lidpilot", isDirectory: true)
        ]

        for root in roots {
            if isDescendant(resolvedBundle, of: root) || isDescendant(bundleURL, of: root) { return true }

            let receiptDirectory = root.appendingPathComponent(".metadata", isDirectory: true)
            guard isNonemptyDirectory(receiptDirectory, fileManager: fileManager) else { continue }

            // A Homebrew app artifact is normally linked into /Applications. Pair that known
            // destination with the cask receipt to avoid treating a leftover receipt alone as proof.
            let bundlePath = bundleURL.standardizedFileURL.path
            if bundlePath == "/Applications/LidPilot.app" || bundlePath == "/Applications/LidPilot" {
                return true
            }
        }
        return false
    }

    private static func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        let candidateComponents = candidate.standardizedFileURL.pathComponents
        let rootComponents = root.standardizedFileURL.pathComponents
        return candidateComponents.count > rootComponents.count &&
            candidateComponents.starts(with: rootComponents)
    }

    private static func isNonemptyDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        guard let values = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]),
              !values.isEmpty else { return false }
        return true
    }
}
