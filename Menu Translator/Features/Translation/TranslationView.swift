import SwiftData
import SwiftUI

struct TranslationView: View {
    @Environment(Router.self) private var router
    let photo: UIImage?

    @Environment(\.modelContext) private var modelContext
    @Environment(OrderSession.self) private var orderSession

    @State private var selection: CGRect?
    @AppStorage(StorageKeys.menuLanguage) private var languageCode = MenuLanguage.spanish.code
    @State private var isLanguagePickerPresented = false
    @AppStorage(StorageKeys.menuCurrency) private var storedCurrencyCode = MenuLanguage.defaultCurrency
    @State private var isCurrencyPickerPresented = false
    @Environment(ExchangeRates.self) private var rates
    @Environment(LanguageDownloads.self) private var downloads
    @State private var photoRotation = 0.0
    @State private var photoTransform = PhotoTransform()
    /// Screen frames of the full-screen photo and of the area the selection frame moves in.
    @State private var photoFrame: CGRect = .zero
    @State private var selectionArea: CGRect = .zero
    /// The dish read from inside the selection frame.
    @State private var menuItem: MenuItem?
    @State private var isReading = false
    @State private var isEditingPrice = false
    /// Counts "Add to order" taps, to play haptic feedback for each.
    @State private var addedDishes = 0
    /// Dish photos flying from the selection frame to the order button.
    @State private var flyingDishes: [FlyingDish] = []
    /// Counts dishes that reached the order button, to bounce it.
    @State private var landedDishes = 0
    @State private var orderButtonFrame: CGRect = .zero
    /// The total the order button shows while dishes are flying to it; it catches up as each lands.
    @State private var shownTotal: Decimal?

