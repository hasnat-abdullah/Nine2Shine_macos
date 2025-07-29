import SwiftUI

struct MenuItemRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .frame(width: 18)
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(title)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .focusable(false)
    }
}
