import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(Router.self) private var router
    @AppStorage(StorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = true

    @Environment(\.modelContext) private var modelContext
    @Environment(OrderSession.self) private var orderSession
    @Query(sort: \Order.date, order: .reverse) private var orders: [Order]

    @State private var isConfirmingClearAll = false

    /// Saved orders only; the order being built appears once it's saved on the Order screen.
    private var recentOrders: [Order] { orders.filter { !$0.isDraft && !$0.dishes.isEmpty } }

    var body: some View {
        // A List (styled like the rest of the app) so orders get the standard swipe-to-delete.
        List {
            header
                .plainListRow(top: 24, bottom: 40)
            recentOrdersHeader
                .plainListRow(bottom: 8)
            if recentOrders.isEmpty {
                Text("There are no orders yet.")
                    .setFontStyleMultiline(Fonts.textMd)
                    .plainListRow()
            } else {
                ForEach(recentOrders) { order in
                    Button {
                        // Edited as a copy: Back drops the changes, Save writes them.
                        if let editable = orderSession.edit(order, in: modelContext.container) {
                            router.push(.order(editable))
                        }
                    } label: {
                        OrderRow(order: order)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recentOrder")
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                modelContext.delete(order)
                                try? modelContext.save()
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(Colors.danger)
                    }
                    .plainListRow(bottom: 8)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // Rows size to their content; the default 44pt minimum adds gaps the design doesn't have.
        .environment(\.defaultMinListRowHeight, 0)
        .foregroundStyle(Colors.text)
        .safeAreaInset(edge: .bottom) {
            Button {
                // Each scan from Home starts a new order.
                orderSession.startNewOrder(in: modelContext.container)
                router.push(.scan)
            } label: {
                Text("Scan menu").setFontStyle(Fonts.textMdBold)
            }
            .buttonStyle(PrimaryButton())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Colors.white)
        }
        .background(Colors.white)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Delete all orders?", isPresented: $isConfirmingClearAll) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                withAnimation {
                    recentOrders.forEach(modelContext.delete)
                    try? modelContext.save()
                }
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Menu Translator")
                .setFontStyle(Fonts.textXlBold)
            Text("Scan menu and manage your orders.")
                .setFontStyleMultiline(Fonts.textMd)
        }
        #if DEBUG
        // The navigation bar is hidden, so the debug reset lives in a long-press menu.
        .contextMenu {
            Button("Reset onboarding", systemImage: "arrow.counterclockwise") {
                hasCompletedOnboarding = false
            }
        }
        #endif
    }

    private var recentOrdersHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Recent orders")
                .setFontStyle(Fonts.textLgBold)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !recentOrders.isEmpty {
                Button {
                    isConfirmingClearAll = true
                } label: {
                    Text("Clear all").setFontStyle(Fonts.textMdBold)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Colors.primary)
            }
        }
    }
}

private struct OrderRow: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .setFontStyle(Fonts.textLgBold)
            Text(date)
                .setFontStyleMultiline(Fonts.textMd)
        }
        .foregroundStyle(Colors.text)
        .card()
    }

    /// US style: "Oct 13 at 1:10 PM", with the year ("Oct 13, 2025 at 1:10 PM") only for other years.
    /// Formatted to a string: `Text(_:format:)` would apply the phone's locale instead.
    private var date: String {
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day().hour().minute()
        if !Calendar.current.isDate(order.date, equalTo: .now, toGranularity: .year) {
            style = style.year()
        }
        return order.date.formatted(style.locale(Locale(identifier: "en_US")))
    }

    /// "McDonalds, $10.99", or just the total without a restaurant name.
    private var title: String {
        let total = order.total.formatted(.usd)
        return order.restaurantName.isEmpty ? total : "\(order.restaurantName), \(total)"
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(Router())
    .environment(OrderSession())
    .modelContainer(.preview)
}
