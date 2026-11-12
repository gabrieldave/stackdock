import Cocoa

// MARK: - Icono del Dock (etiqueta de perfil, Shift+Clic / Doble Clic / Clic medio)

final class DockTileView: NSView {
    let iconSize: CGFloat
    var onSingleClick: (() -> Void)?
    var onTeleportTrigger: (() -> Void)?
    var onMiddleClickQuit: (() -> Void)?
    var menuBuilder: (() -> NSMenu)?

    private let imageView = NSImageView()
    private var trackingArea: NSTrackingArea?

    init(
        icon: NSImage,
        tooltipText: String,
        badgeText: String?,
        runningCount: Int,
        iconSize: CGFloat
    ) {
        self.iconSize = iconSize
        super.init(frame: NSRect(x: 0, y: 0, width: iconSize + 12, height: iconSize + 20))
        setupVisuals(icon: icon, tooltipText: tooltipText, badgeText: badgeText, runningCount: runningCount)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupVisuals(icon: NSImage, tooltipText: String, badgeText: String?, runningCount: Int) {
        wantsLayer = true
        toolTip = tooltipText

        // No mutar icon.size: rompe bitmaps compuestos (avatares de perfil).
        imageView.image = icon
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.masksToBounds = true
        imageView.layer?.cornerRadius = iconSize * 0.22
        imageView.frame = NSRect(x: 6, y: 9, width: iconSize, height: iconSize)
        addSubview(imageView)

        if let badge = badgeText, !badge.isEmpty {
            let pill = NSTextField(labelWithString: badge)
            pill.font = NSFont.systemFont(ofSize: 9.5, weight: .semibold)
            pill.textColor = .white
            pill.alignment = .center
            pill.wantsLayer = true
            pill.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
            pill.layer?.cornerRadius = 5
            pill.layer?.borderWidth = 0.5
            pill.layer?.borderColor = NSColor.white.withAlphaComponent(0.35).cgColor
            let pillWidth = min(bounds.width - 2, max(28, pill.attributedStringValue.size().width + 8))
            pill.frame = NSRect(x: (bounds.width - pillWidth) / 2, y: bounds.height - 14, width: pillWidth, height: 13)
            addSubview(pill)
        }

        if runningCount == 1 {
            addDot(atX: (bounds.width - 5) / 2)
        } else if runningCount >= 2 {
            addDot(atX: (bounds.width / 2) - 6)
            addDot(atX: (bounds.width / 2) + 2)
        }
    }

    private func addDot(atX x: CGFloat) {
        let dot = NSView(frame: NSRect(x: x, y: 3, width: 4.5, height: 4.5))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.95).cgColor
        dot.layer?.cornerRadius = 2.25
        addSubview(dot)
    }

    override func menu(for event: NSEvent) -> NSMenu? { menuBuilder?() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            imageView.animator().frame = NSRect(x: 3, y: 12, width: iconSize + 6, height: iconSize + 6)
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            imageView.animator().frame = NSRect(x: 6, y: 9, width: iconSize, height: iconSize)
        }
    }

    override func mouseDown(with event: NSEvent) {
        pulse()
        if event.modifierFlags.contains(.shift) || event.clickCount == 2 {
            onTeleportTrigger?()
            return
        }
        if event.modifierFlags.contains([.option, .command]) {
            onMiddleClickQuit?()
            return
        }
        onSingleClick?()
    }

    // Clic rueda (button 2) NO se usa: Logitech lo usa para centrar ventana.
    // Cerrar perfil: menú contextual o ⌥⌘+clic.

    private func pulse() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.06
            imageView.animator().alphaValue = 0.5
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                self.imageView.animator().alphaValue = 1.0
            }
        })
    }
}
