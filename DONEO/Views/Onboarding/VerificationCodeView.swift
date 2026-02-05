import SwiftUI

struct VerificationCodeView: View {
    let phoneNumber: String
    @Binding var code: String
    let onVerify: () -> Void
    let onResend: () -> Void
    let onBack: () -> Void
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "message.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.primary)

                Text("Verifica tu número")
                    .font(.system(size: 24, weight: .bold))

                Text("Enviamos un código a \(phoneNumber)")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Code input
            VStack(alignment: .leading, spacing: 8) {
                Text("Ingresa el código de verificación")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("000000", text: $code)
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .focused($isCodeFocused)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: code) { _, newValue in
                        // Limit to 6 digits
                        if newValue.count > 6 {
                            code = String(newValue.prefix(6))
                        }
                        // Auto-verify when 6 digits entered
                        if code.count == 6 {
                            onVerify()
                        }
                    }

                // Hint for demo
                Text("Para la demo, usa el código: 123456")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // Verify button
            Button(action: onVerify) {
                Text("Verificar")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(code.count == 6 ? Theme.primary : Theme.primary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(code.count != 6)

            // Resend option
            Button(action: onResend) {
                Text("¿No recibiste el código? Reenviar")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.primary)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 24)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            isCodeFocused = true
        }
    }
}

#Preview {
    NavigationStack {
        VerificationCodeView(
            phoneNumber: "+1 555-0100",
            code: .constant(""),
            onVerify: {},
            onResend: {},
            onBack: {}
        )
    }
}
