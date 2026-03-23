import SwiftUI

struct AppTabView: View {
    @Bindable var loginViewModel: LoginViewModel
    @State private var shopViewModel = ShopViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                ShopHomeView(viewModel: shopViewModel)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink {
                                CartView(viewModel: shopViewModel)
                            } label: {
                                cartBadge
                            }
                        }
                    }
            }
            .tabItem {
                Label("Shop", systemImage: "cart")
            }

            NavigationStack {
                CommunityFeedView()
            }
            .tabItem {
                Label("Community", systemImage: "person.3")
            }

            ProfileView(loginViewModel: loginViewModel)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
    }

    @ViewBuilder
    private var cartBadge: some View {
        let count = shopViewModel.cart.items.count
        Image(systemName: count > 0 ? "cart.fill" : "cart")
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
    }
}

#Preview {
    AppTabView(loginViewModel: LoginViewModel())
}
