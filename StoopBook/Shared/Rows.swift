import SwiftUI

/// A definition row for prose: what it is, and what it says.
struct DetailRow: View {
    let label: String
    let value: String
    var isProminent = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppMetrics.contentSpacing) {
            Text(label)
                .font(AppType.row)
                .foregroundStyle(AppTheme.inkSoft)

            Spacer(minLength: AppMetrics.tightSpacing)

            Text(value)
                .font(isProminent ? AppType.rowStrong : AppType.row)
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A measured row: printed-leader dots between the label and its figure, the way a
/// ledger sets a table. Use this only where the value is genuinely data.
struct LedgerRow: View {
    let label: String
    let value: String
    var tone: Color = AppTheme.data

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(label)
                .font(AppType.row)
                .foregroundStyle(AppTheme.inkSoft)
                .layoutPriority(1)

            LeaderDots()
                .frame(height: 1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 6)
                .offset(y: -3)
                .accessibilityHidden(true)

            Text(value)
                .font(AppType.data)
                .foregroundStyle(tone)
                .multilineTextAlignment(.trailing)
                .layoutPriority(2)
                .rollingFigure()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LeaderDots: View {
    var body: some View {
        Canvas { context, size in
            guard size.width > 6 else { return }
            let spacing: CGFloat = 4
            var path = Path()
            var x: CGFloat = 1
            while x <= size.width - 1 {
                path.addEllipse(in: CGRect(x: x, y: 0, width: 1, height: 1))
                x += spacing
            }
            context.fill(path, with: .color(AppTheme.ink.opacity(0.34)))
        }
    }
}

/// A tappable line inside a printed index. One card holds many of these, so the
/// page never turns into a field of identical floating boxes.
struct IndexRow: View {
    let title: String
    var detail: String?
    var trailing: String?
    var accentTone: Color = AppTheme.data
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AppMetrics.contentSpacing) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppType.rowStrong)
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.leading)

                    if let detail {
                        Text(detail)
                            .font(AppType.caption)
                            .foregroundStyle(AppTheme.inkSoft)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    if let trailing {
                        Text(trailing)
                            .font(AppType.micro)
                            .foregroundStyle(accentTone)
                            .multilineTextAlignment(.trailing)
                            .rollingFigure()
                    }

                    OutwardArrow(tone: AppTheme.ink.opacity(0.42))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressFillStyle(tone: AppTheme.ink.opacity(0.05), radius: 8))
        .accessibilityLabel([title, detail, trailing].compactMap { $0 }.joined(separator: ", "))
        .padding(.horizontal, -6)
    }
}

/// A hairline that separates rows inside one printed index.
struct IndexRule: View {
    var body: some View {
        Capsule()
            .fill(AppTheme.edge)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct NavigationRow: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var trailingText: String?
    var hint: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AppMetrics.contentSpacing) {
                HStack(alignment: .top, spacing: AppMetrics.contentSpacing) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.inkSoft)
                            .frame(width: 16, alignment: .leading)
                            .padding(.top, 2)
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(AppType.rowStrong)
                            .foregroundStyle(AppTheme.ink)
                            .multilineTextAlignment(.leading)

                        if let subtitle {
                            Text(subtitle)
                                .font(AppType.caption)
                                .foregroundStyle(AppTheme.inkSoft)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    if let trailingText {
                        Text(trailingText)
                            .font(AppType.micro)
                            .foregroundStyle(AppTheme.data)
                            .multilineTextAlignment(.trailing)
                    }

                    OutwardArrow(tone: AppTheme.ink.opacity(0.42))
                        .padding(.top, 1)
                }
            }
            .cardSurface(padding: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(hint ?? "")
    }

    private var accessibilityText: String {
        [title, subtitle, trailingText]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

#Preview {
    ScreenScaffold {
        NavigationRow(
            title: "River Stoop 4B",
            subtitle: "River Blocks · 8:00–11:00 · street west side",
            systemImage: "mappin",
            trailingText: "5 of 7d",
            hint: "Opens the household card"
        ) {}

        SectionCard(title: "Load") {
            LedgerRow(label: "Dwell", value: "228 min")
            LedgerRow(label: "Slack", value: "12 min", tone: AppTheme.sage)
            DetailRow(label: "Estimate", value: "Planning figures from stored pins", isProminent: true)
        }
    }
}
