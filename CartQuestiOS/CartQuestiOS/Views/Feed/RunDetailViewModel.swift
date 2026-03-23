import Foundation

@Observable
class RunDetailViewModel {
    var run: CompletedRun?
    var isLoading = false
    var errorMessage: String?

    private let runId: String
    private let repository = RunsRepository()

    init(runId: String) {
        self.runId = runId
    }

    func loadRun() async {
        isLoading = true
        errorMessage = nil
        do {
            run = try await repository.getRun(id: runId)
            if run == nil {
                errorMessage = "Run not found."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