    var body: some View {
        VStack(spacing: 0) {
            navbar
            GeometryReader { proxy in
                SelectionFrame(
                    rect: Binding(
                        get: { selection ?? defaultSelection(in: proxy.size) },
                        set: { selection = $0 }
                    ),
                    bounds: proxy.size,
                    tooltip: tooltip,
                    showsAddToOrder: hasPrice,
                    canAddToOrder: canAddToOrder,
                    showsEditPrice: hasText,
                    canEditPrice: !isReading,
                    onAddToOrder: addToOrder,
                    onEditPrice: startEditingPrice
                )
            }
            .clipped()
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { selectionArea = $0 }
            RotationDial(degrees: $photoRotation)
            footer
        }
        .background {
            if let photo {
                ZoomablePhoto(
                    image: photo,
                    rotation: .degrees(photoRotation),
                    transform: $photoTransform,
                    frame: $photoFrame
                )
            }
        }
        .background(Colors.black)
        // Keep the layout still when a keyboard appears (Edit price alert): resizing the photo area
        // would move the frame and its buttons and re-read the selection.
        .ignoresSafeArea(.keyboard)
        .toolbar(.hidden, for: .navigationBar)
        .overlay {
            // Screen coordinates: the flights start and end at global frames.
            GeometryReader { proxy in
                let origin = proxy.frame(in: .global).origin
                ForEach(flyingDishes) { dish in
                    FlyingDishView(
                        dish: dish,
                        from: dish.from.offsetBy(dx: -origin.x, dy: -origin.y),
                        to: orderButtonFrame.offsetBy(dx: -origin.x, dy: -origin.y)
                    ) {
                        flyingDishes.removeAll { $0.id == dish.id }
                        shownTotal = flyingDishes.isEmpty ? nil : dish.orderTotal
                        landedDishes += 1
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .overlay {
            ZStack(alignment: .bottom) {
                if isLanguagePickerPresented || isCurrencyPickerPresented {
                    Colors.text.opacity(0.6)
                       .onTapGesture {
                           isLanguagePickerPresented = false
                           isCurrencyPickerPresented = false
                       }
                       .accessibilityHidden(true)
                       .transition(.opacity)
                       .zIndex(0)
                }
                if isLanguagePickerPresented {
                    LanguagePicker(
                        selection: Binding(get: { language }, set: { languageCode = $0.code }),
                        downloads: downloads,
                        onClose: { isLanguagePickerPresented = false }
                    )
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
                }
                if isCurrencyPickerPresented {
                    CurrencyPicker(
                        selection: Binding(get: { currencyCode }, set: { storedCurrencyCode = $0 }),
                        rates: rates,
                        onClose: { isCurrencyPickerPresented = false }
                    )
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
                }
            }
            .ignoresSafeArea()
            .animation(.easeInOut, value: isLanguagePickerPresented)
            .animation(.easeInOut, value: isCurrencyPickerPresented)
        }
        // Apple's download prompt is the only real sheet here, so it can present every time.
        .languageDownloadTask(downloads)
        .sensoryFeedback(.impact(weight: .medium), trigger: addedDishes)
        .priceEditor(isPresented: $isEditingPrice, currencyCode: currencyCode) { price in
            menuItem?.price = price
        }
        // Re-read whenever what's inside the frame may have changed, once it has settled.
        .task(id: readingKey) {
            isReading = true
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await readSelection()
            if !Task.isCancelled {
                isReading = false
            }
        }
    }

    private var navbar: some View {
        HStack {
            Button {
                router.pop(animated: false)
            } label: {
                Image(systemName: "arrow.left")
            }
            .buttonStyle(IconButton())
            Spacer()
        }
        .padding(16)
        .background(Colors.black, ignoresSafeAreaEdges: [.top, .horizontal])
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 12) {
                Button {
                    isLanguagePickerPresented = true
                } label: {
                    languageLabel.setFontStyle(Fonts.textXsBold)
                }
                .buttonStyle(SmallButton(variant: .dark))
                .overlay {
                    if isLanguageMissing {
                        Capsule().strokeBorder(Colors.danger, lineWidth: 1)
                    }
                }
                .accessibilityHint(isLanguageMissing ? "Language not downloaded" : "")
                Button {
                    isCurrencyPickerPresented = true
                } label: {
                    Text(currencyCode).setFontStyle(Fonts.textXsBold)
                }
                .buttonStyle(SmallButton(variant: .dark))
            }
            // Keep the language and currency readable; the order button gives way first.
            .layoutPriority(1)
            Spacer()
            Button {
                // Back to the Order screen this scan came from ("Add more" on an order opened
                // from Home), or a new one for an order started with "Scan menu".
                router.popToOrPush(.order(orderSession.currentOrder(in: modelContext.container)))
            } label: {
                Text("Order \((shownTotal ?? orderTotal).formatted(.usd))")
                    .setFontStyle(Fonts.textXsBold)
            }
            .buttonStyle(SmallButton())
            // Bounces when an added dish lands on it.
            .phaseAnimator([1.0, 1.15], trigger: landedDishes) { content, scale in
                content.scaleEffect(scale)
            } animation: { scale in
                // Quick pop up, then a short spring back.
                scale > 1 ? .easeOut(duration: 0.08) : .spring(duration: 0.15, bounce: 0.3)
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { orderButtonFrame = $0 }
        }
        .padding(16)
        .background(Colors.black, ignoresSafeAreaEdges: [.bottom, .horizontal])
    }

    /// The stored currency, or the default if it's no longer offered (e.g. a previously saved "USD").
    private var currencyCode: String {
        MenuLanguage.menuCurrencies.contains(storedCurrencyCode) ? storedCurrencyCode : MenuLanguage.defaultCurrency
    }

    private var language: MenuLanguage {
        MenuLanguage.menuLanguage(code: languageCode)
    }

    private var languageLabel: Text {
        isLanguageMissing
            ? Text("\(Image(systemName: "exclamationmark.triangle")) \(language.name)")
            : Text(language.name)
    }

    /// The menu language can't be translated until it's downloaded.
    private var isLanguageMissing: Bool {
        downloads.state(of: language) != .downloaded
    }

    // MARK: - Reading the selection

    /// Everything that changes what's inside the selection frame.
    private struct ReadingKey: Equatable {
        var selection: CGRect
        var selectionArea: CGRect
        var photoFrame: CGRect
        var transform: PhotoTransform
        var rotation: Double
        var languageCode: String
        var isLanguageMissing: Bool
        /// Prices are found by the currency's symbols.
        var currencyCode: String
    }

    private var readingKey: ReadingKey {
        ReadingKey(
            selection: currentSelection,
            selectionArea: selectionArea,
            photoFrame: photoFrame,
            transform: photoTransform,
            rotation: photoRotation,
            languageCode: languageCode,
            isLanguageMissing: isLanguageMissing,
            currencyCode: currencyCode
        )
    }

    private var currentSelection: CGRect {
        selection ?? defaultSelection(in: selectionArea.size)
    }

    /// Crops the photo under the frame, reads its text, splits off the price and translates the rest.
    private func readSelection() async {
        guard let photo, !photoFrame.isEmpty, !selectionArea.isEmpty else { return }
        // The frame's rect is relative to its area; the crop needs it relative to the photo.
        let rect = currentSelection.offsetBy(
            dx: selectionArea.minX - photoFrame.minX,
            dy: selectionArea.minY - photoFrame.minY
        )
        guard let crop = MenuReader.crop(
            photo,
            containerSize: photoFrame.size,
            transform: photoTransform,
            rotation: .degrees(photoRotation),
            rect: rect
        ) else { return }

        let text = await MenuReader.recognizeText(in: crop, language: language.locale)
        guard !Task.isCancelled else { return }
        let (dishText, price) = MenuReader.splitPrice(from: text, currencyCode: currencyCode)
        var item = MenuItem(originalText: dishText, price: price, photo: crop)
        menuItem = item

        guard !dishText.isEmpty, !isLanguageMissing else { return }
        item.translatedText = await MenuReader.translate(
            dishText,
            from: language.locale,
            to: MenuLanguage.translationTarget.locale
        )
        guard !Task.isCancelled else { return }
        menuItem = item
    }

    /// The menu price converted from the chosen currency to US dollars.
    private var usdPrice: Decimal? {
        guard let price = menuItem?.price, let rate = rates.rates[currencyCode], rate > 0 else { return nil }
        return price / rate
    }

    private var tooltip: TooltipContent {
        guard photo != nil else {
            return TooltipContent(text: "Take a photo of a menu to translate it.")
        }
        if isLanguageMissing {
            if downloads.isDisconnected(language) {
                // Installed, but the translation service stopped responding; downloading it again
                // from the language list reconnects.
                return TooltipContent(
                    text: "Translation stopped working. Choose \(language.name) below to download it again.",
                    price: priceLine
                )
            }
            return TooltipContent(text: "Download \(language.name) to translate.", price: priceLine)
        }
        if isReading {
            // The previous dish's price would be stale while the new one is read.
            return TooltipContent(text: "Translating…")
        }
        guard let menuItem, !menuItem.originalText.isEmpty else {
            return TooltipContent(text: "No text here. Move the frame over a dish.")
        }
        return TooltipContent(text: menuItem.translatedText ?? menuItem.originalText, price: priceLine)
    }

    /// "Price: $29.77 (550 MXN)", just the menu price when there's no rate to convert with, or
    /// "Price: ?" for a dish whose price wasn't recognized (or set with Edit price).
    private var priceLine: String? {
        guard let menuItem, !menuItem.originalText.isEmpty else { return nil }
        guard menuItem.price != nil else { return "Price: ?" }
        return "Price: " + CurrencyInfo.priceDescription(usd: usdPrice, menuPrice: menuItem.price, currencyCode: currencyCode)
    }

    /// Some dish text was read inside the frame.
    private var hasText: Bool {
        !(menuItem?.originalText.isEmpty ?? true)
    }

    /// A dish can only be ordered once it has a price.
    private var hasPrice: Bool {
        hasText && menuItem?.price != nil
    }

    private var canAddToOrder: Bool {
        !isReading && hasPrice
    }

    private func startEditingPrice() {
        guard hasText, !isReading else { return }
        isEditingPrice = true
    }

    private func defaultSelection(in size: CGSize) -> CGRect {
        // Centered in the photo area.
        CGRect(x: 18, y: (size.height - 51) / 2, width: size.width - 36, height: 51)
    }

    private var orderTotal: Decimal {
        orderSession.order?.total ?? 0
    }

    private func addToOrder() {
        guard let menuItem, canAddToOrder else { return }
        // Keeps the button's total until the dish lands on it.
        if shownTotal == nil {
            shownTotal = orderTotal
        }
        orderSession.add(Dish(
            originalName: menuItem.originalText,
            translatedName: menuItem.translatedText ?? menuItem.originalText,
            price: usdPrice ?? 0,
            photo: menuItem.photo,
            menuPrice: menuItem.price,
            menuCurrencyCode: currencyCode
        ), in: modelContext.container)
        addedDishes += 1
        // The selection frame's screen position; its rect is relative to its area.
        let from = currentSelection.offsetBy(dx: selectionArea.minX, dy: selectionArea.minY)
        flyingDishes.append(FlyingDish(image: menuItem.photo, from: from, orderTotal: orderTotal))
    }
}

/// Full-screen menu photo that can always be zoomed (two fingers) and panned; rotation comes from `RotationDial`.
/// Untouched, it is framed exactly like `FullScreenPhoto`, so it lines up with the Scan preview.
private struct ZoomablePhoto: View {
    let image: UIImage
    let rotation: Angle
    /// Committed zoom and pan, shared so the selected part of the photo can be cropped.
    @Binding var transform: PhotoTransform
    /// The full-screen container's screen frame, also needed for cropping.
    @Binding var frame: CGRect

    // Live changes during a gesture; reset automatically when it ends or is cancelled.
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var translation: CGSize = .zero

    private let scaleRange: ClosedRange<CGFloat> = 0.5...5

    var body: some View {
        // Screen-sized container with the photo centered in an overlay; a bare `scaledToFill` image
        // is wider than the screen and would size and offset its frame to match.
        Color.clear
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(clampedScale(transform.scale * magnification))
                    .rotationEffect(rotation)
                    .offset(
                        x: transform.offset.width + translation.width,
                        y: transform.offset.height + translation.height
                    )
            }
            .contentShape(.rect)
            .gesture(zoom.simultaneously(with: pan))
            .clipped()
            // Measured inside `ignoresSafeArea()`: measuring from outside reports only the safe area,
            // which shifted every crop by the status bar height.
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .ignoresSafeArea()
    }

    private var zoom: some Gesture {
        MagnifyGesture()
            .updating($magnification) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                transform.scale = clampedScale(transform.scale * value.magnification)
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .updating($translation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                transform.offset.width += value.translation.width
                transform.offset.height += value.translation.height
            }
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, scaleRange.lowerBound), scaleRange.upperBound)
    }
}

