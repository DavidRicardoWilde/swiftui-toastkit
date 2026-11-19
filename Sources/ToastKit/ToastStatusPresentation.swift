import SwiftUI

// MARK: - Status → presentation

/// Turns a `ToastMessage.Status` into pixels, given a theme.
///
/// The theme supplies one hue per status; everything here derives from it at fixed
/// opacities. That split is what keeps the component shareable: a host retunes a status
/// by changing a colour, and the *proportions* — how much hue reaches the surface, how
/// far the edge fades, how strong the glow — stay consistent across every app that
/// adopts the kit.
extension ToastMessage.Status {

    var symbolName: String {
        switch self {
        case .normal:       "info.circle.fill"
        case .warning:      "exclamationmark.triangle.fill"
        case .error:        "xmark.octagon.fill"
        case .notification: "bell.badge.fill"
        }
    }

    func tint(in theme: ToastTheme) -> Color {
        theme.tint(self)
    }

    /// Hue laid over the neutral fill.
    ///
    /// `normal` is deliberately clear: "nothing is wrong" is best said by *not*
    /// colouring the surface, and a grey wash would only muddy the blur. Neutral is its
    /// scheme, and it is what distinguishes it from the three that carry a hue.
    func surfaceWash(in theme: ToastTheme) -> Color {
        switch self {
        case .normal:       .clear
        case .warning:      tint(in: theme).opacity(0.16)
        case .error:        tint(in: theme).opacity(0.16)
        case .notification: tint(in: theme).opacity(0.14)
        }
    }

    /// Far end of the edge gradient. The near end stays white — that is the specular
    /// highlight — so the border reads as light catching a tinted pane.
    func edgeTint(in theme: ToastTheme) -> Color {
        self == .normal ? .white.opacity(0.10) : tint(in: theme).opacity(0.45)
    }

    /// Border under Increase Contrast, where the gradient edge is dropped. A hued status
    /// keeps its colour at full strength rather than falling back to grey: system
    /// semantic colours already clear the contrast bar, and the hue is information.
    func contrastBorder(in theme: ToastTheme) -> Color {
        self == .normal ? theme.borderSubtle : tint(in: theme)
    }

    /// Coloured halo under the card, on top of the grounding shadow. Clear for `normal`,
    /// which makes the second shadow a no-op rather than a special case.
    func glow(in theme: ToastTheme) -> Color {
        self == .normal ? .clear : tint(in: theme).opacity(0.30)
    }
}

// MARK: - Glass surface

/// The toast's frosted panel, tinted by status.
///
/// Three stacked layers: the theme's material, its neutral fill, then the status wash.
///
/// Both decorative layers are dropped under the accessibility settings that exist to
/// suppress them — the sheen reads as a smear once the surface behind it is opaque, and
/// the gradient edge loses to a solid border at Increase Contrast. The status wash
/// survives both: it is the only layer carrying meaning, so it must not be an effect
/// that can be switched off.
struct ToastGlassSurface: ViewModifier {
    let status: ToastMessage.Status
    /// Riding the action track: a thinner pane with no sheen and a soft shadow, so the
    /// band and its colours stay visible through the card.
    var lifted = false

    @Environment(\.toastTheme) private var theme
    @Environment(\.toastMetrics) private var metrics
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let cornerRadius = metrics.resolved(in: theme).cornerRadius
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background { surface(shape) }
            .overlay { sheen(in: shape) }
            .overlay { edge(shape) }
            .clipShape(shape)
            .shadow(
                color: lifted ? .black.opacity(0.1) : theme.shadow.color,
                radius: lifted ? 9 : theme.shadow.radius,
                y: lifted ? 6 : theme.shadow.y
            )
            .shadow(color: lifted ? .clear : status.glow(in: theme), radius: 18, y: 6)
    }

    private func surface(_ shape: RoundedRectangle) -> some View {
        ZStack {
            if reduceTransparency {
                // An opaque base under a translucent wash is still opaque, so the status
                // hue survives without reintroducing see-through.
                shape.fill(theme.opaqueSurfaceFill)
            } else if lifted {
                shape.fill(theme.liftedMaterial)
            } else {
                shape.fill(theme.material)
                shape.fill(theme.surfaceFill)
            }
            shape.fill(status.surfaceWash(in: theme))
        }
    }

    @ViewBuilder
    private func sheen(in shape: RoundedRectangle) -> some View {
        if !reduceTransparency && !lifted {
            shape
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.34), .white.opacity(0.05), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func edge(_ shape: RoundedRectangle) -> some View {
        if contrast == .increased {
            shape.strokeBorder(status.contrastBorder(in: theme), lineWidth: 1)
        } else {
            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.55), status.edgeTint(in: theme)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
                .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Frosted panel drawn by `GlassToastStyle`, tinted by `status`. `lifted` thins
    /// it while the card rides the long-press action track.
    func toastGlassSurface(status: ToastMessage.Status, lifted: Bool = false) -> some View {
        modifier(ToastGlassSurface(status: status, lifted: lifted))
    }
}
