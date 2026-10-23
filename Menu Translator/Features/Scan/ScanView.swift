import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI

struct ScanView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(OrderSession.self) private var orderSession
    @Environment(LanguageDownloads.self) private var downloads
    @State private var camera = CameraSession()
    @State private var isCapturing = false
    @State private var isPreviewing = false
    @State private var isPreviewFrozen = false
    @State private var isTorchOn = false
    @State private var pickedPhoto: PhotosPickerItem?
    /// Last captured photo, shown in place of the preview until the camera displays frames again.
    @State private var frozenFrame: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            navbar
            Spacer()
            Button {
                Task { await takePhoto() }
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 26))
                    .frame(width: 80, height: 80)
                    .background(Colors.primary, in: .circle)
                    .overlay(Circle().strokeBorder(Colors.white, lineWidth: 2))
                    .foregroundStyle(Colors.white)
            }
            .buttonStyle(ShutterButtonStyle())
            .disabled(isCapturing)
            .accessibilityLabel("Take photo")
            footer
        }
        .background {
            ZStack {
                if ScreenshotMode.isEnabled, let menuPhoto = ScreenshotMode.menuPhoto {
                    FullScreenPhoto(image: menuPhoto)
                } else {
                    CameraPreview(session: camera.session, isFrozen: isPreviewFrozen) { isPreviewing = $0 }
                        .ignoresSafeArea()
                }
                if let frozenFrame, !isPreviewing, !ScreenshotMode.isEnabled {
                    FullScreenPhoto(image: frozenFrame)
                }
                HelperGrid()
                    .ignoresSafeArea()
            }
        }
        .background(Colors.black)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // Know which languages are installed before Translation opens, so it doesn't flash a warning.
            await downloads.refresh()
        }
        .task {
            isPreviewFrozen = false
            guard !ScreenshotMode.isEnabled, await AVCaptureDevice.requestAccess(for: .video) else { return }
            camera.start()
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task { await openPicked(item) }
        }
        .onDisappear {
            // Stopping the session also turns the torch off.
            isTorchOn = false
            camera.stop()
        }
    }

    private func takePhoto() async {
        if ScreenshotMode.isEnabled {
            router.push(.translation(ScreenshotMode.menuPhoto), animated: false)
            return
        }
        isCapturing = true
        defer { isCapturing = false }
        // Freeze on the tapped frame right away; processing the photo takes a moment.
        frozenFrame = nil
        isPreviewFrozen = true
        let orientation = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .effectiveGeometry.interfaceOrientation ?? .portrait
        let photo = await camera.capturePhoto(rotationAngle: CameraSession.videoRotationAngle(for: orientation))
        isTorchOn = false
        camera.stop()
        frozenFrame = photo
        router.push(.translation(photo), animated: false)
    }

    private func openPicked(_ item: PhotosPickerItem) async {
        // Reset so picking the same photo again still triggers.
        pickedPhoto = nil
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        isTorchOn = false
        camera.stop()
        // A library photo doesn't match the camera view, so don't show it when coming back.
        frozenFrame = nil
        router.push(.translation(image), animated: false)
    }

    private var navbar: some View {
        HStack {
            Button {
                router.pop()
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
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    Image(systemName: "photo")
                }
                .buttonStyle(IconButton())
                .accessibilityLabel("Choose photo from library")
                Button {
                    Task { isTorchOn = await camera.setTorch(!isTorchOn) }
                } label: {
                    Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                }
                .buttonStyle(IconButton())
                .accessibilityLabel(isTorchOn ? "Turn off flashlight" : "Turn on flashlight")
            }
            Spacer()
            Button {
                // Back to the Order screen this scan came from ("Add more" on an order opened
                // from Home), or a new one for an order started with "Scan menu".
                router.popToOrPush(.order(orderSession.currentOrder(in: modelContext.container)))
            } label: {
                Text("Order \((orderSession.order?.total ?? 0).formatted(.usd))")
                    .setFontStyle(Fonts.textXsBold)
            }
            .buttonStyle(SmallButton())
            .accessibilityIdentifier("orderButton")
        }
        .padding(16)
        .background(Colors.black, ignoresSafeAreaEdges: [.bottom, .horizontal])
    }
}

/// Keeps full opacity while pressed and shrinks slightly instead.
/// A crisp haptic fires on touch down, approximating the system Camera shutter.
private struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7), trigger: configuration.isPressed) { _, isPressed in
                isPressed
            }
    }
}

/// Rule-of-thirds guide over the camera preview.
private struct HelperGrid: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Path { path in
                for i in 1...2 {
                    let x = size.width * CGFloat(i) / 3
                    let y = size.height * CGFloat(i) / 3
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
            }
            .stroke(Colors.white, lineWidth: 1)
            .opacity(0.5)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    NavigationStack {
        ScanView()
    }
    .environment(Router())
    .environment(LanguageDownloads())
    .environment(OrderSession())
    .modelContainer(.preview)
}
