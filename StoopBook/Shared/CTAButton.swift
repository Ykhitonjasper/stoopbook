import SwiftUI

/// Two honest weights and nothing else: the primary action is printed in ink,
/// the quiet action is a tonal slip of paper. Never a bright fill beside an outline.
struct CTAButton: View {
    enum Emphasis {
        case primary
        case quiet
        case secondary
        case destructive
    }

    let title: String
    var systemImage: String?
    var emphasis: Emphasis = .primary
    var hint: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .accessibilityHidden(true)
                }

                Text(title)
            }
            .font(AppType.rowStrong)
            .foregroundStyle(labelTone)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, AppMetrics.cardPadding)
            .background(fill, in: RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous))
        }
        .buttonStyle(PressFillStyle(tone: pressTone))
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? "")
    }

    private var fill: Color {
        switch emphasis {
        case .primary:
            return isEnabled ? AppTheme.ink : AppTheme.ink.opacity(0.28)
        case .quiet:
            return AppTheme.surfaceLow.opacity(isEnabled ? 1 : 0.5)
        case .secondary:
            return AppTheme.surface.opacity(isEnabled ? 1 : 0.5)
        case .destructive:
            return isEnabled ? AppTheme.rust : AppTheme.rust.opacity(0.3)
        }
    }

    /// The press sweeps brass across an ink button and ink across a paper one, so
    /// the control answers in its own material.
    private var pressTone: Color {
        switch emphasis {
        case .primary, .destructive:
            return AppTheme.brass.opacity(0.30)
        case .quiet, .secondary:
            return AppTheme.ink.opacity(0.09)
        }
    }

    private var labelTone: Color {
        switch emphasis {
        case .primary, .destructive:
            return isEnabled ? AppTheme.paper : AppTheme.inkSoft
        case .quiet, .secondary:
            return isEnabled ? AppTheme.ink : AppTheme.inkFaint
        }
    }
}

/// A quiet action: bare text with the drawn outward arrow. It carries secondary
/// work without competing with the page, and it is a real control, never a prop.
struct TextAction: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.inkSoft)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(AppType.rowStrong)
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.leading)

                OutwardArrow(size: 11, tone: AppTheme.brass)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressFillStyle(tone: AppTheme.ink.opacity(0.05), radius: 8))
        .accessibilityLabel(title)
    }
}

#Preview {
    ScreenScaffold {
        CTAButton(title: "Check cadence", systemImage: "clock") {}
        CTAButton(title: "Reorder the round", systemImage: "arrow.up.arrow.down", emphasis: .quiet, hint: "Opens the round builder") {}
        CTAButton(title: "Export the pack", emphasis: .secondary) {}
        TextAction(title: "Open the household card") {}
        CTAButton(title: "Needs a readout", isEnabled: false) {}
    }
}
