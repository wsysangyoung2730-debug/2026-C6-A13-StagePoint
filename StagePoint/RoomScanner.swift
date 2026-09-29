// Adapted from xrpjwk8/StageVision, commit 1757e0c, at user's request.
// See docs/phase1.md for provenance and differences.
import SwiftUI
import Combine
import RoomPlan
import ARKit
import StagePointCore

struct StageScanDraft: Codable {
    var size: StageSize
    var floorPolygon: [Point2D]
    var floorTransform: [Float]
    var rawRoom: Data?
    var capturedAt = Date()
}

enum StageScanArchive {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StagePointLive", isDirectory: true).appendingPathComponent("latest-scan.json")
    }
    static func save(_ draft: StageScanDraft) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(draft).write(to: url, options: .atomic)
    }
    static func load() throws -> StageScanDraft { try JSONDecoder().decode(StageScanDraft.self, from: Data(contentsOf: url)) }
}

enum ScanResult {
    case success(StageScanDraft)
    case failure(String)
}

private enum ProjectedLineKind {
    case grid
    case boundary
}

private struct ProjectedGridSegment {
    let start: CGPoint
    let end: CGPoint
    let kind: ProjectedLineKind
}

struct RoomScannerView: View {
    let onFinish: (ScanResult) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = RoomScannerController()

    var body: some View {
        ZStack(alignment: .bottom) {
            RoomCaptureContainer(controller: controller)
                .ignoresSafeArea()
            LiveStageGridOverlay(controller: controller)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Circle().fill(.mint).frame(width: 8, height: 8)
                    Text("1m 격자")
                    Circle().fill(.orange).frame(width: 8, height: 8)
                    Text("감지된 바닥 외곽")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                Text(controller.status)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                HStack {
                    Button("취소") {
                        controller.cancel()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    Button("스캔 완료") { controller.finish() }
                        .buttonStyle(.borderedProminent)
                        .disabled(controller.isProcessing)
                }
            }
            .padding(20)
        }
        .onAppear { controller.onResult = onFinish }
        .onDisappear { controller.cancel() }
    }
}

private struct LiveStageGridOverlay: View {
    @ObservedObject var controller: RoomScannerController

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, _ in
                for segment in controller.projectedGridSegments {
                    var path = Path()
                    path.move(to: segment.start)
                    path.addLine(to: segment.end)
                    switch segment.kind {
                    case .grid:
                        context.stroke(path, with: .color(.mint.opacity(0.9)), lineWidth: 1.5)
                    case .boundary:
                        context.stroke(path, with: .color(.orange), lineWidth: 4)
                    }
                }
            }
            .onAppear {
                controller.updateViewportSize(geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                controller.updateViewportSize(newSize)
            }
        }
    }
}

