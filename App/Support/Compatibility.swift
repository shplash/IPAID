import SwiftUI

extension View {
    @ViewBuilder
    func ipaidProminentButton() -> some View {
        if #available(iOS 15.0, *) {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(IPAIDProminentButtonStyle())
        }
    }

    @ViewBuilder
    func ipaidBorderedButton() -> some View {
        if #available(iOS 15.0, *) {
            self.buttonStyle(.bordered)
        } else {
            self.buttonStyle(IPAIDBorderedButtonStyle())
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
}

struct IPAIDProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.blue.opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.35))
            )
            .contentShape(Rectangle())
    }
}

struct IPAIDBorderedButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isEnabled ? .blue : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.blue.opacity(configuration.isPressed ? 0.16 : 0.08))
            )
            .contentShape(Rectangle())
    }
}
