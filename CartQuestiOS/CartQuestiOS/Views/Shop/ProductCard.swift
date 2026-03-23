import SwiftUI

struct ProductCard: View {
    let result: ShopViewModel.ProductResult
    let cartQuantity: Int
    let onAdd: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: result.imageUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    Color(.systemGray5)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                case .empty:
                    Color(.systemGray5)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    Color(.systemGray5)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(result.product.description)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)

            if !result.product.brand.isEmpty {
                Text(result.product.brand)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let price = result.price {
                Text(String(format: "$%.2f", price))
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            Spacer(minLength: 0)

            if !result.isAvailable {
                Text("Unavailable near you")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray3))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if cartQuantity > 0 {
                HStack {
                    Button(action: onDecrement) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.accent)
                    }
                    .buttonStyle(.borderless)

                    Spacer()

                    Text("\(cartQuantity)")
                        .font(.headline)
                        .monospacedDigit()

                    Spacer()

                    Button(action: onIncrement) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.accent)
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                Button(action: onAdd) {
                    Text("Add to Cart")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    ProductCard(
        result: ShopViewModel.ProductResult(
            product: KrogerProduct(productId: "001", description: "Organic Strawberries, 1 Lb", brand: "Simple Truth", images: [], items: []),
            isAvailable: true
        ),
        cartQuantity: 0,
        onAdd: {},
        onIncrement: {},
        onDecrement: {}
    )
    .padding()
}
