import SwiftUI

struct ShareCardView: View {
    let run: CompletedRun
    let mapImage: UIImage?

    private let brandColor = Color(red: 0.259, green: 0.522, blue: 0.957) // #4285F4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: App icon + name
            HStack(spacing: 12) {
                Image("AppIconImage")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("CartQuest")
                    .font(.title2.bold())
                    .foregroundStyle(brandColor)
            }
            .padding(.bottom, 16)

            // Date
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(run.completedAt, format: .dateTime.weekday(.wide).month(.abbreviated).day().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 20)

            // Map image
            if let mapImage {
                Image(uiImage: mapImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 352, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 20)
            }

            // Stores visited
            VStack(alignment: .leading, spacing: 8) {
                Text("STORES VISITED")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .kerning(1)

                ForEach(Array(run.stores.enumerated()), id: \.element.storeId) { index, store in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(brandColor)
                            .clipShape(Circle())

                        Text(store.storeName)
                            .font(.subheadline.weight(.medium))

                        Spacer()

                        Text("\(store.items.count) item\(store.items.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.bottom, 20)

            // Divider
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
                .padding(.bottom, 16)

            // Stats row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL COST")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .kerning(0.5)
                    Text(String(format: "$%.2f", run.totalCost))
                        .font(.title3.bold())
                        .foregroundStyle(brandColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("ITEMS")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .kerning(0.5)
                    Text("\(run.stores.flatMap { $0.items }.count)")
                        .font(.title3.bold())
                }
                .padding(.trailing, 14)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("DRIVE TIME")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .kerning(0.5)
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
    static func render(run: CompletedRun, mapImage: UIImage? = nil) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(run: run, mapImage: mapImage))
        renderer.scale = 3.0
        return renderer.uiImage
    }

    static func loadStaticMapImage(stores: [StoreStop]) async -> UIImage? {
        guard !stores.isEmpty,
              let apiKey = Bundle.main.infoDictionary?["GOOGLE_MAPS_API_KEY"] as? String,
              !apiKey.isEmpty else { return nil }

        var urlString = "https://maps.googleapis.com/maps/api/staticmap?size=800x400&maptype=roadmap&scale=2"

        // Add markers for each store
        for (index, store) in stores.enumerated() {
            urlString += "&markers=color:0x4285F4|label:\(index + 1)|\(store.lat),\(store.lng)"
        }

        // Connect stores with a path
        if stores.count > 1 {
            let pathCoords = stores.map { "\($0.lat),\($0.lng)" }.joined(separator: "|")
            urlString += "&path=color:0x4285F4ff|weight:3|\(pathCoords)"
        }

        urlString += "&key=\(apiKey)"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
