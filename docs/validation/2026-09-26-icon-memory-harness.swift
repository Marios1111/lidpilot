import AppKit
import Darwin
let mode = CommandLine.arguments[1]
let bundle = Bundle(path: "/Applications/LidPilot.app")!
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
func footprint() -> UInt64 {
    var value = rusage_info_v6()
    let result = withUnsafeMutablePointer(to: &value) {
        $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
            proc_pid_rusage(getpid(), RUSAGE_INFO_V6, $0)
        }
    }
    precondition(result == 0)
    return value.ri_phys_footprint
}
let before = footprint()
guard let artwork = bundle.image(forResource: "PilotIcon") else { fatalError("Missing approved artwork") }
app.effectiveAppearance.performAsCurrentDrawingAppearance {
    if mode.hasPrefix("raster") {
        let size = mode == "raster256" ? 256 : 512
        let icon = NSImage(size: NSSize(width: size, height: size))
        icon.lockFocus()
        artwork.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        icon.unlockFocus()
        app.applicationIconImage = icon
    } else {
        precondition(mode == "direct")
        app.applicationIconImage = artwork
    }
}
usleep(200000)
print("mode=\(mode) baselineMiB=\(Double(before)/1048576) finalMiB=\(Double(footprint())/1048576)")
if let cg = app.applicationIconImage.cgImage(forProposedRect: nil, context: nil, hints: nil) { print("resolvedPixels=\(cg.width)x\(cg.height)") }
