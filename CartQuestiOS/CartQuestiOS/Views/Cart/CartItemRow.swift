import SwiftUI

struct CartItemRow: View {
    let index: Int
    let item: CartItem
    let onUpdateQuantity: (Int) -> Void
    let onDelete: () -> Void
    let onAddSubstitute: () -> Void
    let onRemoveSubstitute: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: item.imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 56, height: 56)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(2)
                    Text(item.brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }

            Stepper("Qty: \(item.quantity)", value: Binding(
                get: { item.quantity },
                set: { onUpdateQuantity($0) }
            ), in: 1...99)
            .font(.subheadline)

            // Substitutes
            if !item.substitutes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Substitutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(Array(item.substitutes.enumerated()), id: \.element.productId) { subIndex, sub in
                        HStack {
                            Text("\(subIndex + 1). \(sub.name)")
                                .font(.caption)
                            Spacer()
                            Button {
                                onRemoveSubstitute(subIndex)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .padding(.leading, 68)
            }

            Button {
                onAddSubstitute()
            } label: {
                Label("Add Substitute", systemImage: "plus.circle")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .padding(.leading, 68)
        }
        .padding(.vertical, 4)
    }
}
