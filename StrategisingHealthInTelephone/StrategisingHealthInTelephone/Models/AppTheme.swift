import SwiftUI
internal import Combine

@MainActor
class AppTheme: ObservableObject {
    static let shared = AppTheme()
    
    @Published var useGradientBackground: Bool {
        didSet {
            UserDefaults.standard.set(useGradientBackground, forKey: "useGradientBackground")
        }
    }
    
    private init() {
        if UserDefaults.standard.object(forKey: "useGradientBackground") == nil {
            self.useGradientBackground = true
        } else {
            self.useGradientBackground = UserDefaults.standard.bool(forKey: "useGradientBackground")
        }
    }
    
    // MARK: - Gradient
    
    static let diaryGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: "b474e8"), location: 0.0),
            .init(color: Color(hex: "62d431"), location: 1.0)
        ],
        startPoint: UnitPoint(x: 0, y: 0.75),
        endPoint: UnitPoint(x: 1, y: 0.25)
    )
    
    // MARK: - Adaptive Colors
    
    var primaryText: Color {
        .white
    }
    
    var secondaryText: Color {
        useGradientBackground ? Color.white.opacity(0.7) : Color.gray
    }
    
    var accent: Color {
        useGradientBackground ? .white : .blue
    }
    
    var destructive: Color {
        useGradientBackground ? .red.opacity(0.9) : .red
    }
    
    var colorScheme: ColorScheme {
        useGradientBackground ? .dark : .light
    }
    
    // MARK: - Glass / Material
    
    var cardMaterial: Material {
        useGradientBackground ? .ultraThinMaterial : .regularMaterial
    }
    
    var cardStroke: Color {
        useGradientBackground
            ? Color.white.opacity(0.25)
            : Color.black.opacity(0.1)
    }
    
    var glassButtonMaterial: Material {
        .thinMaterial
    }
    
    var shadowColor: Color {
        useGradientBackground
            ? Color.black.opacity(0.25)
            : Color.black.opacity(0.1)
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    @EnvironmentObject var appTheme: AppTheme
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(appTheme.cardMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(appTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: appTheme.shadowColor, radius: 10, y: 4)
    }
}

// MARK: - Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        
        self.init(red: r, green: g, blue: b)
    }
}
