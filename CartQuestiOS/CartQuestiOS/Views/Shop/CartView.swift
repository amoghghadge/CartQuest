import SwiftUI

struct CartView: View {
    @Bindable var viewModel: ShopViewModel
    var onTripCompleted: (() -> Void)?
    @State private var navigateToRoute = false
    @State private var substituteTargetIndex: Int?

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
                        VStack(alignment: .leading, spacing: 8) {
                            // Main item row
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: item.imageUrl)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color(.tertiarySystemBackground)
                                }
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                    Text(item.brand)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

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

                            // Substitutes list
                            if !item.substitutes.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Substitutes")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)

                                    ForEach(Array(item.substitutes.enumerated()), id: \.element.productId) { subIndex, sub in
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.turn.down.right")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)

                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(sub.name)
                                                    .font(.caption)
                                                    .lineLimit(1)
                                                if !sub.brand.isEmpty {
                                                    Text(sub.brand)
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }

                                            Spacer()

                                            Button {
                                                viewModel.removeSubstitute(from: index, substituteIndex: subIndex)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                                .padding(.leading, 4)
                            }

                            // Add Substitute button
                            Button {
                                substituteTargetIndex = index
                            } label: {
                                Label("Add Substitute", systemImage: "plus.circle")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }

            // Checkout button
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
                    RouteMapView(cartId: viewModel.cart.id, onTripCompleted: onTripCompleted)
                }
            }
        }
        .navigationTitle("Cart")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $substituteTargetIndex) { index in
            SubstituteSearchView(viewModel: viewModel, cartItemIndex: index)
        }
    }
}

#Preview {
    NavigationStack {
        CartView(viewModel: .preview)
    }
}
