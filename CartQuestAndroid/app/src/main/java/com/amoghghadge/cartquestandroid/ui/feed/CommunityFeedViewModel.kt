package com.amoghghadge.cartquestandroid.ui.feed

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.amoghghadge.cartquestandroid.data.model.CompletedRun
import com.amoghghadge.cartquestandroid.data.repository.RunsRepository
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

@OptIn(FlowPreview::class)
class CommunityFeedViewModel : ViewModel() {

    private val runsRepository = RunsRepository()

    private val _allRuns = MutableStateFlow<List<CompletedRun>>(emptyList())

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery

    val runs: StateFlow<List<CompletedRun>> = combine(
        _allRuns,
        _searchQuery.debounce(500)
    ) { allRuns, query ->
        if (query.isBlank()) {
            allRuns
        } else {
            val lowerQuery = query.lowercase()
            allRuns.filter { run ->
                run.displayName.lowercase().contains(lowerQuery) ||
                    run.stores.any { store ->
                        store.storeName.lowercase().contains(lowerQuery) ||
                            store.items.any { item ->
                                item.name.lowercase().contains(lowerQuery)
                            }
                    }
            }
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    init {
        viewModelScope.launch {
            runsRepository.getRecentRuns().collect { runs ->
                _allRuns.value = runs
            }
        }
    }

    fun onSearchQueryChanged(query: String) {
        _searchQuery.value = query
    }
}
