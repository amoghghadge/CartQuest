import Foundation
import Combine

@Observable
class CommunityFeedViewModel {
    var runs: [CompletedRun] = []
    var filteredRuns: [CompletedRun] = []
    var searchText: String = "" {
        didSet { scheduleFilter() }
    }
    var isLoading = false
    var errorMessage: String?

    private let repository = RunsRepository()
    private var filterWorkItem: DispatchWorkItem?

    // MARK: - Load

    func loadRuns() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await repository.getRecentRuns(limit: 50)
            runs = fetched
            applyFilter()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Debounced Filter

    private func scheduleFilter() {
        filterWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.applyFilter()
        }
        filterWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    private func applyFilter() {
        guard !searchText.isEmpty else {
            filteredRuns = runs
            return
        }
        let query = searchText.lowercased()
        filteredRuns = runs.filter { run in
            if run.displayName.lowercased().contains(query) { return true }
            for stop in run.stores {
                if stop.storeName.lowercased().contains(query) { return true }
                for item in stop.items {
                    if item.name.lowercased().contains(query) { return true }
                }
            }
            return false
        }
    }
}
