import SwiftUI

struct CommunityFeedView: View {
    @State private var viewModel = CommunityFeedViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading runs...")
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
                .listRowSeparator(.hidden)
            } else if viewModel.filteredRuns.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.filteredRuns) { run in
                    NavigationLink(value: run.id) {
                        FeedCard(run: run)
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $viewModel.searchText, prompt: "Search by user, store, or product")
        .navigationTitle("Community")
        .navigationDestination(for: String.self) { runId in
            RunDetailView(runId: runId)
        }
        .refreshable {
            await viewModel.loadRuns()
        }
        .task {
            if viewModel.runs.isEmpty {
                await viewModel.loadRuns()
            }
        }
    }
}

// MARK: - Feed Card

private struct FeedCard: View {
    let run: CompletedRun

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User info row
            HStack(spacing: 8) {
                if !run.photoUrl.isEmpty, let url = URL(string: run.photoUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(run.displayName.isEmpty ? "Anonymous" : run.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(run.completedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Store tags
            if !run.stores.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(run.stores) { store in
                            Text(store.storeName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundStyle(.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Stats row
            HStack(spacing: 16) {
                Label {
                    Text("\(totalItemCount) item\(totalItemCount == 1 ? "" : "s")")
                } icon: {
                    Image(systemName: "bag")
                }

                Label {
                    Text(String(format: "$%.2f", run.totalCost))
                } icon: {
                    Image(systemName: "dollarsign.circle")
                }

                Label {
                    Text("\(run.totalDriveTimeMinutes) min")
                } icon: {
                    Image(systemName: "car.fill")
                }

                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var totalItemCount: Int {
        run.stores.reduce(0) { $0 + $1.items.count }
    }
}