/// A dish photo on its way from the selection frame to the order button after "Add to order".
private struct FlyingDish: Identifiable {
    let id = UUID()
    let image: UIImage
    /// Screen frame of the selection when the dish was added.
    let from: CGRect
    /// The order's total with this dish, shown once it lands.
    let orderTotal: Decimal
}

/// Shrinks the dish photo from the selection frame into the order button, then calls `onLanded`.
private struct FlyingDishView: View {
    let dish: FlyingDish
    let from: CGRect
    let to: CGRect
    let onLanded: () -> Void

    @State private var hasLanded = false

    var body: some View {
        Image(uiImage: dish.image)
            .resizable()
            .frame(width: from.width, height: from.height)
            .clipShape(.rect(cornerRadius: 4))
            .scaleEffect(hasLanded ? endScale : 1)
            .opacity(hasLanded ? 0.3 : 1)
            .position(hasLanded ? CGPoint(x: to.midX, y: to.midY) : CGPoint(x: from.midX, y: from.midY))
            .onAppear {
                withAnimation(.easeIn(duration: 0.45)) {
                    hasLanded = true
                } completion: {
                    onLanded()
                }
            }
    }

    /// About the size of the order button's text when it arrives.
    private var endScale: CGFloat {
        min(1, 24 / max(from.width, from.height, 1))
    }
}

