import SwiftUI
import Combine
import StagePointCore

enum WorkspaceMode: String, CaseIterable { case mapping = "기준점 등록", points = "포인트 지정", measure = "정확도 검증" }

@MainActor
final class StageSession: ObservableObject {
    @Published var mode: WorkspaceMode = .mapping
    @Published var quad = StageQuad.manual
    @Published var mapping: StageMapping?
    @Published var widthText = "6.0"
    @Published var depthText = "4.0"
    @Published var proposals: [RectangleProposal] = []
    @Published var selectedProposal: UUID?
    @Published var isDetecting = false
    @Published var frozenFrame: UIImage?
    @Published var message = "무대 바닥의 A·B·C·D를 확인하세요."
    @Published var target: Point2D?
    @Published var selectedCorner = 0
    private var detectionID = UUID()
    var stageSize: StageSize { .init(width: Double(widthText) ?? 0, depth: Double(depthText) ?? 0) }

    func invalidate(_ reason: String = "기준점이 변경됐습니다. 매핑을 다시 적용하세요.") {
        mapping = nil; message = reason
    }
    func detect(_ frame: UIImage) {
        let requestID = UUID(); detectionID = requestID
        frozenFrame = frame; mode = .mapping; isDetecting = true; proposals = []; selectedProposal = nil
        invalidate("사각형 후보를 찾고 있습니다…")
        RectangleDetector.detect(in: frame) { [weak self] result in
            guard let self, self.detectionID == requestID else { return }
            self.isDetecting = false
            switch result {
            case .success(let proposals):
                self.proposals = proposals
                if let first = proposals.first { self.select(first) }
                else { self.message = "후보를 찾지 못했습니다. 수동 기준점을 조정하세요." }
            case .failure(let error): self.message = "인식 실패: \(error.localizedDescription). 수동 조정할 수 있습니다."
            }
        }
    }
    func select(_ proposal: RectangleProposal) {
        quad = proposal.quad; selectedProposal = proposal.id
        invalidate("자동 제안입니다. 무대 바닥인지 확인하고 모서리를 옮기세요.")
    }
    func manual(frame: UIImage?) {
        detectionID = UUID(); isDetecting = false
        frozenFrame = frame; quad = .manual; proposals = []; selectedProposal = nil; mode = .mapping
        invalidate("수동 설정 · 네 점을 실제 바닥 기준점에 맞추세요.")
    }
    func moveCorner(_ index: Int, to point: Point2D) {
        guard !isDetecting else { return }
        selectedCorner = index; quad.corners[index] = point.clamped(); selectedProposal = nil; invalidate()
    }
    func flipFront() {
        quad.corners = Array(quad.corners[2...]) + Array(quad.corners[0..<2]); invalidate()
    }
    func apply() {
        guard stageSize.isValid, stageSize.width <= 100, stageSize.depth <= 100,
              let mapping = StageMapping(quad: quad) else { message = "치수(0 초과~100m)와 교차하지 않는 네 점을 확인하세요."; return }
        self.mapping = mapping; mode = .points
        message = "매핑 적용됨 · 화면의 바닥을 눌러 목표점을 지정하세요."
    }
    func tap(_ imagePoint: Point2D) {
        guard let point = mapping?.stagePoint(from: imagePoint), point.isUnitPoint else {
            message = "매핑된 무대 안쪽을 선택하세요."; return
        }
        target = point; message = "목표 A를 지정했습니다."
    }
}
