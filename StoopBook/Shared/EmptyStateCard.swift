import SwiftUI

/// An empty screen still belongs to this brand: one bare mark, one clear line,
/// and a real action. No stock placeholder, no box around the mark.
struct EmptyStateCard: View {
    let title: String
    let message: String
    /// A screen may name its own mark. Without one, the house mark stands in.
    var systemImage: String? = nil
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(AppTheme.ink.opacity(0.5))
                    .accessibilityHidden(true)
                    .padding(.bottom, 4)
            } else {
                StoopMark(size: 40, tone: AppTheme.ink.opacity(0.45))
                    .padding(.bottom, 2)
            }

            Text(title)
                .font(AppType.title)
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)

            Text(message)
                .font(AppType.caption)
                .foregroundStyle(AppTheme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                TextAction(title: actionTitle, action: action)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, AppMetrics.cardPadding)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    ScreenScaffold {
        EmptyStateCard(
            title: "Nobody overdue",
            message: "Every household on this round is inside its cadence window.",
            systemImage: nil,
            actionTitle: "Check cadence anyway"
        ) {}
    }
}
