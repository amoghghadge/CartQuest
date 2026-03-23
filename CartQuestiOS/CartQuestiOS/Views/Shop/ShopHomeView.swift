import SwiftUI

struct ShopHomeView: View {
    @Bindable var viewModel: ShopViewModel
    @State private var navigateToResults = false

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text("Find items near you")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search products...", text: $viewModel.searchQuery)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .onSubmit {
                            viewModel.search()
                            navigateToResults = true
                        }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 1)
                )
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .navigationDestination(isPresented: $navigateToResults) {
            ProductListView(viewModel: viewModel)
        }
    }
}

#Preview {
    NavigationStack {
        ShopHomeView(viewModel: ShopViewModel.preview)
    }
}