/// Text shown in the selection frame's tooltip: the translation (or a status) and the price.
private struct TooltipContent {
    var text: String
    var price: String?
}

/// Movable, resizable frame over the menu photo with the translation above and actions below.
private struct SelectionFrame: View {
    @Binding var rect: CGRect
    let bounds: CGSize
    let tooltip: TooltipContent
    /// Hidden while the dish has no price; "Edit price" stays so one can be entered.
    let showsAddToOrder: Bool
    let canAddToOrder: Bool
    /// Hidden when no dish text was read; disabled, like "Add to order", while reading.
    let showsEditPrice: Bool
    let canEditPrice: Bool
    let onAddToOrder: () -> Void
    let onEditPrice: () -> Void

    /// Frame when a move/pinch began.
    @State private var transformStart: CGRect?
    /// Each handle's corner position when its drag began, so several handles can be dragged at once.
    @State private var cornerStarts: [Corner: CGPoint] = [:]
    @State private var tooltipHeight: CGFloat = 0
    @State private var actionsSize: CGSize = .zero

    private let minSize = CGSize(width: 60, height: 20)
    /// Keeps the frame this far from the edges, so the corner dots (16pt) aren't cut off.
    private let inset: CGFloat = 8
    private let spacing: CGFloat = 16
    /// Keeps the translation readable when the frame is narrow.
    private let minTooltipWidth: CGFloat = 240

