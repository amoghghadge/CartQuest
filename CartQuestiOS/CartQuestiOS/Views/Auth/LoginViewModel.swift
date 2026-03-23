import Foundation
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

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

    @MainActor
    func signInWithGoogle() {
        authState = .loading
        Task {
            do {
                guard let clientID = FirebaseApp.app()?.options.clientID else {
                    authState = .error("Missing Firebase client ID")
                    return
                }

                let config = GIDConfiguration(clientID: clientID)
                GIDSignIn.sharedInstance.configuration = config

                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let rootViewController = windowScene.windows.first?.rootViewController else {
                    authState = .error("Cannot find root view controller")
                    return
                }

                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

                guard let idToken = result.user.idToken?.tokenString else {
                    authState = .error("Missing Google ID token")
                    return
                }

                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )

                let authResult = try await Auth.auth().signIn(with: credential)
                try await userRepository.createUserDocument(user: authResult.user)
                authState = .authenticated(authResult.user)
            } catch {
                authState = .error(error.localizedDescription)
            }
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        authState = .unauthenticated
    }
}
