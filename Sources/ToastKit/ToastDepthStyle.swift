import CoreGraphics

/// How a card at a given depth is drawn: the scale, opacity and blur of the pile.
///
/// Shared by live cards and the stand-ins that animate a removal, so a card that leaves
/// starts from exactly the look it had.
struct ToastDepthStyle: Equatable {
    let depth: Int

    init(depth: Int) {
        self.depth = depth
    }

    var scale: CGFloat { 1 - 0.05 * CGFloat(depth) }
    var opacity: Double { 1 - 0.16 * Double(depth) }
    /// A hair of defocus on buried cards.
    var blur: CGFloat { depth == 0 ? 0 : 1.4 }
}
