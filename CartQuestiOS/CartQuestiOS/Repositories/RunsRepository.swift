import Foundation
import FirebaseFirestore

class RunsRepository {
    private lazy var db = Firestore.firestore()

    func saveCompletedRun(_ run: CompletedRun) async throws -> String {
        let docRef = db.collection("runs").document()
        var runToSave = run
        runToSave.id = docRef.documentID
        try docRef.setData(from: runToSave)
        return docRef.documentID
    }

    func getRun(id: String) async throws -> CompletedRun? {
        let doc = try await db.collection("runs").document(id).getDocument()
        guard doc.exists else { return nil }
        var run = try doc.data(as: CompletedRun.self)
        run.id = doc.documentID
        return run
    }

    func getRecentRuns(limit: Int = 20) async throws -> [CompletedRun] {
        let snapshot = try await db.collection("runs")
            .order(by: "completedAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            var run = try? doc.data(as: CompletedRun.self)
            run?.id = doc.documentID
            return run
        }
    }
}
