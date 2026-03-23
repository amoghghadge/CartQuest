import SwiftUI

struct StoreStopCard: View {
    let stopNumber: Int
    let stop: StoreStop

    private var subtotal: Double {
        stop.items.reduce(0.0) { $0 + $1.price }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Numbered circle
            ZStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 32, height: 32)
                Text("\(stopNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(stop.storeName)
                    .font(.headline)

                Text(stop.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                ForEach(stop.items) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.subheadline)
                            Text(item.brand)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(String(format: "$%.2f", item.price))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }

                Divider()

                HStack {
                    Text("Subtotal")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(String(format: "$%.2f", subtotal))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}
