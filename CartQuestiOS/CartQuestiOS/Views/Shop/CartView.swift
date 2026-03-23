import SwiftUI

struct CartView: View {
    @Bindable var viewModel: ShopViewModel
    @State private var navigateToRoute = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.cart.items.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "Your Cart is Empty",
                    systemImage: "cart",
                    description: Text("Search for products to add to your cart.")
                )
                Spacer()
            } else {
                List {
                    ForEach(Array(viewModel.cart.items.enumerated()), id: \.element.productId) { index, item in
                        HStack(spacing: 12) {
                            // 56x56 async image with rounded corners
                            AsyncImage(url: URL(string: item.imageUrl)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color(.tertiarySystemBackground)
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            // Name + brand
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                Text(item.brand)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // Quantity controls
                            HStack(spacing: 12) {
                                Button {
                                    viewModel.updateQuantity(at: index, quantity: item.quantity - 1)
                                } label: {
                                    Image(systemName: item.quantity == 1 ? "trash" : "minus.circle")
                                        .foregroundStyle(item.quantity == 1 ? .red : .primary)
                                }
                                .buttonStyle(.plain)

                                Text("\(item.quantity)")
                                    .font(.headline)
                                    .frame(minWidth: 20)

                                Button {
                                    viewModel.updateQuantity(at: index, quantity: item.quantity + 1)
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }

            // Checkout button — force-saves cart before navigating
            if !viewModel.cart.items.isEmpty {
                Button {
                    Task {
                        await viewModel.saveCartNow()
                        navigateToRoute = true
                    }
                } label: {
                    Text("Find Route")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding()
                .navigationDestination(isPresented: $navigateToRoute) {
                    RouteMapView(cartId: viewModel.cart.id)
                }
            }
        }
        .navigationTitle("Cart")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CartView(viewModel: .preview)
    }
}
