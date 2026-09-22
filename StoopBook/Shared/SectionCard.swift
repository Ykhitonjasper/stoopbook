import SwiftUI

struct SectionCard<Content: View>: View {
    private let title: String?
    private let footnote: String?
    private let content: Content

    init(title: String? = nil, footnote: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footnote = footnote
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppMetrics.contentSpacing) {
            if let title {
                Text(title)
                    .font(AppType.title)
                    .foregroundStyle(AppTheme.ink)
            }

            content

            if let footnote {
                Text(footnote)
                    .font(AppType.caption)
                    .foregroundStyle(AppTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardSurface()
    }
}

/// A section head that carries its own count, in data type.
struct SectionLabel: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppMetrics.contentSpacing) {
            Text(title)
                .font(AppType.title)
                .foregroundStyle(AppTheme.ink)

            Spacer(minLength: 0)

            if let detail {
                Text(detail)
                    .font(AppType.meta)
                    .foregroundStyle(AppTheme.data)
                    .rollingFigure()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ScreenScaffold {
        SectionLabel(title: "Morning rounds", detail: "8")
        SectionCard(title: "Load", footnote: "Planning estimate from dwell and pin-to-pin bins.") {
            LedgerRow(label: "Dwell", value: "228 min")
            LedgerRow(label: "Budget", value: "240 min")
        }
    }
}
