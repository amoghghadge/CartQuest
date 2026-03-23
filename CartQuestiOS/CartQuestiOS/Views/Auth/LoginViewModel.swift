import Foundation
import FirebaseAuth

enum AuthState: Equatable {
    case unauthenticated
    case loading
    case authenticated(FirebaseAuth.User)
    case error(String)

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.unauthenticated, .unauthenticated), (.loading, .loading):
            return true
        case (.authenticated(let a), .authenticated(let b)):
            return a.uid == b.uid
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

@Observable
class LoginViewModel {
    var authState: AuthState = .unauthenticated
    var email: String = ""
    var password: String = ""
    var displayName: String = ""
    var isSignUp: Bool = false

    private let userRepository = UserRepository()

    init() {
        if let user = Auth.auth().currentUser {
            authState = .authenticated(user)
        }
    }

    func signInWithEmail() {
        authState = .loading
        Task {
            do {
                let result = try await Auth.auth().signIn(withEmail: email, password: password)
                await MainActor.run {
                    authState = .authenticated(result.user)
                }
            } catch {
                await MainActor.run {
                    authState = .error(error.localizedDescription)
                }
            }
        }
    }

    func signUpWithEmail() {
        authState = .loading
        Task {
            do {
                let result = try await Auth.auth().createUser(withEmail: email, password: password)
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
                try await userRepository.createUserDocument(user: result.user)
                await MainActor.run {
                    authState = .authenticated(result.user)
                }
            } catch {
                await MainActor.run {
                    authState = .error(error.localizedDescription)
                }
            }
        }
    }

    func signInWithGoogle() {
        // TODO: Implement Google Sign-In once GoogleSignIn-iOS SPM package is added
        // Will use GIDSignIn to get ID token, then:
        // let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        // try await Auth.auth().signIn(with: credential)
    }

    func signOut() {
        try? Auth.auth().signOut()
        authState = .unauthenticated
    }
}