    private enum Corner: CaseIterable {
        case topLeading, topTrailing, bottomLeading, bottomTrailing

        var isLeading: Bool { self == .topLeading || self == .bottomLeading }
        var isTop: Bool { self == .topLeading || self == .topTrailing }
    }

    /// Where the tooltip and actions go relative to the frame, depending on free space.
    private enum Placement {
        /// Tooltip above, actions below.
        case split
        /// Frame, tooltip, actions — when the frame is near the top.
        case below
        /// Actions, tooltip, frame — when the frame is near the bottom.
        case above
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            tooltipView
                .offset(x: clampedX(rect.minX, width: tooltipWidth), y: tooltipTop)
            actions
                .offset(x: clampedX(rect.minX, width: actionsSize.width), y: actionsTop)
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Colors.primary, lineWidth: 1)
                .contentShape(.rect)
                .frame(width: rect.width, height: rect.height)
                .gesture(moveAndPinch)
                .offset(x: rect.minX, y: rect.minY)
            // Placed at the corner points directly, so they stay on the corners even when the frame
            // is smaller than a handle's touch target.
            ForEach(Corner.allCases, id: \.self) { corner in
                handle(corner)
                    .position(point(of: corner, in: rect))
            }
        }
        .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
    }

    private var placement: Placement {
        let tooltipSpace = tooltipHeight + spacing
        let actionsSpace = actionsSize.height + spacing
        let spaceAbove = rect.minY
        let spaceBelow = bounds.height - rect.maxY
        if spaceAbove >= tooltipSpace, spaceBelow >= actionsSpace { return .split }
        if spaceBelow >= tooltipSpace + actionsSpace { return .below }
        if spaceAbove >= tooltipSpace + actionsSpace { return .above }
        return spaceBelow >= spaceAbove ? .below : .above
    }

    private var tooltipTop: CGFloat {
        switch placement {
        case .split, .above: rect.minY - spacing - tooltipHeight
        case .below: rect.maxY + spacing
        }
    }

    private var actionsTop: CGFloat {
        switch placement {
        case .split: rect.maxY + spacing
        case .below: rect.maxY + spacing + tooltipHeight + spacing
        case .above: rect.minY - spacing - tooltipHeight - spacing - actionsSize.height
        }
    }

    private var tooltipWidth: CGFloat {
        min(max(rect.width, minTooltipWidth), bounds.width)
    }

    /// Aligns to the frame's leading edge but keeps the whole view inside the photo area.
    private func clampedX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        min(max(x, 0), max(bounds.width - width, 0))
    }

    private var tooltipView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tooltip.text)
                .setFontStyleMultiline(Fonts.textXs)
            if let price = tooltip.price {
                Text(price)
                    .setFontStyleMultiline(Fonts.textXsBold)
            }
        }
        .foregroundStyle(Colors.white)
        .padding(8)
        .frame(width: tooltipWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(Colors.primary, in: .rect(cornerRadius: 4))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tooltipHeight = $0 }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            if showsAddToOrder {
                Button(action: onAddToOrder) {
                    Text("Add to order").setFontStyle(Fonts.textXsBold)
                }
                .buttonStyle(SmallButton(variant: .primary))
                .disabled(!canAddToOrder)
                .opacity(canAddToOrder ? 1 : 0.5)
            }
            if showsEditPrice {
                Button(action: onEditPrice) {
                    Text("Edit price").setFontStyle(Fonts.textXsBold)
                }
                .buttonStyle(SmallButton())
                .overlay(Capsule().strokeBorder(Colors.primary, lineWidth: 1))
                .disabled(!canEditPrice)
                .opacity(canEditPrice ? 1 : 0.5)
            }
        }
        .fixedSize()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { actionsSize = $0 }
    }

    private func handle(_ corner: Corner) -> some View {
        Circle()
            .fill(Colors.primary)
            .frame(width: 16, height: 16)
            // Larger invisible touch target centered on the corner.
            .frame(width: 44, height: 44)
            .contentShape(.rect)
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        let start = cornerStarts[corner] ?? point(of: corner, in: rect)
                        cornerStarts[corner] = start
                        let target = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
                        rect = resized(rect, moving: corner, to: target)
                    }
                    .onEnded { _ in
                        cornerStarts[corner] = nil
                    }
            )
    }

    /// One finger moves the frame; two fingers also resize it around its center.
    private var moveAndPinch: some Gesture {
        DragGesture(coordinateSpace: .global)
            .simultaneously(with: MagnifyGesture())
            .onChanged { value in
                let start = transformStart ?? rect
                transformStart = start
                rect = transformed(
                    start,
                    by: value.first?.translation ?? .zero,
                    magnification: value.second?.magnification ?? 1
                )
            }
            .onEnded { _ in
                transformStart = nil
            }
    }

    private func transformed(_ start: CGRect, by translation: CGSize, magnification: CGFloat) -> CGRect {
        let width = min(max(start.width * magnification, minSize.width), bounds.width - 2 * inset)
        let height = min(max(start.height * magnification, minSize.height), bounds.height - 2 * inset)
        let x = start.midX + translation.width - width / 2
        let y = start.midY + translation.height - height / 2
        return CGRect(
            x: min(max(x, inset), bounds.width - inset - width),
            y: min(max(y, inset), bounds.height - inset - height),
            width: width,
            height: height
        )
    }

    private func point(of corner: Corner, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: corner.isLeading ? rect.minX : rect.maxX,
            y: corner.isTop ? rect.minY : rect.maxY
        )
    }

    /// Moves only the edges that `corner` controls, leaving edges dragged by other handles intact.
    private func resized(_ current: CGRect, moving corner: Corner, to point: CGPoint) -> CGRect {
        var minX = current.minX, maxX = current.maxX, minY = current.minY, maxY = current.maxY
        if corner.isLeading {
            minX = min(max(point.x, inset), maxX - minSize.width)
        } else {
            maxX = max(min(point.x, bounds.width - inset), minX + minSize.width)
        }
        if corner.isTop {
            minY = min(max(point.y, inset), maxY - minSize.height)
        } else {
            maxY = max(min(point.y, bounds.height - inset), minY + minSize.height)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

#Preview {
    NavigationStack {
        TranslationView(photo: nil)
    }
    .environment(Router())
    .environment(LanguageDownloads())
    .environment(ExchangeRates())
    .environment(OrderSession())
    .modelContainer(.preview)
}
