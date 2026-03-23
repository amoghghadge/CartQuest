import Foundation
import FirebaseAuth
import FirebaseFirestore

class CartRepository {
    private lazy var db = Firestore.firestore()

    private func cartsCollection() -> CollectionReference {
        guard let uid = Auth.auth().currentUser?.uid else {
            fatalError("User must be authenticated to access carts")
        }
        return db.collection("users").document(uid).collection("carts")
    }

    func getActiveCart() async throws -> Cart? {
        let snapshot = try await cartsCollection()
            .whereField("status", isEqualTo: "active")
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else { return nil }
        var cart = try doc.data(as: Cart.self)
        cart.id = doc.documentID
        return cart
    }

    func saveCart(_ cart: Cart) async throws -> Cart {
        var cartToSave = cart
        cartToSave.updatedAt = Date()

        let docRef: DocumentReference
        if cart.id.isEmpty {
            docRef = cartsCollection().document()
            cartToSave.id = docRef.documentID
        } else {
            docRef = cartsCollection().document(cart.id)
        }

        try docRef.setData(from: cartToSave)
        return cartToSave
    }

    func completeCart(cartId: String) async throws {
        try await cartsCollection().document(cartId).updateData(["status": "completed"])
    }
}
