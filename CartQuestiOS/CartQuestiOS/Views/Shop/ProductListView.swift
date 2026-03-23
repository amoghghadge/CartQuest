import SwiftUI

struct ProductListView: View {
    @Bindable var viewModel: ShopViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        Group {
            if viewModel.isSearching {
                VStack {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                }
            } else if viewModel.searchResults.isEmpty && viewModel.hasSearched {
                ContentUnavailableView.search(text: viewModel.searchQuery)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.searchResults) { result in
                            ProductCard(
                                result: result,
                                cartQuantity: viewModel.cartQuantity(for: result.product.productId),
                                onAdd: { viewModel.addToCart(product: result.product) },
                                onIncrement: { viewModel.incrementQuantity(productId: result.product.productId) },
                                onDecrement: { viewModel.decrementQuantity(productId: result.product.productId) }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                let itemCount = viewModel.cart.items.reduce(0) { $0 + $1.quantity }
                NavigationLink {
                    CartView(viewModel: viewModel)
                } label: {
                    if itemCount > 0 {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "cart.fill")
                                .font(.body)

                            Text("\(itemCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(3)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
                        }
                    } else {
                        Image(systemName: "cart")
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchQuery, prompt: "Search products")
        .onSubmit(of: .search) {
            viewModel.search()
        }
        .overlay(alignment: .bottom) {
            let itemCount = viewModel.cart.items.reduce(0) { $0 + $1.quantity }
            if itemCount > 0 {
                NavigationLink {
                    CartView(viewModel: viewModel)
                } label: {
                    Text("Find Route (\(itemCount) item\(itemCount == 1 ? "" : "s"))")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProductListView(viewModel: ShopViewModel.preview)
    }
}
