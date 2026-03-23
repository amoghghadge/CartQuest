//
//  CartQuestiOSApp.swift
//  CartQuestiOS
//
//  Created by Amogh Ghadge on 3/22/26.
//

import SwiftUI
import FirebaseCore
// import GoogleMaps  // will be needed when Google Maps SPM package is added

@main
struct CartQuestiOSApp: App {
    @State private var loginViewModel = LoginViewModel()

    init() {
        FirebaseApp.configure()
        // GMSServices.provideAPIKey("your-api-key")  // TODO: configure when Google Maps SDK is added
    }

    var body: some Scene {
        WindowGroup {
            switch loginViewModel.authState {
            case .unauthenticated, .error:
                LoginView(viewModel: loginViewModel)
            case .loading:
                ProgressView()
            case .authenticated:
                Text("Welcome!") // Placeholder for main app
            }
        }
    }
}
