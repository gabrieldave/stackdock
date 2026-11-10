import Cocoa

final class DockGlassBarView: NSVisualEffectView {
    var menuProvider: (() -> NSMenu)?
    override func menu(for event: NSEvent) -> NSMenu? { menuProvider?() }
}
