package com.amoghghadge.cartquestandroid.ui.feed

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.amoghghadge.cartquestandroid.data.model.CompletedRun
import com.amoghghadge.cartquestandroid.data.repository.RunsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class RunDetailState {
    object Loading : RunDetailState()
    data class Loaded(val run: CompletedRun) : RunDetailState()
    data class Error(val message: String) : RunDetailState()
}

class RunDetailViewModel(
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val runId: String = savedStateHandle["runId"] ?: ""
    private val runsRepository = RunsRepository()

    private val _state = MutableStateFlow<RunDetailState>(RunDetailState.Loading)
    val state: StateFlow<RunDetailState> = _state

    init {
        loadRun()
    }

    private fun loadRun() {
        viewModelScope.launch {
            _state.value = RunDetailState.Loading
            try {
                val run = runsRepository.getRunById(runId)
                if (run != null) {
                    _state.value = RunDetailState.Loaded(run)
                } else {
                    _state.value = RunDetailState.Error("Run not found")
                }
            } catch (e: Exception) {
                _state.value = RunDetailState.Error(e.message ?: "Failed to load run")
            }
        }
    }

    fun onShareClicked() {
        // Placeholder -- will be connected in Task 23
    }
}
