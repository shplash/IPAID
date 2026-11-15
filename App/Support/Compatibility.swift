import SwiftUI

extension View {
    @ViewBuilder
    func ipaidProminentButton(_ tint: Color = .blue) -> some View {
        if #available(iOS 15.0, *) {
            self.buttonStyle(.borderedProminent).tint(tint)
        } else {
            self.buttonStyle(IPAIDProminentButtonStyle(tint: tint))
        }
    }

    @ViewBuilder
    func ipaidBorderedButton(_ tint: Color = .blue) -> some View {
        if #available(iOS 15.0, *) {
            self.buttonStyle(.bordered).tint(tint)
        } else {
            self.buttonStyle(IPAIDBorderedButtonStyle(tint: tint))
        }
    }

    @ViewBuilder
    func ipaidMonospacedDigits() -> some View {
        if #available(iOS 15.0, *) {
            self.monospacedDigit()
        } else {
            self
        }
    }

    @ViewBuilder
    func ipaidSmallControl() -> some View {
        if #available(iOS 15.0, *) {
            self.controlSize(.small)
        } else {
            self.scaleEffect(0.8)
        }
    }

    @ViewBuilder
    func ipaidOnSubmit(_ action: @escaping () -> Void) -> some View {
        if #available(iOS 15.0, *) {
            self.onSubmit(action)
        } else {
            self
        }
    }

    func ipaidGlassButton(_ tint: Color = .blue) -> some View {
        self.buttonStyle(IPAGlassButtonStyle(tint: tint))
    }
}

struct IPAGlassButtonStyle: ButtonStyle {
    var tint: Color = .blue

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isEnabled ? tint : .secondary)
            .background(glass(pressed: configuration.isPressed))
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func glass(pressed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        if #available(iOS 15.0, *) {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(tint.opacity(pressed ? 0.26 : 0.16)))
                .overlay(shape.strokeBorder(tint.opacity(0.22), lineWidth: 1))
        } else {
            shape.fill(tint.opacity(pressed ? 0.30 : 0.18))
        }
    }
}

struct IPAIDProminentButtonStyle: ButtonStyle {
    var tint: Color = .blue

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.35))
            )
            .contentShape(Rectangle())
    }
}

struct IPAIDBorderedButtonStyle: ButtonStyle {
    var tint: Color = .blue

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isEnabled ? tint : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.16 : 0.08))
            )
            .contentShape(Rectangle())
    }
}
