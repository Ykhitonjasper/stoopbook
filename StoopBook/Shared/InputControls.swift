import SwiftUI

struct NumberField: View {
    let title: String
    @Binding private var value: String
    var unit: String?
    var prompt: String?
    var help: String?
    var error: String?

    @FocusState private var isFocused: Bool

    init(
        title: String,
        value: Binding<String>,
        unit: String? = nil,
        prompt: String? = nil,
        help: String? = nil,
        error: String? = nil
    ) {
        self.title = title
        _value = value
        self.unit = unit
        self.prompt = prompt
        self.help = help
        self.error = error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppMetrics.tightSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: AppMetrics.tightSpacing) {
                Text(title)
                    .font(AppType.rowStrong)
                    .foregroundStyle(AppTheme.ink)

                Spacer(minLength: 0)

                if let unit {
                    Text(unit)
                        .font(AppType.micro)
                        .foregroundStyle(AppTheme.data)
                }
            }

            TextField(prompt ?? title, text: $value)
                .font(AppType.figure(21))
                .foregroundStyle(AppTheme.ink)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, AppMetrics.inputVerticalPadding)
                .background {
                    let shape = RoundedRectangle(cornerRadius: AppMetrics.controlRadius, style: .continuous)
                    shape
                        .fill(AppTheme.surfaceLow.opacity(0.7))
                        .overlay {
                            shape.strokeBorder(
                                error != nil ? AppTheme.rust : (isFocused ? AppTheme.brass : AppTheme.ink.opacity(0.08)),
                                lineWidth: isFocused || error != nil ? 1.4 : 1
                            )
                        }
                        .clipShape(shape)
                }
                .accessibilityLabel(title)
                .accessibilityHint(help ?? "")

            if let help, error == nil {
                Text(help)
                    .font(AppType.caption)
                    .foregroundStyle(AppTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error {
                InlineError(message: error)
            }
        }
    }
}

struct SegmentOption: Identifiable, Hashable {
    let id: String
    let title: String

    init(_ title: String, id: String? = nil) {
        self.id = id ?? title
        self.title = title
    }
}

/// A recessed track with one ink slab that slides between choices. The movement is
/// the only motion, and the labels are always readable in every state.
struct SegmentedPicker: View {
    let title: String
    let options: [SegmentOption]
    @Binding private var selection: String
    var help: String?

    @Namespace private var indicator

    init(
        title: String,
        options: [SegmentOption],
        selection: Binding<String>,
        help: String? = nil
    ) {
        self.title = title
        self.options = options
        _selection = selection
        self.help = help
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppMetrics.tightSpacing) {
            Text(title)
                .font(AppType.rowStrong)
                .foregroundStyle(AppTheme.ink)

            HStack(spacing: 0) {
                ForEach(options) { option in
                    Button {
                        withAnimation(AppMotion.quick) {
                            selection = option.id
                        }
                    } label: {
                        Text(option.title)
                            .font(AppType.rowStrong)
                            .foregroundStyle(selection == option.id ? AppTheme.paper : AppTheme.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppMetrics.segmentVerticalPadding)
                            .background {
                                if selection == option.id {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(AppTheme.ink)
                                        .matchedGeometryEffect(id: "segment", in: indicator)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityHint(help ?? "")
                    .accessibilityAddTraits(selection == option.id ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(3)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(AppTheme.surfaceLow.opacity(0.85))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

struct InlineError: View {
    let message: String
    var systemImage = "exclamationmark.triangle.fill"

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .accessibilityHidden(true)

            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(AppType.caption.weight(.medium))
        .foregroundStyle(AppTheme.rust)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    InputControlsPreview()
}

private struct InputControlsPreview: View {
    @State private var distance = "18.5"
    @State private var unit = "metric"

    var body: some View {
        ScreenScaffold {
            NumberField(
                title: "Cluster radius",
                value: $distance,
                unit: "m",
                prompt: "250",
                help: "Metres around each seed pin."
            )

            SegmentedPicker(
                title: "Units",
                options: [SegmentOption("Metric", id: "metric"), SegmentOption("Imperial", id: "imperial")],
                selection: $unit
            )

            InlineError(message: "Enter a value greater than zero.")
        }
    }
}
