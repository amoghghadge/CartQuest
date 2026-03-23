import SwiftUI

struct AppTabView: View {
    var body: some View {
        TabView {
            CartBuilderView()
            .tabItem {
                Label("Shop", systemImage: "cart")
            }

            NavigationStack {
                CommunityFeedView()
            }
            .tabItem {
                Label("Community", systemImage: "person.3")
            }
        }
    }
}
