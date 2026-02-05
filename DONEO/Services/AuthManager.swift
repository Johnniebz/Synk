import Foundation
import Observation

enum AuthState {
    case unknown
    case unauthenticated
    case verifying(phoneNumber: String)
    case authenticated(user: User)
}

@Observable
final class AuthManager {
    static let shared = AuthManager()

    var authState: AuthState = .unknown
    var verificationCode: String = ""

    private init() {
        checkExistingAuth()
    }

    private func checkExistingAuth() {
        // In a real app, check keychain/UserDefaults for existing session
        // For MVP, start as unauthenticated
        authState = .unauthenticated
    }

    var isAuthenticated: Bool {
        if case .authenticated = authState {
            return true
        }
        return false
    }

    var currentUser: User? {
        if case .authenticated(let user) = authState {
            return user
        }
        return nil
    }

    // MARK: - Auth Flow

    func requestVerification(phoneNumber: String) {
        // In a real app, send SMS verification code
        // For MVP, just move to verifying state
        authState = .verifying(phoneNumber: phoneNumber)
        // Generate a mock code (in production, this comes from backend)
        verificationCode = "123456"
    }

    func verifyCode(_ code: String) -> Bool {
        // In a real app, verify with backend
        // For MVP, accept the mock code
        guard code == verificationCode else {
            return false
        }

        if case .verifying(let phoneNumber) = authState {
            // Create or fetch user
            let user = User(
                name: "New User",
                phoneNumber: phoneNumber
            )
            authState = .authenticated(user: user)
            return true
        }
        return false
    }

    func updateUserName(_ name: String) {
        if case .authenticated(var user) = authState {
            user.name = name
            authState = .authenticated(user: user)
        }
    }

    func signOut() {
        authState = .unauthenticated
        verificationCode = ""
    }
}
