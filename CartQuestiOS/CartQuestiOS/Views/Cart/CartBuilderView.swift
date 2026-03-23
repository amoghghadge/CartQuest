import SwiftUI

struct CartBuilderView: View {
    @State private var viewModel = CartBuilderViewModel()

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.searchResults.isEmpty {
                    ProductSearchResults(results: viewModel.searchResults) { product in
                        viewModel.addToCart(product: product)
                    }
                }

                if viewModel.isSearching {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Searching...")
                            Spacer()
                        }
                    }
                }

                Section {
                    if viewModel.cart.items.isEmpty {
                        ContentUnavailableView(
                            "Your Cart is Empty",
                            systemImage: "cart",
                            description: Text("Search for products to add to your cart.")
                        )
                    } else {
                        ForEach(Array(viewModel.cart.items.enumerated()), id: \.element.productId) { index, item in
                            CartItemRow(
                                index: index,
                                item: item,
                                onUpdateQuantity: { qty in
                                    viewModel.updateQuantity(at: index, quantity: qty)
                                },
                                onDelete: {
                                    viewModel.removeFromCart(at: index)
                                },
                                onAddSubstitute: {
                                    viewModel.addingSubstituteForIndex = index
                                },
                                onRemoveSubstitute: { subIndex in
                                    viewModel.removeSubstitute(cartItemIndex: index, subIndex: subIndex)
                                }
                            )
                        }
                    }
                } header: {
                    HStack {
                        Text("Your Cart")
                        Spacer()
                        if viewModel.isSaving {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                }

                if !viewModel.cart.items.isEmpty {
                    Section {
                        NavigationLink {
                            Text("Route Map")
                        } label: {
                            Label("Find Route", systemImage: "map")
                        }
                    }
                }
            }
            .navigationTitle("Shop")
            .searchable(text: $viewModel.searchQuery, prompt: "Search products")
            .onSubmit(of: .search) {
                viewModel.search()
            }
            .overlay {
                if viewModel.addingSubstituteForIndex != nil && viewModel.searchResults.isEmpty && viewModel.searchQuery.isEmpty {
                    VStack {
                        Text("Search for a substitute product")
                            .foregroundStyle(.secondary)
                        Button("Cancel") {
                            viewModel.addingSubstituteForIndex = nil
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }
}
