import Foundation
import FirebaseAuth
import FirebaseFirestore

// Typealias to disambiguate our app's User model from FirebaseAuth.User
private typealias AppUser = User

class UserRepository {
    private let db = Firestore.firestore()

    func createUserDocument(user: FirebaseAuth.User) async throws {
        let userData = AppUser(
            id: user.uid,
            email: user.email ?? "",
            displayName: user.displayName ?? "",
            photoUrl: user.photoURL?.absoluteString ?? ""
        )
        try await db.collection("users").document(user.uid).setData([
            "uid": userData.id,
            "email": userData.email,
            "displayName": userData.displayName,
            "photoUrl": userData.photoUrl,
            "createdAt": Timestamp(date: userData.createdAt)
        ])
    }
}
