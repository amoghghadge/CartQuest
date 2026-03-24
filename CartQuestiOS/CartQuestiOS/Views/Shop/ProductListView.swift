import SwiftUI

struct ProductListView: View {
    @Bindable var viewModel: ShopViewModel
    var onTripCompleted: (() -> Void)?
    @FocusState private var isSearchFocused: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Inline search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search products", text: $viewModel.searchQuery)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        viewModel.search()
                        isSearchFocused = false
                    }
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Content
            if viewModel.isSearching {
                Spacer()
                ProgressView("Searching...")
                Spacer()
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
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                let itemCount = viewModel.cart.items.reduce(0) { $0 + $1.quantity }
                NavigationLink {
                    CartView(viewModel: viewModel, onTripCompleted: onTripCompleted)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: itemCount > 0 ? "cart.fill" : "cart")
                            .font(.body)
                            .frame(width: 24, height: 24)
                            .padding(.top, 6)
                            .padding(.trailing, 6)

                        if itemCount > 0 {
                            Text("\(itemCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Color(red: 0.9, green: 0.1, blue: 0.1))
                                .clipShape(Circle())
                        }
                    }
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
