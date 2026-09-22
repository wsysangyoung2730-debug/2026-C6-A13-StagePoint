import UIKit

enum DemoStage {
    /// A synthetic camera fixture; no simulated detection/accuracy is reported as a real measurement.
    static func image() -> UIImage {
        let size = CGSize(width: 1280, height: 720)
        return UIGraphicsImageRenderer(size: size).image { renderer in
            let ctx = renderer.cgContext
            UIColor(red: 0.05, green: 0.07, blue: 0.08, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            for i in 0..<28 {
                UIColor(white: i % 2 == 0 ? 0.09 : 0.12, alpha: 1).setFill()
                ctx.fill(CGRect(x: i * 46, y: 0, width: 23, height: 265))
            }
            let floor = UIBezierPath()
            floor.move(to: CGPoint(x: 230, y: 265)); floor.addLine(to: CGPoint(x: 1050, y: 265))
            floor.addLine(to: CGPoint(x: 1280, y: 720)); floor.addLine(to: CGPoint(x: 0, y: 720)); floor.close()
            UIColor(red: 0.35, green: 0.28, blue: 0.20, alpha: 1).setFill(); floor.fill()
            ctx.saveGState(); floor.addClip()
            ctx.setStrokeColor(UIColor(white: 0.7, alpha: 0.15).cgColor); ctx.setLineWidth(1)
            for y in stride(from: 285, through: 720, by: 32) {
                ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: 1280, y: y)); ctx.strokePath()
            }
            ctx.restoreGState()
            let boundary = UIBezierPath()
            boundary.move(to: CGPoint(x: 215, y: 620)); boundary.addLine(to: CGPoint(x: 1065, y: 620))
            boundary.addLine(to: CGPoint(x: 945, y: 310)); boundary.addLine(to: CGPoint(x: 335, y: 310)); boundary.close()
            UIColor(white: 0.95, alpha: 0.95).setStroke(); boundary.lineWidth = 7; boundary.stroke()
            for p in [CGPoint(x: 480, y: 480), CGPoint(x: 820, y: 520)] {
                ctx.setStrokeColor(UIColor.white.cgColor); ctx.setLineWidth(4)
                ctx.move(to: CGPoint(x: p.x - 10, y: p.y)); ctx.addLine(to: CGPoint(x: p.x + 10, y: p.y))
                ctx.move(to: CGPoint(x: p.x, y: p.y - 10)); ctx.addLine(to: CGPoint(x: p.x, y: p.y + 10)); ctx.strokePath()
            }
            ("DEMO · 가상 연습실" as NSString).draw(at: CGPoint(x: 36, y: 28), withAttributes: [
                .font: UIFont.systemFont(ofSize: 24, weight: .semibold), .foregroundColor: UIColor.lightGray
            ])
        }
    }
}
