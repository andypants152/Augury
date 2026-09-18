import CoreGraphics

/// Lays a spread's cards out in a rect — the pure, unit-testable half of M7.
///
/// A spread specifies each position in *card units* (one unit = the card's
/// own width, so a card is 1 wide by 16/9 tall, at a center point, with an
/// optional rotation). `frames` finds the spec's rotation-aware bounding
/// box, scales it to fit the offered rect as large as it can, and centers
/// the result — every card keeps the draft's 9:16 ratio, and the cross's
/// ten face-down cards fit whatever space the table's chrome leaves, down to
/// the smallest iPhone (the roadmap's M7 bar; pinned in `SpreadTests`).
///
/// The engine returns each card's *unrotated* frame, centered on its spec
/// point; the view applies the position's rotation with `rotationEffect`
/// (a drawing-only transform about the same center). The bounding
/// computation below already accounts for rotated cards, so a 90° crossing
/// card never spills outside the rect.
enum SpreadLayout {

    /// A card's height in card widths — the draft's 540×960 canvas, 9:16.
    /// (Kept in step with `Spread.cardHeight`; both name the same draft.)
    static let cardHeight = 16.0 / 9.0

    /// Points reserved below the laid-out cards for the position labels that
    /// the big one- and three-card slots draw under each card. The cross
    /// labels nothing (its panel names the positions), so it reserves none.
    static let labelInset: CGFloat = 26

    /// The on-screen frame for each dealt card, in position order.
    ///
    /// `bottomInset` (points, default `labelInset`) is reserved along the
    /// rect's *bottom* edge — the card area is the space above it — so the
    /// cards and the labels beneath them both fit, and the block stays
    /// optically centered in the space the cards themselves use.
    static func frames(for spread: Spread, in size: CGSize, bottomInset: CGFloat = labelInset) -> [CGRect] {
        let avail = CGSize(width: size.width, height: size.height - bottomInset)
        guard avail.width > 0, avail.height > 0, !spread.positions.isEmpty else { return [] }

        // The spec's bounding box in card units, rotation-aware.
        var minX = Double.greatestFiniteMagnitude, minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
        for p in spread.positions {
            let (bw, bh) = bounds(of: p)
            minX = min(minX, p.x - bw / 2); maxX = max(maxX, p.x + bw / 2)
            minY = min(minY, p.y - bh / 2); maxY = max(maxY, p.y + bh / 2)
        }
        let specW = maxX - minX
        let specH = maxY - minY
        let scale = min(avail.width / specW, avail.height / specH)
        let w = scale
        let h = scale * cardHeight

        // Center the scaled spec in the (inset) space.
        let offX = (avail.width - specW * scale) / 2 - minX * scale
        let offY = (avail.height - specH * scale) / 2 - minY * scale

        return spread.positions.map { p in
            let cx = offX + p.x * scale
            let cy = offY + p.y * scale
            return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
        }
    }

    /// The rotation-aware bounding box of one position's card, in card units:
    /// how much space a 1 × (16/9) card at `p.rotation` actually occupies.
    static func bounds(of p: SpreadPosition) -> (width: Double, height: Double) {
        let r = p.rotation * .pi / 180
        let c = abs(cos(r)), s = abs(sin(r))
        return (c + s * cardHeight, s + c * cardHeight)
    }
}
