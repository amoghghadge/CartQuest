//
//  CartQuestiOSApp.swift
//  CartQuestiOS
//
//  Created by Amogh Ghadge on 3/22/26.
//

import SwiftUI
import FirebaseCore
import GoogleMaps

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        if let key = Bundle.main.infoDictionary?["GOOGLE_MAPS_API_KEY"] as? String {
            GMSServices.provideAPIKey(key)
        }
        return true
    }
}

@main
struct CartQuestiOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var loginViewModel = LoginViewModel()

    var body: some View {
        switch loginViewModel.authState {
        case .unauthenticated, .error:
            LoginView(viewModel: loginViewModel)
        case .loading:
            ProgressView()
        case .authenticated(_):
            AppTabView(loginViewModel: loginViewModel)
        }
    }
}
