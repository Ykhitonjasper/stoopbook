import SwiftUI

/// A filter is a tab, not a pill. Weight and ink carry the active state, and a
/// rounded brass rule sits under it rather than a badge around it.
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(isSelected ? AppType.rowStrong : AppType.row)
                .foregroundStyle(isSelected ? AppTheme.ink : AppTheme.inkSoft)
                .lineLimit(1)
                .padding(.bottom, 7)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(isSelected ? AppTheme.brass : .clear)
                        .frame(height: 2)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A strip of filters that behaves like one physical indicator: the brass rule
/// travels from the tab you left to the tab you chose, instead of blinking out in
/// one place and appearing in another. One namespace, one rule, always the full
/// width of the label it belongs to.
struct TabStrip<Item: Identifiable>: View {
    let items: [Item]
    let title: (Item) -> String
    let isSelected: (Item) -> Bool
    let onSelect: (Item) -> Void
    var spacing: CGFloat = 16

    @Namespace private var rule
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ChipRow(spacing: spacing) {
            ForEach(items) { item in
                let selected = isSelected(item)
                Button {
                    withAnimation(reduceMotion ? nil : AppMotion.slide) {
                        onSelect(item)
                    }
                } label: {
                    Text(title(item))
                        .font(selected ? AppType.rowStrong : AppType.row)
                        .foregroundStyle(selected ? AppTheme.ink : AppTheme.inkSoft)
                        .lineLimit(1)
                        .padding(.bottom, 7)
                        .overlay(alignment: .bottom) {
                            if selected {
                                Capsule()
                                    .fill(AppTheme.brass)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "tab.rule", in: rule)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(item))
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

struct ChipRow<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: spacing) {
                content
            }
            .padding(.vertical, 2)
            .padding(.trailing, AppMetrics.screenPadding)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

#Preview {
    ScreenScaffold {
        ChipRow {
            FilterChip(title: "North Loop", isSelected: true) {}
            FilterChip(title: "Overdue", isSelected: false) {}
            FilterChip(title: "Window clash", isSelected: false) {}
        }
        ChipRow(spacing: 14) {
            Text("North Loop").font(AppType.micro).foregroundStyle(AppTheme.data)
            Text("240 min").font(AppType.micro).foregroundStyle(AppTheme.data)
            Text("5 overdue").font(AppType.micro).foregroundStyle(AppTheme.data)
        }
    }
}
