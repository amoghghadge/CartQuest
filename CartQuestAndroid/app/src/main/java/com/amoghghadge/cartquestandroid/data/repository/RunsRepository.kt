package com.amoghghadge.cartquestandroid.data.repository

import com.amoghghadge.cartquestandroid.data.model.CompletedRun
import com.google.firebase.firestore.Query
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.firestore.ktx.snapshots
import com.google.firebase.firestore.ktx.toObject
import com.google.firebase.ktx.Firebase
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.tasks.await

class RunsRepository {
    private val db = Firebase.firestore

    suspend fun saveCompletedRun(run: CompletedRun): String {
        val docRef = db.collection("runs").document()
        docRef.set(run.copy(id = docRef.id)).await()
        return docRef.id
    }

    suspend fun getRunById(runId: String): CompletedRun? {
        val doc = db.collection("runs").document(runId).get().await()
        return doc.toObject<CompletedRun>()?.copy(id = doc.id)
    }

    fun getRecentRuns(limit: Int = 20): Flow<List<CompletedRun>> {
        return db.collection("runs")
            .orderBy("completedAt", Query.Direction.DESCENDING)
            .limit(limit.toLong())
            .snapshots()
            .map { snapshot ->
                snapshot.documents.mapNotNull { doc ->
                    doc.toObject<CompletedRun>()?.copy(id = doc.id)
                }
            }
    }
}
