//
//  AppTheme.swift
//  StrategisingHealthInTelephone
//
//  Created by Michael Kilvington on 4/5/2026.
//
import SwiftUI
internal import Combine

class AppTheme: ObservableObject {
    static let shared = AppTheme()
    
    @Published var useGradientBackground: Bool {
        didSet {
            UserDefaults.standard.set(useGradientBackground, forKey: "useGradientBackground")
        }
    }
    
    private init() {
        self.useGradientBackground = UserDefaults.standard.bool(forKey: "useGradientBackground")
    }
    
    // ✅ The diagonal gradient from #62d431 to #b474e8
    // 25% down left side to 75% down right side
    static let diaryGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: "62d431"), location: 0.0),
            .init(color: Color(hex: "b474e8"), location: 1.0)
        ],
        startPoint: UnitPoint(x: 0, y: 0.25),  // 25% down left side
        endPoint: UnitPoint(x: 1, y: 0.75)      // 75% down right side
    )
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
