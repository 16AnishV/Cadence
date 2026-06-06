import AppKit

/// Renders the Cadence menu bar progress icon: a half-sun arc with N task circles
/// distributed evenly across the arc, the leftmost `done` of which are filled amber.
///
/// Geometry mirrors the SVG design references in Resources/MenubarIcons. We render
/// programmatically (rather than loading SVG/PNG assets) so the icon stays crisp at
/// any menu bar height and so the build doesn't depend on actool or rsvg-convert.
enum MenuBarIconRenderer {
    private static let amber = NSColor(srgbRed: 0xB8 / 255.0, green: 0x41 / 255.0, blue: 0x0E / 255.0, alpha: 1.0)
    private static let dark = NSColor(srgbRed: 0x2B / 255.0, green: 0x18 / 255.0, blue: 0x10 / 255.0, alpha: 1.0)
    private static let cream = NSColor(srgbRed: 0xF5 / 255.0, green: 0xEF / 255.0, blue: 0xE6 / 255.0, alpha: 1.0)

    /// Render an icon for the given progress. `total` clamped to 1...5; `done` clamped to 0...total.
    static func icon(done: Int, total: Int) -> NSImage {
        let total = max(1, min(5, total))
        let done = max(0, min(total, done))

        // Menu bar status item targets ~22pt total height. Drawing into a 28×22
        // canvas lets the half-sun + tick circles take up most of the bar's vertical
        // space while leaving a sliver of breathing room.
        let pointSize = NSSize(width: 28, height: 22)
        let image = NSImage(size: pointSize, flipped: false) { rect in
            draw(done: done, total: total, in: rect)
            return true
        }
        image.isTemplate = false   // we want amber, not auto-tinted black/white
        return image
    }

    /// All angles in degrees, measured from the positive x-axis sweeping counter-clockwise
    /// — i.e. 0° is the right edge of the arc, 90° is the top, 180° is the left edge.
    private static func tickAngles(for total: Int) -> [Double] {
        switch total {
        case 1: return [90]
        case 2: return [135, 45]
        case 3: return [150, 90, 30]
        case 4: return [157.5, 112.5, 67.5, 22.5]
        default: return [180, 135, 90, 45, 0]
        }
    }

    private static func draw(done: Int, total: Int, in rect: NSRect) {
        // Design canvas in the SVG references is 512×512 with the arc centered on
        // (256, 320) and radius 100. We map a sub-region of that canvas — the arc
        // and its tick circles — into `rect`, preserving aspect ratio.
        //
        // The arc spans x ∈ [156, 356] (200pt wide) and y ∈ [220, 334] in the
        // design canvas (top of arc to bottom of stroke). Tick circles at radius 20
        // can extend ~25pt beyond the arc bounds, so we pad the source bounding
        // box accordingly to keep them from clipping.
        let designLeft: CGFloat = 130
        let designRight: CGFloat = 382
        let designTop: CGFloat = 195
        let designBottom: CGFloat = 345
        let designWidth = designRight - designLeft     // 252
        let designHeight = designBottom - designTop    // 150

        // Fit the design region into rect, preserving aspect ratio.
        let scale = min(rect.width / designWidth, rect.height / designHeight)
        let drawnWidth = designWidth * scale
        let drawnHeight = designHeight * scale
        let offsetX = rect.minX + (rect.width - drawnWidth) / 2.0
        let offsetY = rect.minY + (rect.height - drawnHeight) / 2.0

        // Map a design-space point into the rendered rect.
        // Note: design canvas has y=0 at top (SVG convention). NSImage's drawing
        // context has y=0 at bottom. We flip y as part of the mapping.
        func map(_ designX: CGFloat, _ designY: CGFloat) -> NSPoint {
            let x = offsetX + (designX - designLeft) * scale
            let y = offsetY + (designBottom - designY) * scale
            return NSPoint(x: x, y: y)
        }

        // Sun center (design-space): (256, 320)
        let centerDesign = NSPoint(x: 256, y: 320)
        let center = map(centerDesign.x, centerDesign.y)
        let arcRadius: CGFloat = 100 * scale

        // Stroke widths in the design canvas (10 for the arc, 6 for tick strokes)
        // map proportionally. Floor at 1 to avoid disappearing strokes at small sizes.
        let arcStroke = max(1.0, 10 * scale)
        let tickStroke = max(0.8, 6 * scale)
        let tickRadiusOuter = 20 * scale  // tick circle radius (design pts → menu bar pts)

        // -- Draw the arc (half circle from 180° to 0° going over the top) --
        // appendArc treats angles as math conventions (0° right, 90° up). To sweep
        // from 180° (left) through 90° (top) to 0° (right), we go CLOCKWISE in
        // those angle terms — i.e. decreasing angle. clockwise=false would sweep
        // the other way (through 270°, the bottom half) and get clipped.
        let arcPath = NSBezierPath()
        arcPath.appendArc(
            withCenter: center,
            radius: arcRadius,
            startAngle: 180,
            endAngle: 0,
            clockwise: true
        )
        arcPath.lineWidth = arcStroke
        arcPath.lineCapStyle = .round
        dark.setStroke()
        arcPath.stroke()

        // -- Draw tick circles --
        let angles = tickAngles(for: total)
        for (idx, angleDeg) in angles.enumerated() {
            let theta = angleDeg * .pi / 180.0
            // In design space, the tick sits ON the arc at radius 100 from center.
            // Design-space y decreases going up, so we subtract sin(θ).
            let designTickX = centerDesign.x + 100 * CGFloat(cos(theta))
            let designTickY = centerDesign.y - 100 * CGFloat(sin(theta))
            let tickCenter = map(designTickX, designTickY)

            let isFilled = idx < done
            let circleRect = NSRect(
                x: tickCenter.x - tickRadiusOuter,
                y: tickCenter.y - tickRadiusOuter,
                width: tickRadiusOuter * 2,
                height: tickRadiusOuter * 2
            )
            let circle = NSBezierPath(ovalIn: circleRect)

            if isFilled {
                amber.setFill()
            } else {
                cream.setFill()
            }
            circle.fill()

            dark.setStroke()
            circle.lineWidth = tickStroke
            circle.stroke()
        }
    }
}
