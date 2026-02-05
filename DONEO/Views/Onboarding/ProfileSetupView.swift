import SwiftUI

struct ProfileSetupView: View {
    @Binding var name: String
    let onContinue: () -> Void
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.primary)

                Text("¿Cómo te llamas?")
                    .font(.system(size: 24, weight: .bold))

                Text("Así es como te verán los demás")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Tu nombre")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Juan Pérez", text: $name)
                    .font(.system(size: 20))
                    .textContentType(.name)
                    .focused($isNameFocused)
                    .submitLabel(.continue)
                    .onSubmit(onContinue)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Continue button
            Button(action: onContinue) {
                Text("Continuar")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        name.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Theme.primary.opacity(0.5)
                        : Theme.primary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 24)
        .onAppear {
            isNameFocused = true
        }
    }
}

#Preview {
    ProfileSetupView(name: .constant(""), onContinue: {})
}
