import SwiftUI

struct ResultLine: Identifiable {
    let id: String
    let label: String
    let value: String

    init(label: String, value: String) {
        id = label
        self.label = label
        self.value = value
    }
}

struct ResultCard: View {
    let title: String
    let value: String
    var unit: String?
    var lines: [ResultLine] = []
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppMetrics.contentSpacing) {
            Text(title)
                .font(AppType.rowStrong)
                .foregroundStyle(AppTheme.inkSoft)

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(value)
                    .font(AppType.figure(34))
                    .tracking(0.4)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let unit {
                    Text(unit)
                        .font(AppType.meta)
                        .foregroundStyle(AppTheme.data)
                }
            }
            .accessibilityElement(children: .combine)

            if !lines.isEmpty {
                VStack(spacing: 8) {
                    ForEach(lines) { line in
                        DetailRow(label: line.label, value: line.value)
                    }
                }
                .padding(.top, 2)
            }

            if let note {
                Text(note)
                    .font(AppType.caption)
                    .foregroundStyle(AppTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardSurface()
    }
}

#Preview {
    ScreenScaffold {
        ResultCard(
            title: "Morning book",
            value: "228",
            unit: "min",
            lines: [
                ResultLine(label: "Circuit", value: "North Loop active circuit"),
                ResultLine(label: "Completed", value: "3 of 8")
            ],
            note: "Planned from dwell and pin-to-pin bins, not a live fix."
        )
    }
}
