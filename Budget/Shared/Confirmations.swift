import SwiftUI

extension View {
    /// Asks before deleting: nothing in the app can be undone.
    func confirmDelete(_ title: String, message: String? = nil, isPresented: Binding<Bool>,
                       action: @escaping () -> Void) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: action)
        } message: {
            if let message { Text(message) }
        }
    }

    /// Asks before deleting `item`, for example one picked from a context menu.
    /// Set the binding to show the question; it's reset when the question closes.
    func confirmDelete<Item>(_ item: Binding<Item?>, title: @escaping (Item) -> String,
                             message: ((Item) -> String)? = nil,
                             action: @escaping (Item) -> Void) -> some View {
        let isPresented = Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )
        return confirmationDialog(item.wrappedValue.map(title) ?? "", isPresented: isPresented,
                                  titleVisibility: .visible, presenting: item.wrappedValue) { value in
            Button("Delete", role: .destructive) { action(value) }
        } message: { value in
            if let message { Text(message(value)) }
        }
    }
}
