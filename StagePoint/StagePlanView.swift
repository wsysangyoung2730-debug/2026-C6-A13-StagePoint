import SwiftUI
import StagePointCore

struct StagePlanView: View {
    let size: StageSize
    let targets: [StageTarget]
    let selectedID: UUID?
    var onTap: ((Point2D) -> Void)? = nil
    var body: some View {
        GeometryReader { geometry in
            let available = CGSize(width: max(1, geometry.size.width - 40), height: max(1, geometry.size.height - 40))
            let ratio = size.isValid ? size.width / size.depth : 1.5
            let width = min(available.width, available.height * ratio)
            let height = width / ratio
            let rect = CGRect(x: (geometry.size.width - width) / 2, y: (geometry.size.height - height) / 2, width: width, height: height)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.2))
                Canvas { context, _ in
                    context.fill(Path(rect), with: .color(.cyan.opacity(0.055)))
                    context.stroke(Path(rect), with: .color(.white.opacity(0.5)), lineWidth: 1)
                    for i in 1..<6 {
                        var path = Path()
                        path.move(to: CGPoint(x: rect.minX + rect.width * Double(i) / 6, y: rect.minY))
                        path.addLine(to: CGPoint(x: rect.minX + rect.width * Double(i) / 6, y: rect.maxY))
                        context.stroke(path, with: .color(.white.opacity(0.1)), lineWidth: 1)
                    }
                    for i in 1..<4 {
                        var path = Path(); path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * Double(i) / 4))
                        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * Double(i) / 4))
                        context.stroke(path, with: .color(.white.opacity(0.1)), lineWidth: 1)
                    }
                }.allowsHitTesting(false)
                Text("무대 뒤쪽").font(.system(size: 10)).foregroundStyle(.secondary).position(x: rect.midX, y: rect.minY - 10)
                Text("관객 · 앞쪽 A → B").font(.system(size: 10)).foregroundStyle(.secondary).position(x: rect.midX, y: rect.maxY + 11)
                ForEach(targets) { target in
                    ZStack {
                        Circle().fill(target.id == selectedID ? .yellow : .cyan).frame(width: 12, height: 12)
                        Circle().stroke(.yellow.opacity(target.id == selectedID ? 0.4 : 0), lineWidth: 2).frame(width: 22, height: 22)
                        Text(target.name).font(.system(size: 10, weight: .semibold)).offset(y: -19)
                    }.position(x: rect.minX + target.normalized.x * rect.width, y: rect.maxY - target.normalized.y * rect.height)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard rect.contains(location) else { return }
                onTap?(.init(x: (location.x - rect.minX) / rect.width, y: 1 - (location.y - rect.minY) / rect.height))
            }
        }
    }
}
