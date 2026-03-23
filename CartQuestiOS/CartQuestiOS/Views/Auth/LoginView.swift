import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: LoginViewModel

    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                // App title + icon
                Text("CartQuest")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 60)

                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .padding(.top, 8)

                Spacer()

                VStack(spacing: 16) {
                    // Email field
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)

                    // Password field
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(viewModel.isSignUp ? .newPassword : .password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)

                    // Display name field (sign-up only)
                    if viewModel.isSignUp {
                        TextField("Display Name", text: $viewModel.displayName)
                            .textContentType(.name)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }

                    // Primary action button
                    Button {
                        if viewModel.isSignUp {
                            viewModel.signUpWithEmail()
                        } else {
                            viewModel.signInWithEmail()
                        }
                    } label: {
                        Text(viewModel.isSignUp ? "Create Account" : "Sign In")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .fontWeight(.semibold)
                    }

                    // Toggle sign-in / sign-up mode
                    Button {
                        withAnimation {
                            viewModel.isSignUp.toggle()
                        }
                    } label: {
                        Text(viewModel.isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.footnote)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 24)

                // Divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.separator))
                    Text("or")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.separator))
                }
                .padding(.horizontal, 24)

                // Google Sign-In button (placeholder until SPM package is added)
                Button {
                    viewModel.signInWithGoogle()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.title3)
                        Text("Sign in with Google")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 24)

                Spacer()
            }

            // Loading overlay
            if case .loading = viewModel.authState {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
        .onChange(of: viewModel.authState) { _, newState in
            if case .error(let message) = newState {
                errorMessage = message
                showErrorAlert = true
            }
        }
        .alert("Sign In Error", isPresented: $showErrorAlert) {
            Button("OK") {
                viewModel.authState = .unauthenticated
            }
        } message: {
            Text(errorMessage)
        }
    }
}

#Preview {
    LoginView(viewModel: LoginViewModel())
}
