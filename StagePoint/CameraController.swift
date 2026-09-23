import AVFoundation
import Combine
import UIKit
import Vision
import StagePointCore

struct RectangleProposal: Identifiable {
    let id = UUID()
    let quad: StageQuad
    let confidence: Float
}

final class CameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var frame: UIImage?
    @Published private(set) var message = "카메라 준비 중"
    @Published private(set) var unavailable = false
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "stagepoint.camera")
    private let context = CIContext()
    private var configured = false
    private var lastFrameTime = 0.0

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                if allowed { self?.configureAndStart() }
                else { self?.report("카메라 권한이 필요합니다. 설정에서 허용하거나 데모를 사용하세요.") }
            }
        default: report("카메라 권한이 꺼져 있습니다. 설정에서 허용하거나 데모를 사용하세요.")
        }
    }
    func stop() { queue.async { [weak self] in self?.session.stopRunning() } }
    private func report(_ message: String) {
        DispatchQueue.main.async { self.message = message; self.unavailable = true }
    }
    private func configureAndStart() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .hd1280x720
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: device), self.session.canAddInput(input) else {
                    self.session.commitConfiguration(); self.report("사용 가능한 후면 카메라가 없습니다."); return
                }
                self.session.addInput(input)
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                output.setSampleBufferDelegate(self, queue: self.queue)
                guard self.session.canAddOutput(output) else {
                    self.session.removeInput(input); self.session.commitConfiguration()
                    self.report("카메라 영상 출력을 시작할 수 없습니다."); return
                }
                self.session.addOutput(output)
                // Landscape-right UI, Vision, and preview all share this upright image buffer.
                if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(0) {
                    connection.videoRotationAngle = 0
                    connection.isVideoMirrored = false
                }
                self.session.commitConfiguration()
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.message = "후면 카메라 · 1×"; self.unavailable = false }
        }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let time = CACurrentMediaTime()
        guard time - lastFrameTime >= 0.10, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrameTime = time
        let image = CIImage(cvPixelBuffer: buffer)
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return }
        let frame = UIImage(cgImage: cgImage)
        DispatchQueue.main.async { self.frame = frame }
    }
}

enum RectangleDetector {
    static func detect(in image: UIImage, completion: @escaping (Result<[RectangleProposal], Error>) -> Void) {
        guard let cgImage = image.cgImage else { completion(.success([])); return }
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNDetectRectanglesRequest()
            request.maximumObservations = 8
            request.minimumConfidence = 0.35
            request.minimumSize = 0.15
            request.minimumAspectRatio = 0.15
            request.maximumAspectRatio = 1
            request.quadratureTolerance = 45
            do {
                try VNImageRequestHandler(cgImage: cgImage, orientation: .up).perform([request])
                let proposals = (request.results ?? []).compactMap { rectangle -> RectangleProposal? in
                    func point(_ p: CGPoint) -> Point2D { .init(x: p.x, y: 1 - p.y) }
                    let quad = StageQuad(corners: [point(rectangle.bottomLeft), point(rectangle.bottomRight),
                                                  point(rectangle.topRight), point(rectangle.topLeft)])
                    guard quad.isValid else { return nil }
                    return RectangleProposal(quad: quad, confidence: rectangle.confidence)
                }
                DispatchQueue.main.async { completion(.success(proposals)) }
            } catch { DispatchQueue.main.async { completion(.failure(error)) } }
        }
    }
}