final class RoomScannerController: NSObject, ObservableObject, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
    @Published var status = "바닥을 천천히 비추면 1m 좌표 격자가 나타납니다."
    @Published var isProcessing = false
    @Published fileprivate var projectedGridSegments: [ProjectedGridSegment] = []
    var onResult: ((ScanResult) -> Void)?
    weak var captureView: RoomCaptureView?
    private var latestFloor: CapturedRoom.Surface?
    private var viewportSize: CGSize = .zero
    private var displayLink: CADisplayLink?

    override init() { super.init() }
    required init?(coder: NSCoder) { super.init() }
    func encode(with coder: NSCoder) {}

    func start(_ view: RoomCaptureView) {
        captureView = view
        view.delegate = self
        view.captureSession.delegate = self
        view.captureSession.run(configuration: RoomCaptureSession.Configuration())
        let displayLink = CADisplayLink(target: self, selector: #selector(refreshGridForCurrentFrame))
        displayLink.preferredFramesPerSecond = 20
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    func updateViewportSize(_ size: CGSize) {
        viewportSize = size
        refreshProjectedGrid()
    }

    func finish() {
        isProcessing = true
        status = "스캔 결과를 처리하는 중입니다…"
        displayLink?.invalidate()
        displayLink = nil
        captureView?.captureSession.stop()
    }

    func cancel() {
        displayLink?.invalidate()
        displayLink = nil
        captureView?.captureSession.stop()
        onResult = nil
    }

    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        DispatchQueue.main.async { [weak self] in self?.updateLiveFloor(from: room) }
    }

    func captureSession(_ session: RoomCaptureSession, didChange room: CapturedRoom) {
        DispatchQueue.main.async { [weak self] in self?.updateLiveFloor(from: room) }
    }

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        if let error {
            DispatchQueue.main.async { [weak self] in
                self?.onResult?(.failure(error.localizedDescription)); self?.onResult = nil
            }
            return false
        }
        return true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        DispatchQueue.main.async { [weak self] in self?.process(processedResult, error: error) }
    }

    private func process(_ processedResult: CapturedRoom, error: Error?) {
        displayLink?.invalidate()
        displayLink = nil
        if let error {
            onResult?(.failure(error.localizedDescription))
        } else if let floor = processedResult.floors.max(by: { floorArea($0) < floorArea($1) }) {
            let dimensions = [Double(floor.dimensions.x), Double(floor.dimensions.y), Double(floor.dimensions.z)]
                .sorted(by: >)
            let width = dimensions[0]
            let depth = dimensions[1]
            if width >= 1, depth >= 1 {
                let polygon = localPolygon(for: floor).map { Point2D(x: Double($0.x), y: Double($0.y)) }
                let transform = (0..<4).flatMap { column in (0..<4).map { row in floor.transform[column][row] } }
                onResult?(.success(StageScanDraft(size: StageSize(width: width, depth: depth), floorPolygon: polygon,
                    floorTransform: transform, rawRoom: try? JSONEncoder().encode(processedResult))))
            } else {
                onResult?(.failure("바닥의 크기를 확인할 수 없습니다. 직접 입력해 주세요."))
            }
        } else {
            onResult?(.failure("바닥을 감지하지 못했습니다. 직접 입력해 주세요."))
        }
        onResult = nil
    }

    private func floorArea(_ floor: CapturedRoom.Surface) -> Double {
        if floor.polygonCorners.count >= 3 {
            let polygon = floor.polygonCorners
            var twiceArea: Float = 0
            for index in polygon.indices {
                let next = polygon[(index + 1) % polygon.count]
                twiceArea += polygon[index].x * next.y - next.x * polygon[index].y
            }
            return Double(abs(twiceArea) / 2)
        }
        let dimensions = [Double(floor.dimensions.x), Double(floor.dimensions.y), Double(floor.dimensions.z)]
            .sorted(by: >)
        return dimensions[0] * dimensions[1]
    }

    private func updateLiveFloor(from room: CapturedRoom) {
        guard let floor = room.floors.max(by: { floorArea($0) < floorArea($1) }) else {
            return
        }
        latestFloor = floor
        status = floor.polygonCorners.count > 4
            ? "비정형 바닥 외곽과 1m 좌표 격자를 표시하고 있습니다."
            : "바닥 위에 1m 좌표 격자를 표시하고 있습니다."
        refreshProjectedGrid()
    }

    @objc private func refreshGridForCurrentFrame() {
        refreshProjectedGrid()
    }

    private func refreshProjectedGrid() {
        guard
            viewportSize.width > 0,
            viewportSize.height > 0,
            let floor = latestFloor,
            let frame = captureView?.captureSession.arSession.currentFrame
        else {
            projectedGridSegments = []
            return
        }

        let polygon = localPolygon(for: floor)
        guard polygon.count >= 3 else {
            projectedGridSegments = []
            return
        }

        let orientation = captureView?.window?.windowScene?.interfaceOrientation ?? .landscapeRight
        let camera = frame.camera
        var localSegments: [(SIMD2<Float>, SIMD2<Float>, ProjectedLineKind)] = []

        for index in polygon.indices {
            localSegments.append((polygon[index], polygon[(index + 1) % polygon.count], .boundary))
        }

        let minX = polygon.map(\.x).min() ?? 0
        let maxX = polygon.map(\.x).max() ?? 0
        let minY = polygon.map(\.y).min() ?? 0
        let maxY = polygon.map(\.y).max() ?? 0

        var x = minX + 1
        while x < maxX {
            let intersections = verticalIntersections(x: x, polygon: polygon)
            for pair in paired(intersections) {
                localSegments.append((SIMD2(x, pair.0), SIMD2(x, pair.1), .grid))
            }
            x += 1
        }

        var y = minY + 1
        while y < maxY {
            let intersections = horizontalIntersections(y: y, polygon: polygon)
            for pair in paired(intersections) {
                localSegments.append((SIMD2(pair.0, y), SIMD2(pair.1, y), .grid))
            }
            y += 1
        }

        projectedGridSegments = localSegments.compactMap { start, end, kind in
            guard
                let projectedStart = project(start, floor: floor, camera: camera, orientation: orientation),
                let projectedEnd = project(end, floor: floor, camera: camera, orientation: orientation)
            else { return nil }
            return ProjectedGridSegment(start: projectedStart, end: projectedEnd, kind: kind)
        }
    }

    private func localPolygon(for floor: CapturedRoom.Surface) -> [SIMD2<Float>] {
        let corners = floor.polygonCorners.map { SIMD2<Float>($0.x, $0.y) }
        if corners.count >= 3 { return corners }

        let halfWidth = floor.dimensions.x / 2
        let halfDepth = floor.dimensions.y / 2
        guard halfWidth > 0, halfDepth > 0 else { return [] }
        return [
            SIMD2(-halfWidth, -halfDepth),
            SIMD2(halfWidth, -halfDepth),
            SIMD2(halfWidth, halfDepth),
            SIMD2(-halfWidth, halfDepth)
        ]
    }

    private func project(
        _ localPoint: SIMD2<Float>,
        floor: CapturedRoom.Surface,
        camera: ARCamera,
        orientation: UIInterfaceOrientation
    ) -> CGPoint? {
        let world4 = floor.transform * SIMD4<Float>(localPoint.x, localPoint.y, 0, 1)
        let world = SIMD3<Float>(world4.x, world4.y, world4.z)
        let cameraPoint = camera.transform.inverse * SIMD4<Float>(world.x, world.y, world.z, 1)
        guard cameraPoint.z < 0 else { return nil }

        let projected = camera.projectPoint(world, orientation: orientation, viewportSize: viewportSize)
        guard projected.x.isFinite, projected.y.isFinite else { return nil }
        return projected
    }

    private func verticalIntersections(x: Float, polygon: [SIMD2<Float>]) -> [Float] {
        var values: [Float] = []
        for index in polygon.indices {
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]
            guard (a.x <= x && b.x > x) || (b.x <= x && a.x > x) else { continue }
            let ratio = (x - a.x) / (b.x - a.x)
            values.append(a.y + ratio * (b.y - a.y))
        }
        return values.sorted()
    }

    private func horizontalIntersections(y: Float, polygon: [SIMD2<Float>]) -> [Float] {
        var values: [Float] = []
        for index in polygon.indices {
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]
            guard (a.y <= y && b.y > y) || (b.y <= y && a.y > y) else { continue }
            let ratio = (y - a.y) / (b.y - a.y)
            values.append(a.x + ratio * (b.x - a.x))
        }
        return values.sorted()
    }

    private func paired(_ values: [Float]) -> [(Float, Float)] {
        stride(from: 0, to: values.count - 1, by: 2).map { (values[$0], values[$0 + 1]) }
    }
}

private struct RoomCaptureContainer: UIViewRepresentable {
    let controller: RoomScannerController

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        controller.start(view)
        return view
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}
