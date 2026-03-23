import SwiftUI

struct AppTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                Text("Cart Builder") // placeholder
                    .navigationTitle("Shop")
            }
            .tabItem {
                Label("Shop", systemImage: "cart")
            }

            NavigationStack {
                Text("Community Feed") // placeholder
                    .navigationTitle("Community")
            }
            .tabItem {
                Label("Community", systemImage: "person.3")
            }
        }
    }
}
