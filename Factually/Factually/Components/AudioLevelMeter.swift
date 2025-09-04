import SwiftUI

/// A reusable audio level meter component that displays a horizontal bar
struct AudioLevelMeter: View {
    let audioLevel: Float
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(audioLevel: Float, height: CGFloat = 20, cornerRadius: CGFloat = 10) {
        self.audioLevel = audioLevel
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background bar
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: height)
                
                // Active level bar
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(levelColor)
                    .frame(
                        width: max(0, CGFloat(audioLevel) * geometry.size.width),
                        height: height
                    )
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
        }
        .frame(height: height)
    }
    
    private var levelColor: Color {
        switch audioLevel {
        case 0.0..<0.3:
            return .green
        case 0.3..<0.7:
            return .yellow
        case 0.7...1.0:
            return .red
        default:
            return .green
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Audio Level Meter Examples")
            .foregroundColor(.white)
            .font(.title2)
        
        VStack(spacing: 12) {
            HStack {
                Text("Low:")
                    .foregroundColor(.white)
                AudioLevelMeter(audioLevel: 0.2)
            }
            
            HStack {
                Text("Medium:")
                    .foregroundColor(.white)
                AudioLevelMeter(audioLevel: 0.5)
            }
            
            HStack {
                Text("High:")
                    .foregroundColor(.white)
                AudioLevelMeter(audioLevel: 0.8)
            }
            
            HStack {
                Text("Max:")
                    .foregroundColor(.white)
                AudioLevelMeter(audioLevel: 1.0)
            }
        }
        .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
