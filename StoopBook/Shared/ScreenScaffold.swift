import SwiftUI

struct ScreenScaffold<Content: View>: View {
    private let spacing: CGFloat
    private let scrolls: Bool
    private let content: Content

    /// The named space the page measures its own scroll in.
    private static var rakeSpace: String { "stoopbook.page" }

    @State private var rake: CGFloat = 0

    init(
        spacing: CGFloat = AppMetrics.sectionSpacing,
        scrolls: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.scrolls = scrolls
        self.content = content()
    }

    var body: some View {
        ZStack {
            AppBackground(rake: rake)

            if scrolls {
                ScrollView {
                    stack
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: PageRakeKey.self,
                                    value: proxy.frame(in: .named(Self.rakeSpace)).minY
                                )
                            }
                        }
                }
                .coordinateSpace(.named(Self.rakeSpace))
                .scrollDismissesKeyboard(.interactively)
                .onPreferenceChange(PageRakeKey.self) { offset in
                    // A few points of drift, capped: depth, not a bouncy background.
                    rake = min(max(offset * 0.14, -26), 26)
                }
            } else {
                stack
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var stack: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(.horizontal, AppMetrics.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, AppMetrics.screenPadding * 2)
    }
}

/// A masthead, not a hero. Serif title, and under it one line of measured fact
/// rather than a second sentence of marketing.
///
/// The navigation bar already names the screen, so this names the *subject*: a
/// round, a household, a sheet. Where a screen has nothing to say that the bar has
/// not said, pass only the measured line instead of printing the same word twice.
struct ScreenHeader: View {
    var title: String?
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(AppType.masthead)
                    .foregroundStyle(AppTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let subtitle {
                Text(subtitle)
                    .font(AppType.meta)
                    .foregroundStyle(AppTheme.data)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // A survey baseline under the masthead: it finds its length once, and the
            // brass lead shows where the measurement starts.
            ZStack(alignment: .leading) {
                DrawnRule(tone: AppTheme.ink.opacity(0.15), duration: 0.55)
                DrawnRule(tone: AppTheme.brass, height: 1.6, duration: 0.42, delay: 0.14, width: 26)
            }
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The one sentence a screen is allowed to explain itself with, set quietly
/// against the paper rather than inside a box.
struct ScreenNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppType.caption)
            .foregroundStyle(AppTheme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    ScreenScaffold {
        ScreenHeader(
            title: "The morning line",
            subtitle: "North Loop · 8 stoops · 240 min · 5 overdue"
        )
        ScreenNote(text: "Planning figures come from stored pins, not live location.")
        Text("Section body")
            .foregroundStyle(AppTheme.ink)
            .cardSurface()
    }
}
