import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.08, blue: 0.10).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "viewfinder").font(.system(size: 48)).foregroundStyle(.cyan)
                Text("StagePoint").font(.largeTitle.bold())
                Text("무대 포인트 매핑 검증").foregroundStyle(.secondary)
            }
        }
    }
}
