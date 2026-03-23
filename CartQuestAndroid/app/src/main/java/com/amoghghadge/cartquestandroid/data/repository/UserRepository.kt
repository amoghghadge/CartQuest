package com.amoghghadge.cartquestandroid.data.repository

import com.amoghghadge.cartquestandroid.data.model.User
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.ktx.Firebase
import kotlinx.coroutines.tasks.await

class UserRepository {
    private val db = Firebase.firestore

    suspend fun createUserDocument(user: FirebaseUser) {
        val userData = User(
            uid = user.uid,
            email = user.email ?: "",
            displayName = user.displayName ?: "",
            photoUrl = user.photoUrl?.toString() ?: ""
        )
        db.collection("users").document(user.uid).set(userData).await()
    }
}
