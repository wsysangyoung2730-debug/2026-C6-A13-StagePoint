import SwiftUI
import StagePointCore

extension Point2D {
    func screen(in rect: CGRect) -> CGPoint { .init(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
}

struct StageCanvas: View {
    @ObservedObject var model: StageSession
    let image: UIImage?
    var body: some View {
        GeometryReader { geometry in
            let rect = fittedRect(image: image?.size ?? CGSize(width: 16, height: 9), in: geometry.size)
            ZStack(alignment: .topLeading) {
                Color.black
                if let image {
                    Image(uiImage: image).resizable().frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                } else {
                    ContentUnavailableView("카메라 대기 중", systemImage: "camera", description: Text("카메라를 허용하거나 데모 무대를 사용하세요."))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                Canvas { context, _ in
                    if let map = StageMapping(quad: model.quad) {
                        for i in 0...6 {
                            drawLine(&context, map: map, from: .init(x: Double(i) / 6, y: 0), to: .init(x: Double(i) / 6, y: 1), rect: rect)
                        }
                        for i in 0...4 {
                            drawLine(&context, map: map, from: .init(x: 0, y: Double(i) / 4), to: .init(x: 1, y: Double(i) / 4), rect: rect)
                        }
                    }
                    var boundary = Path()
                    for (i, p) in model.quad.corners.enumerated() {
                        if i == 0 { boundary.move(to: p.screen(in: rect)) } else { boundary.addLine(to: p.screen(in: rect)) }
                    }
                    boundary.closeSubpath()
                    context.stroke(boundary, with: .color(model.quad.isValid ? .cyan : .red), lineWidth: 2)
                }.allowsHitTesting(false)
                if model.mode == .mapping {
                    ForEach(0..<4, id: \.self) { index in
                        Text(["A", "B", "C", "D"][index]).font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.black).frame(width: 34, height: 34)
                            .background(model.selectedCorner == index ? .white : .cyan, in: Circle())
                            .overlay(Circle().stroke(.black.opacity(0.5), lineWidth: 2))
                            .frame(width: 52, height: 52).contentShape(Circle())
                            .position(model.quad.corners[index].screen(in: rect))
                            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("stageCanvas")).onChanged { event in
                                model.moveCorner(index, to: .init(x: (event.location.x - rect.minX) / rect.width, y: (event.location.y - rect.minY) / rect.height))
                            })
                            .accessibilityLabel("기준점 \(["A", "B", "C", "D"][index])")
                            .accessibilityIdentifier("corner-\(index)")
                    }
                }
                ForEach(model.targets) { target in
                    if let p = model.mapping?.imagePoint(from: target.normalized) {
                        ZStack {
                            Image(systemName: "scope").font(.system(size: 28)).foregroundStyle(target.id == model.selectedTarget?.id ? .yellow : .cyan)
                            Text(target.name).font(.caption.bold()).padding(5).background(.black.opacity(0.75), in: Capsule()).offset(y: -28)
                        }.position(p.screen(in: rect)).allowsHitTesting(false)
                    }
                }
                if model.mode == .measure, let probe = model.probe, let p = model.mapping?.imagePoint(from: probe) {
                    Image(systemName: "plus.viewfinder").font(.system(size: 30)).foregroundStyle(.white)
                        .position(p.screen(in: rect)).allowsHitTesting(false)
                }
                VStack {
                    HStack { Label(model.frozenFrame == nil ? "LIVE" : "정지 화면", systemImage: model.frozenFrame == nil ? "circle.fill" : "pause.fill").font(.caption.bold()); Spacer() }
                    Spacer()
                    Text(model.message).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(12).foregroundStyle(.white).allowsHitTesting(false)
            }
            .coordinateSpace(name: "stageCanvas")
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard model.mode != .mapping, rect.contains(location) else { return }
                model.tap(.init(x: (location.x - rect.minX) / rect.width, y: (location.y - rect.minY) / rect.height))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityIdentifier("stage-canvas")
        }
    }
    private func fittedRect(image: CGSize, in size: CGSize) -> CGRect {
        let scale = min(size.width / image.width, size.height / image.height)
        let fitted = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2, width: fitted.width, height: fitted.height)
    }
    private func drawLine(_ context: inout GraphicsContext, map: StageMapping, from: Point2D, to: Point2D, rect: CGRect) {
        guard let a = map.imagePoint(from: from), let b = map.imagePoint(from: to) else { return }
        var path = Path(); path.move(to: a.screen(in: rect)); path.addLine(to: b.screen(in: rect))
        context.stroke(path, with: .color(.cyan.opacity(0.35)), lineWidth: 1)
    }
}
