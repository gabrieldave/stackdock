import Cocoa

/// Iconos dibujados a mano para Descargas y Papelera.
/// Siguen la referencia visual del dock compacto: carpeta cian con flecha de descarga
/// y basurero de cristal oscuro.
enum DockSpecialIcons {

    // MARK: - Descargas

    static func downloads(size: CGFloat = 128) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        let s = size
        let cx = s * 0.52

        // Cuerpo + pestaña de la carpeta
        let tab = NSBezierPath(
            roundedRect: NSRect(x: s * 0.09, y: s * 0.585, width: s * 0.44, height: s * 0.20),
            xRadius: s * 0.07, yRadius: s * 0.07
        )
        let body = NSBezierPath(
            roundedRect: NSRect(x: s * 0.05, y: s * 0.12, width: s * 0.90, height: s * 0.58),
            xRadius: s * 0.10, yRadius: s * 0.10
        )
        tab.append(body)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = s * 0.06
        shadow.shadowOffset = NSSize(width: 0, height: -s * 0.02)
        shadow.set()

        let cyanTop = NSColor(calibratedRed: 0.36, green: 0.90, blue: 1.00, alpha: 1)
        let cyanBottom = NSColor(calibratedRed: 0.02, green: 0.52, blue: 0.83, alpha: 1)
        NSGradient(starting: cyanTop, ending: cyanBottom)?.draw(in: tab, angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        // Brillo superior
        NSGraphicsContext.saveGraphicsState()
        tab.addClip()
        NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.38),
            NSColor.white.withAlphaComponent(0.0)
        ])?.draw(in: NSRect(x: 0, y: s * 0.50, width: s, height: s * 0.34), angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        // Borde luminoso
        NSColor.white.withAlphaComponent(0.35).setStroke()
        tab.lineWidth = s * 0.012
        tab.stroke()

        // Insignia circular con flecha de descarga
        let badgeRadius = s * 0.235
        let badgeCenter = NSPoint(x: cx, y: s * 0.40)
        let badgeRect = NSRect(
            x: badgeCenter.x - badgeRadius,
            y: badgeCenter.y - badgeRadius,
            width: badgeRadius * 2,
            height: badgeRadius * 2
        )
        let badge = NSBezierPath(ovalIn: badgeRect)
        NSColor(calibratedRed: 0.02, green: 0.20, blue: 0.30, alpha: 0.94).setFill()
        badge.fill()
        NSColor(calibratedRed: 0.55, green: 0.95, blue: 1.00, alpha: 0.55).setStroke()
        badge.lineWidth = s * 0.018
        badge.stroke()

        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: cx, y: badgeCenter.y + badgeRadius * 0.52))
        arrow.line(to: NSPoint(x: cx, y: badgeCenter.y - badgeRadius * 0.30))
        arrow.move(to: NSPoint(x: cx - badgeRadius * 0.42, y: badgeCenter.y + badgeRadius * 0.02))
        arrow.line(to: NSPoint(x: cx, y: badgeCenter.y - badgeRadius * 0.34))
        arrow.line(to: NSPoint(x: cx + badgeRadius * 0.42, y: badgeCenter.y + badgeRadius * 0.02))
        arrow.lineCapStyle = .round
        arrow.lineJoinStyle = .round
        arrow.lineWidth = s * 0.055
        NSColor(calibratedRed: 0.60, green: 0.96, blue: 1.00, alpha: 1).setStroke()
        arrow.stroke()

        return image
    }

    // MARK: - Papelera

    static func trash(size: CGFloat = 128, full: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        let s = size
        let cx = s * 0.5
        let topY = s * 0.70
        let bottomY = s * 0.10
        let topHalf = s * 0.33
        let bottomHalf = s * 0.235
        let corner = s * 0.05

        let body = NSBezierPath()
        body.move(to: NSPoint(x: cx - topHalf, y: topY))
        body.line(to: NSPoint(x: cx - topHalf, y: bottomY + corner))
        body.appendArc(
            withCenter: NSPoint(x: cx - topHalf + corner, y: bottomY + corner),
            radius: corner, startAngle: 180, endAngle: 270
        )
        body.line(to: NSPoint(x: cx + bottomHalf - corner, y: bottomY))
        body.appendArc(
            withCenter: NSPoint(x: cx + bottomHalf - corner, y: bottomY + corner),
            radius: corner, startAngle: 270, endAngle: 360
        )
        body.line(to: NSPoint(x: cx + topHalf, y: topY))
        body.close()

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.40)
        shadow.shadowBlurRadius = s * 0.06
        shadow.shadowOffset = NSSize(width: 0, height: -s * 0.02)
        shadow.set()

        NSGradient(
            starting: NSColor(calibratedRed: 0.42, green: 0.48, blue: 0.55, alpha: 0.97),
            ending: NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.12, alpha: 0.98)
        )?.draw(in: body, angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        // Reflejo de cristal en el lateral izquierdo
        NSGraphicsContext.saveGraphicsState()
        body.addClip()
        let gloss = NSBezierPath(
            roundedRect: NSRect(x: cx - topHalf + s * 0.06, y: bottomY, width: s * 0.13, height: topY - bottomY),
            xRadius: s * 0.06, yRadius: s * 0.06
        )
        NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.18),
            NSColor.white.withAlphaComponent(0.01)
        ])?.draw(in: gloss, angle: 0)
        NSGraphicsContext.restoreGraphicsState()

        // Nervaduras verticales
        NSGraphicsContext.saveGraphicsState()
        body.addClip()
        NSColor.white.withAlphaComponent(0.07).setStroke()
        for dx in [-0.17, 0.0, 0.17] {
            let rib = NSBezierPath()
            rib.move(to: NSPoint(x: cx + s * CGFloat(dx), y: topY - s * 0.04))
            rib.line(to: NSPoint(x: cx + s * CGFloat(dx) * 0.80, y: bottomY + s * 0.06))
            rib.lineWidth = s * 0.012
            rib.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()

        if full {
            drawTrashContents(in: NSRect(x: cx - topHalf, y: topY - s * 0.12, width: topHalf * 2, height: s * 0.20), scale: s)
        }

        // Borde superior (aro metálico)
        let rimRect = NSRect(
            x: cx - topHalf - s * 0.025,
            y: topY - s * 0.055,
            width: (topHalf + s * 0.025) * 2,
            height: s * 0.11
        )
        let rim = NSBezierPath(ovalIn: rimRect)
        NSGradient(
            starting: NSColor(calibratedRed: 0.70, green: 0.76, blue: 0.82, alpha: 0.95),
            ending: NSColor(calibratedRed: 0.28, green: 0.33, blue: 0.39, alpha: 0.95)
        )?.draw(in: rim, angle: -90)
        NSColor.white.withAlphaComponent(0.35).setStroke()
        rim.lineWidth = s * 0.012
        rim.stroke()

        let opening = NSBezierPath(ovalIn: rimRect.insetBy(dx: s * 0.045, dy: s * 0.022))
        NSColor(calibratedRed: 0.03, green: 0.04, blue: 0.05, alpha: 0.95).setFill()
        opening.fill()

        return image
    }

    private static func drawTrashContents(in rect: NSRect, scale s: CGFloat) {
        let papers: [(NSRect, NSColor, CGFloat)] = [
            (NSRect(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.05, width: s * 0.20, height: s * 0.18),
             NSColor(calibratedRed: 0.92, green: 0.93, blue: 0.95, alpha: 0.95), -14),
            (NSRect(x: rect.minX + rect.width * 0.46, y: rect.minY + rect.height * 0.16, width: s * 0.18, height: s * 0.16),
             NSColor(calibratedRed: 0.78, green: 0.86, blue: 0.95, alpha: 0.95), 10),
            (NSRect(x: rect.minX + rect.width * 0.58, y: rect.minY, width: s * 0.15, height: s * 0.14),
             NSColor(calibratedRed: 0.96, green: 0.90, blue: 0.72, alpha: 0.95), 22)
        ]
        for (r, color, angle) in papers {
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: r.midX, yBy: r.midY)
            transform.rotate(byDegrees: angle)
            transform.translateX(by: -r.midX, yBy: -r.midY)
            transform.concat()
            color.setFill()
            NSBezierPath(roundedRect: r, xRadius: s * 0.02, yRadius: s * 0.02).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}
