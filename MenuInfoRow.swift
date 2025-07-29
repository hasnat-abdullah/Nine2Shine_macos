import SwiftUI

struct MenuInfoRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .frame(width: 18)
            Text(title)
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .foregroundStyle(.secondary)
        .contentShape(Rectangle())
    }
}
