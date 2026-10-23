import AVFoundation
import SwiftUI

/// Owns the capture session; all session work runs on a private serial queue.
nonisolated final class CameraSession: @unchecked Sendable {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "CameraSession")
    private var device: AVCaptureDevice?
    /// Capture delegates are held until their photo is delivered.
    private var captureDelegates: [Int64: PhotoCaptureDelegate] = [:]

    func start() {
        queue.async { [self] in
            if session.inputs.isEmpty {
                configure()
            }
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    /// Rotation that makes the back camera's image upright for an interface orientation (the
    /// sensor's natural orientation is landscape with the Dynamic Island on the left).
    static func videoRotationAngle(for orientation: UIInterfaceOrientation) -> CGFloat {
        switch orientation {
        case .landscapeRight: 0
        case .landscapeLeft: 180
        case .portraitUpsideDown: 270
        default: 90
        }
    }

    /// Returns `nil` when no photo could be taken (e.g. no camera in the simulator).
    /// `rotationAngle` should match the preview's, so the photo is framed like the screen.
    func capturePhoto(rotationAngle: CGFloat) async -> UIImage? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard session.isRunning, let connection = photoOutput.connection(with: .video) else {
                    continuation.resume(returning: nil)
                    return
                }
                if connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                }
                let settings = AVCapturePhotoSettings()
                // Lighter processing: shorter capture delay and closer to the frozen preview frame.
                settings.photoQualityPrioritization = .speed
                let id = settings.uniqueID
                captureDelegates[id] = PhotoCaptureDelegate { [self] image in
                    queue.async { captureDelegates[id] = nil }
                    continuation.resume(returning: image)
                }
                photoOutput.capturePhoto(with: settings, delegate: captureDelegates[id]!)
            }
        }
    }

    /// Turns the flashlight on or off; returns whether it is now on (false when there is no torch).
    func setTorch(_ isOn: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard let device, device.hasTorch, session.isRunning,
                      (try? device.lockForConfiguration()) != nil else {
                    continuation.resume(returning: false)
                    return
                }
                if isOn {
                    try? device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
                continuation.resume(returning: device.torchMode == .on)
            }
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(photoOutput) else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        session.addInput(input)
        session.addOutput(photoOutput)
        session.commitConfiguration()
        self.device = device
    }
}

private nonisolated final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        completion(photo.fileDataRepresentation().flatMap(UIImage.init(data:)))
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// Holds the last displayed frame instead of showing live video.
    var isFrozen = false
    /// Reports whether the preview is actually displaying camera frames.
    var onPreviewingChange: (Bool) -> Void = { _ in }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onPreviewingChange = onPreviewingChange
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.onPreviewingChange = onPreviewingChange
        uiView.previewLayer.connection?.isEnabled = !isFrozen
    }

    final class PreviewView: UIView {
        var onPreviewingChange: (Bool) -> Void = { _ in }
        private var observation: NSKeyValueObservation?

        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        /// Called on rotation (the bounds change): keeps the camera image upright for the interface.
        override func layoutSubviews() {
            super.layoutSubviews()
            guard let orientation = window?.windowScene?.effectiveGeometry.interfaceOrientation,
                  let connection = previewLayer.connection else { return }
            let angle = CameraSession.videoRotationAngle(for: orientation)
            if connection.videoRotationAngle != angle, connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            observation = previewLayer.observe(\.isPreviewing, options: [.initial, .new]) { [weak self] layer, _ in
                let isPreviewing = layer.isPreviewing
                Task { @MainActor in
                    self?.onPreviewingChange(isPreviewing)
                    // The connection only exists once the session runs; apply the rotation to it.
                    self?.setNeedsLayout()
                }
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

/// Fills the whole screen with `image` using the same aspect-fill framing as `CameraPreview`,
/// so a captured photo lines up exactly with the live preview it replaces.
struct FullScreenPhoto: View {
    let image: UIImage

    var body: some View {
        Color.clear
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .ignoresSafeArea()
    }
}
