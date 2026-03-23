import SwiftUI
import GoogleMaps
import CoreLocation

struct RouteMapView: View {
    @State private var viewModel: RouteMapViewModel
    @Environment(\.dismiss) private var dismiss

    init(cartId: String) {
        _viewModel = State(initialValue: RouteMapViewModel(cartId: cartId))
    }

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.routeState {
            case .loading:
                Spacer()
                ProgressView("Computing best route...")
                    .frame(maxWidth: .infinity)
                Spacer()

            case .error(let message):
                Spacer()
                ContentUnavailableView(
                    "Route Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
                Spacer()

            case .computed(let route, let userLocation):
                // Map
                GoogleMapView(
                    userLocation: userLocation,
                    stops: route.stops,
                    encodedPolyline: route.encodedPolyline
                )
                .frame(maxWidth: .infinity)
                .frame(height: 300)

                // Drive time summary
                HStack {
                    Image(systemName: "car.fill")
                    Text("Estimated drive: \(route.totalDriveTimeSeconds / 60) min")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(route.stops.count) stop\(route.stops.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))

                // Store stop cards
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(route.stops.enumerated()), id: \.element.storeId) { index, stop in
                            StoreStopCard(stopNumber: index + 1, stop: stop)
                        }
                    }
                    .padding()
                }

                // Bottom buttons
                HStack(spacing: 12) {
                    Button {
                        viewModel.startNavigation()
                    } label: {
                        Label("Start Navigation", systemImage: "location.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task { await viewModel.completeTrip() }
                    } label: {
                        Label("Complete Trip", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding()
            }
        }
        .navigationTitle("Route Map")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.tripCompleted) { _, completed in
            if completed {
                dismiss()
            }
        }
    }
}

// MARK: - Google Maps UIViewRepresentable

struct GoogleMapView: UIViewRepresentable {
    let userLocation: CLLocationCoordinate2D
    let stops: [StoreStop]
    let encodedPolyline: String

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(
            withLatitude: userLocation.latitude,
            longitude: userLocation.longitude,
            zoom: 12
        )
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.isMyLocationEnabled = true
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.clear()

        // User location marker
        let userMarker = GMSMarker(position: userLocation)
        userMarker.title = "You"
        userMarker.icon = GMSMarker.markerImage(with: .blue)
        userMarker.map = mapView

        // Store markers with numbers
        for (index, stop) in stops.enumerated() {
            let position = CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lng)
            let marker = GMSMarker(position: position)
            marker.title = stop.storeName
            marker.snippet = stop.address
            marker.icon = GMSMarker.markerImage(with: .red)
            marker.map = mapView

            // Add numbered label
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
            label.text = "\(index + 1)"
            label.textAlignment = .center
            label.font = UIFont.boldSystemFont(ofSize: 12)
            label.textColor = .white
            label.backgroundColor = .red
            label.layer.cornerRadius = 12
            label.layer.masksToBounds = true
            UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, 0)
            label.layer.render(in: UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            marker.icon = image
        }

        // Decode and draw polyline
        let coordinates = decodePolyline(encodedPolyline)
        if !coordinates.isEmpty {
            let path = GMSMutablePath()
            for coord in coordinates {
                path.add(coord)
            }
            let polyline = GMSPolyline(path: path)
            polyline.strokeWidth = 4
            polyline.strokeColor = .systemBlue
            polyline.map = mapView
        }

        // Fit bounds to show all markers
        var bounds = GMSCoordinateBounds(coordinate: userLocation, coordinate: userLocation)
        for stop in stops {
            let coord = CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lng)
            bounds = bounds.includingCoordinate(coord)
        }
        let update = GMSCameraUpdate.fit(bounds, withPadding: 50)
        mapView.animate(with: update)
    }
}

// MARK: - Polyline Decoder

/// Decodes a Google-encoded polyline string into an array of coordinates.
/// See: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
    var coordinates: [CLLocationCoordinate2D] = []
    let bytes = Array(encoded.utf8)
    var index = 0
    var lat: Int32 = 0
    var lng: Int32 = 0

    while index < bytes.count {
        // Decode latitude
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

        // Decode longitude
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

        let coordinate = CLLocationCoordinate2D(
            latitude: Double(lat) / 1e5,
            longitude: Double(lng) / 1e5
        )
        coordinates.append(coordinate)
    }

    return coordinates
}
