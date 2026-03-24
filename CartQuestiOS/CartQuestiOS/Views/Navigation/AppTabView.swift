import SwiftUI

struct AppTabView: View {
    @Bindable var loginViewModel: LoginViewModel
    @State private var shopViewModel = ShopViewModel()
    @State private var selectedTab = 0
    @State private var shopNavigationId = UUID()
    @State private var communityRefreshId = UUID()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ShopHomeView(viewModel: shopViewModel, onTripCompleted: handleTripCompleted)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink {
                                CartView(viewModel: shopViewModel, onTripCompleted: handleTripCompleted)
                            } label: {
                                cartBadge
                            }
                        }
                    }
            }
            .id(shopNavigationId)
            .tabItem {
                Label("Shop", systemImage: "cart")
            }
            .tag(0)

            NavigationStack {
                CommunityFeedView()
            }
            .id(communityRefreshId)
            .tabItem {
                Label("Community", systemImage: "person.3")
            }
            .tag(1)

            ProfileView(loginViewModel: loginViewModel)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(2)
        }
        .onChange(of: shopViewModel.tripJustCompleted) { _, completed in
            if completed {
                shopViewModel.tripJustCompleted = false
                shopViewModel.clearCart()
                shopNavigationId = UUID()
                communityRefreshId = UUID()
                selectedTab = 1
            }
        }
    }

    private func handleTripCompleted() {
        shopViewModel.tripJustCompleted = true
    }

    @ViewBuilder
    private var cartBadge: some View {
        let count = shopViewModel.cart.items.reduce(0) { $0 + $1.quantity }
        ZStack(alignment: .topTrailing) {
            Image(systemName: count > 0 ? "cart.fill" : "cart")
                .font(.body)
                .frame(width: 24, height: 24)
                .padding(.top, 6)
                .padding(.trailing, 6)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
    }
}

#Preview {
    AppTabView(loginViewModel: LoginViewModel())
}
