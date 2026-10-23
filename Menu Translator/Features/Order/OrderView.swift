import SwiftData
import SwiftUI

struct OrderView: View {
    @Environment(Router.self) private var router
    @Environment(OrderSession.self) private var orderSession
    let order: Order

    @State private var isEditingRestaurant = false
    @State private var restaurantText = ""

    var body: some View {
        // A List (styled like the rest of the app) so dishes get the standard swipe-to-delete.
        List {
            header
                .plainListRow(top: 24, bottom: 40)
            restaurant
                .plainListRow(bottom: 40)
            ForEach(order.sortedDishes) { dish in
                DishRow(dish: dish, onOpen: { router.push(.dishDetails(dish)) })
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                orderSession.remove(dish)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(Colors.danger)
                    }
                    .plainListRow(bottom: 8)
            }
            // Only when opened from Home; an Order screen reached from Scan/Translation
            // gets more dishes by going back to the camera.
            if isOpenedFromHome {
                Button {
                    // New dishes go into this order (the session's).
                    router.popToOrPush(.scan)
                } label: {
                    Text("Add more")
                        .setFontStyle(Fonts.textMdBold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .plainListRow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // Rows size to their content; the default 44pt minimum adds gaps the design doesn't have.
        .environment(\.defaultMinListRowHeight, 0)
        .foregroundStyle(Colors.text)
        .safeAreaInset(edge: .bottom) {
            Group {
                if isEmpty {
                    saveButton("Delete").buttonStyle(DangerButton())
                } else {
                    saveButton("Save").buttonStyle(PrimaryButton())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Colors.white)
        }
        .background(Colors.white)
        .toolbar(.hidden, for: .navigationBar)
        // Like on Translation: keep the layout still while the alert's keyboard is up.
        .ignoresSafeArea(.keyboard)
        // Like the order's other changes, kept only when the order is saved.
        .alert("Restaurant", isPresented: $isEditingRestaurant) {
            TextField("Name", text: $restaurantText)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                order.restaurantName = restaurantText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .keyboardShortcut(.defaultAction)
        } message: {
            Text("Enter the restaurant name.")
        }
    }

    private var restaurant: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("Restaurant")
                    .setFontStyle(Fonts.textLgBold)
                Button {
                    restaurantText = order.restaurantName
                    isEditingRestaurant = true
                } label: {
                    Text("(edit)")
                        .setFontStyle(Fonts.textLgBold)
                        .foregroundStyle(Colors.primary)
                }
                .buttonStyle(.plain)
            }
            Text(order.restaurantName.isEmpty ? "No name." : order.restaurantName)
                .setFontStyleMultiline(Fonts.textMd)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func saveButton(_ title: LocalizedStringKey) -> some View {
        Button {
            // The only place orders are written: a new order becomes a saved one listed on
            // Home; a saved order's changes (dishes from "Add more", quantities, prices) are stored.
            // With every dish at 0 it deletes the order instead (a new one is just not saved).
            orderSession.save()
            router.popToRoot()
        } label: {
            Text(title).setFontStyle(Fonts.textMdBold)
        }
    }

    /// Every dish is down to 0 or deleted, so saving would leave nothing.
    private var isEmpty: Bool {
        order.dishes.allSatisfy { $0.quantity == 0 }
    }

    /// This screen sits directly on Home (rather than on Scan/Translation).
    private var isOpenedFromHome: Bool {
        router.path.count == 1
    }

    /// Going back to Home without Save discards the changes made to the order (dishes added,
    /// quantities, prices). Going back deeper, e.g. to Translation while scanning, keeps them.
    private func goBack() {
        if isOpenedFromHome {
            orderSession.end()
        }
        router.pop()
    }

    private var header: some View {
        BackHeader(onBack: goBack) {
            Text("Order \(order.total.formatted(.usd))")
        }
    }
}

private struct DishRow: View {
    @Bindable var dish: Dish
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dish.translatedName)
                        .setFontStyle(Fonts.textLgBold)
                    Text("\(price(dish.price)) x \(dish.quantity) = \(price(dish.subtotal))")
                        .setFontStyleMultiline(Fonts.textMd)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dishRow")

            HStack(spacing: 12) {
                Button {
                    // Stops at 0; dishes at 0 stay listed and are removed when the order is saved.
                    dish.quantity -= 1
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(OutlineIconButton())
                .disabled(dish.quantity == 0)
                .opacity(dish.quantity == 0 ? 0.4 : 1)
                Button {
                    dish.quantity += 1
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(OutlineIconButton())
            }
            // The quantity only changes here (− and +) while this screen is shown.
            .sensoryFeedback(.impact(weight: .light), trigger: dish.quantity)
        }
        .card()
    }

    private func price(_ value: Decimal) -> String {
        value.formatted(.usd)
    }
}

#Preview {
    let container = ModelContainer.preview
    NavigationStack {
        OrderView(order: container.previewOrder)
    }
    .environment(Router())
    .environment(OrderSession())
    .modelContainer(container)
}
