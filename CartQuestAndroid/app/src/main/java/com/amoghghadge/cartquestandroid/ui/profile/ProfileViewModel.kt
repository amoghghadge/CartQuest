package com.amoghghadge.cartquestandroid.ui.profile

import androidx.lifecycle.ViewModel
import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class ProfileUiState(
    val displayName: String = "",
    val email: String = "",
    val photoUrl: String = "",
    val uid: String = "",
    val isEmailVerified: Boolean = false
)

class ProfileViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init {
        val user = FirebaseAuth.getInstance().currentUser
        if (user != null) {
            _uiState.value = ProfileUiState(
                displayName = user.displayName.orEmpty(),
                email = user.email.orEmpty(),
                photoUrl = user.photoUrl?.toString().orEmpty(),
                uid = user.uid,
                isEmailVerified = user.isEmailVerified
            )
        }
    }

    fun signOut() {
        FirebaseAuth.getInstance().signOut()
    }
}
