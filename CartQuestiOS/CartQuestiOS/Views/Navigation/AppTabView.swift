import SwiftUI

struct AppTabView: View {
    var body: some View {
        TabView {
            CartBuilderView()
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
