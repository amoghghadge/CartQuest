import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @Bindable var loginViewModel: LoginViewModel

    private var user: FirebaseAuth.User? {
        Auth.auth().currentUser
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section {
                        HStack(spacing: 16) {
                            if let photoURL = user?.photoURL {
                                AsyncImage(url: photoURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user?.displayName ?? "User")
                                    .font(.headline)
                                Text(user?.email ?? "")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section {
                        LabeledContent("User ID") {
                            Text(user?.uid ?? "")
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        LabeledContent("Email Verified", value: user?.isEmailVerified == true ? "Yes" : "No")
                    }
                }

                Button(role: .destructive) {
                    loginViewModel.signOut()
                } label: {
                    Text("Log Out")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ProfileView(loginViewModel: LoginViewModel())
}
