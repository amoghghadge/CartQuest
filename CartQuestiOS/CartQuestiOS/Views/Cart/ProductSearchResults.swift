import SwiftUI

struct ProductSearchResults: View {
    let results: [KrogerProduct]
    let onSelect: (KrogerProduct) -> Void

    var body: some View {
        Section("Search Results") {
            ForEach(results) { product in
                Button {
                    onSelect(product)
                } label: {
                    HStack(spacing: 12) {
                        let imageUrl = product.images.first?.sizes.first?.url ?? ""
                        AsyncImage(url: URL(string: imageUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            case .failure:
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 48, height: 48)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.description)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(product.brand)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let price = product.items.first?.price {
                                Text(String(format: "$%.2f", price.regular))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                            }
                        }

                        Spacer()

                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }
}
