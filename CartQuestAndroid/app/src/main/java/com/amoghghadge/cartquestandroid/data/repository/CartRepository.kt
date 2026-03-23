package com.amoghghadge.cartquestandroid.data.repository

import com.amoghghadge.cartquestandroid.data.model.Cart
import com.google.firebase.auth.ktx.auth
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.firestore.ktx.toObject
import com.google.firebase.ktx.Firebase
import kotlinx.coroutines.tasks.await

class CartRepository {
    private val db = Firebase.firestore
    private val auth = Firebase.auth

    private fun cartsCollection() =
        db.collection("users").document(auth.currentUser!!.uid).collection("carts")

    suspend fun getActiveCart(): Cart? {
        val snapshot = cartsCollection()
            .whereEqualTo("status", "active")
            .limit(1)
            .get().await()
        return snapshot.documents.firstOrNull()?.let { doc ->
            doc.toObject<Cart>()?.copy(id = doc.id)
        }
    }

    suspend fun saveCart(cart: Cart): Cart {
        val docRef = if (cart.id.isEmpty()) cartsCollection().document() else cartsCollection().document(cart.id)
        val savedCart = cart.copy(id = docRef.id, updatedAt = System.currentTimeMillis())
        docRef.set(savedCart).await()
        return savedCart
    }

    suspend fun completeCart(cartId: String) {
        cartsCollection().document(cartId).update("status", "completed").await()
    }
}
