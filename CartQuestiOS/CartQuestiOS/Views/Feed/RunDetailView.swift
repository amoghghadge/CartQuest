import SwiftUI
import GoogleMaps
import CoreLocation

struct RunDetailView: View {
    @State private var viewModel: RunDetailViewModel
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false

    init(runId: String) {
        _viewModel = State(initialValue: RunDetailViewModel(runId: runId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading run...")
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if let run = viewModel.run {
                RunDetailContent(run: run)
            }
        }
        .navigationTitle("Run Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let run = viewModel.run,
                       let image = ShareCardRenderer.render(run: run) {
                        shareImage = image
                        showShareSheet = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareImage {
                ActivityViewController(activityItems: [shareImage])
            }
        }
        .task {
            await viewModel.loadRun()
        }
    }
}

// MARK: - Activity View Controller

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Content

private struct RunDetailContent: View {
    let run: CompletedRun

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Mini map
                RunMiniMapView(stores: run.stores)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()

                // Summary bar
                HStack(spacing: 16) {
                    SummaryPill(icon: "car.fill", text: "\(run.totalDriveTimeMinutes) min")
                    SummaryPill(icon: "bag", text: "\(totalItemCount) items")
                    SummaryPill(icon: "dollarsign.circle", text: String(format: "$%.2f", run.totalCost))
                }
                .padding(.horizontal)

                Divider()
                    .padding(.vertical, 12)

                // Items grouped by store
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(run.stores.enumerated()), id: \.element.storeId) { index, store in
                        StoreSection(stopNumber: index + 1, store: store)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)

                // Total cost
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "$%.2f", run.totalCost))
                        .font(.headline)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
            }
        }
    }

    private var totalItemCount: Int {
        run.stores.reduce(0) { $0 + $1.items.count }
    }
}

// MARK: - Summary Pill

private struct SummaryPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .fontWeight(.medium)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemBackground))
        .clipShape(Capsule())
    }
}

// MARK: - Store Section

private struct StoreSection: View {
    let stopNumber: Int
    let store: StoreStop

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(stopNumber). \(store.storeName)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(store.address)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ForEach(store.items) { item in
                HStack {
                    Text(item.name)
                        .font(.subheadline)
                    if !item.brand.isEmpty {
                        Text("(\(item.brand))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "$%.2f", item.price))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 8)
            }

            let storeTotal = store.items.reduce(0.0) { $0 + $1.price }
            HStack {
                Spacer()
                Text(String(format: "Subtotal: $%.2f", storeTotal))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Mini Map (UIViewRepresentable)

struct RunMiniMapView: UIViewRepresentable {
    let stores: [StoreStop]

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: 0, longitude: 0, zoom: 12)
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.isUserInteractionEnabled = false
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.clear()

        guard !stores.isEmpty else { return }

        // Add markers for each store
        for (index, store) in stores.enumerated() {
            let position = CLLocationCoordinate2D(latitude: store.lat, longitude: store.lng)
            let marker = GMSMarker(position: position)
            marker.title = store.storeName
            marker.snippet = store.address

            // Numbered label icon
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
            label.text = "\(index + 1)"
            label.textAlignment = .center
            label.font = UIFont.boldSystemFont(ofSize: 12)
            label.textColor = .white
            label.backgroundColor = .systemRed
            label.layer.cornerRadius = 12
            label.layer.masksToBounds = true
            UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, 0)
            label.layer.render(in: UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            marker.icon = image

            marker.map = mapView
        }

        // Draw polyline connecting stores in order
        if stores.count > 1 {
            let path = GMSMutablePath()
            for store in stores {
                path.add(CLLocationCoordinate2D(latitude: store.lat, longitude: store.lng))
            }
            let polyline = GMSPolyline(path: path)
            polyline.strokeWidth = 3
            polyline.strokeColor = .systemBlue
            polyline.map = mapView
        }

        // Fit bounds
        var bounds = GMSCoordinateBounds()
        for store in stores {
            let coord = CLLocationCoordinate2D(latitude: store.lat, longitude: store.lng)
            bounds = bounds.includingCoordinate(coord)
        }
        let update = GMSCameraUpdate.fit(bounds, withPadding: 40)
        mapView.animate(with: update)
    }
}

// MARK: - Polyline Decoder

/// Decodes a Google-encoded polyline string into an array of coordinates.
/// See: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
func decodePolylineForDetail(_ encoded: String) -> [CLLocationCoordinate2D] {
    var coordinates: [CLLocationCoordinate2D] = []
    let bytes = Array(encoded.utf8)
    var index = 0
    var lat: Int32 = 0
    var lng: Int32 = 0

    while index < bytes.count {
        var result: Int32 = 0
        var shift: Int32 = 0
        var byte: Int32
        repeat {
            byte = Int32(bytes[index]) - 63
            index += 1
            result |= (byte & 0x1F) << shift
            shift += 5
        } while byte >= 0x20
        let deltaLat: Int32 = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        lat += deltaLat

        result = 0
        shift = 0
        repeat {
            byte = Int32(bytes[index]) - 63
            index += 1
            result |= (byte & 0x1F) << shift
            shift += 5
        } while byte >= 0x20
        let deltaLng: Int32 = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        lng += deltaLng

        coordinates.append(CLLocationCoordinate2D(
            latitude: Double(lat) / 1e5,
            longitude: Double(lng) / 1e5
        ))
    }

    return coordinates
}
