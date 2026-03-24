import SwiftUI

struct SubstituteSearchView: View {
    @Bindable var viewModel: ShopViewModel
    let cartItemIndex: Int
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    @State private var query = ""
    @State private var results: [ShopViewModel.ProductResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false

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
                TextField("Search products...", text: $query)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                        isSearchFocused = false
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
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
            if isSearching {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            } else if results.isEmpty && hasSearched {
                ContentUnavailableView.search(text: query)
            } else if results.isEmpty {
                Spacer()
                Text("Search for a substitute product")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(results) { result in
                            SubstituteResultCard(result: result) {
                                viewModel.addSubstitute(to: cartItemIndex, product: result.product)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
            }
        }
        .navigationTitle("Add Substitute")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isSearchFocused = true }
    }

    private func performSearch() {
        isSearching = true
        Task {
            results = await viewModel.searchProducts(query: query)
            hasSearched = true
            isSearching = false
        }
    }
}

// MARK: - Substitute Result Card

private struct SubstituteResultCard: View {
    let result: ShopViewModel.ProductResult
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageUrl = result.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color(.tertiarySystemBackground)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(result.product.description)
                .font(.subheadline)
                .lineLimit(2)

            if let brand = result.product.brand {
                Text(brand)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let price = result.price {
                Text(String(format: "$%.2f", price))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }

            Button("Add as Substitute", action: onAdd)
                .buttonStyle(.borderedProminent)
                .font(.caption)
                .frame(maxWidth: .infinity)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
