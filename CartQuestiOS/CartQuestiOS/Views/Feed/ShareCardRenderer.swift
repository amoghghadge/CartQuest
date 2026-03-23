import SwiftUI

struct ShareCardView: View {
    let run: CompletedRun

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // App title "CartQuest"
            Text("CartQuest")
                .font(.title.bold())

            // Date
            Text(run.completedAt, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            // Route summary: "Store A → Store B → Store C"
            Text(run.stores.map { $0.storeName }.joined(separator: " → "))
                .font(.headline)

            // Item highlights (first 6 items)
            ForEach(Array(run.stores.flatMap { $0.items }.prefix(6)), id: \.productId) { item in
                HStack {
                    Text(item.name)
                        .font(.caption)
                    Spacer()
                    Text(String(format: "$%.2f", item.price))
                        .font(.caption.bold())
                }
            }

            Divider()

            // Totals
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Cost")
                        .font(.caption)
                    Text(String(format: "$%.2f", run.totalCost))
                        .font(.title3.bold())
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Drive Time")
                        .font(.caption)
                    Text("\(run.totalDriveTimeMinutes) min")
                        .font(.title3.bold())
                }
            }
        }
        .frame(width: 400)
        .padding(24)
        .background(.white)
    }
}

class ShareCardRenderer {
    @MainActor
    static func render(run: CompletedRun) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(run: run))
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
