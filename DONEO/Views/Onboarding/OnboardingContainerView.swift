import SwiftUI

enum OnboardingStep {
    case phone
    case verification
    case profile
    case firstProject
}

struct OnboardingContainerView: View {
    @State private var currentStep: OnboardingStep = .phone
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var userName: String = ""
    @State private var firstProjectName: String = ""
    @State private var firstProjectDescription: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    let onComplete: (_ projectName: String?, _ projectDescription: String?) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                switch currentStep {
                case .phone:
                    PhoneEntryView(
                        phoneNumber: $phoneNumber,
                        onContinue: handlePhoneSubmit
                    )
                case .verification:
                    VerificationCodeView(
                        phoneNumber: phoneNumber,
                        code: $verificationCode,
                        onVerify: handleVerification,
                        onResend: handleResend,
                        onBack: { currentStep = .phone }
                    )
                case .profile:
                    ProfileSetupView(
                        name: $userName,
                        onContinue: handleProfileSetup
                    )
                case .firstProject:
                    FirstProjectView(
                        projectName: $firstProjectName,
                        projectDescription: $firstProjectDescription,
                        onCreateProject: handleCreateProject,
                        onSkip: handleComplete
                    )
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func handlePhoneSubmit() {
        let cleaned = phoneNumber.filter { $0.isNumber || $0 == "+" }
        guard cleaned.count >= 10 else {
            errorMessage = "Por favor ingresa un número de teléfono válido"
            showError = true
            return
        }
        AuthManager.shared.requestVerification(phoneNumber: phoneNumber)
        currentStep = .verification
    }

    private func handleVerification() {
        if AuthManager.shared.verifyCode(verificationCode) {
            currentStep = .profile
        } else {
            errorMessage = "Código de verificación inválido. Intenta 123456"
            showError = true
        }
    }

    private func handleResend() {
        AuthManager.shared.requestVerification(phoneNumber: phoneNumber)
        verificationCode = ""
    }

    private func handleProfileSetup() {
        guard !userName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Por favor ingresa tu nombre"
            showError = true
            return
        }
        AuthManager.shared.updateUserName(userName)
        currentStep = .firstProject
    }

    private func handleCreateProject() {
        guard !firstProjectName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Por favor ingresa un nombre de proyecto"
            showError = true
            return
        }
        // Pass project info to the main app for creation
        let description = firstProjectDescription.trimmingCharacters(in: .whitespaces).isEmpty ? nil : firstProjectDescription
        onComplete(firstProjectName, description)
    }

    private func handleComplete() {
        // Skipping project creation
        onComplete(nil, nil)
    }
}
