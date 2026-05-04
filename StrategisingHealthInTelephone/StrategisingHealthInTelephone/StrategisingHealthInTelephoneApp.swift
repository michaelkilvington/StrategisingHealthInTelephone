//
//  StrategisingHealthInTelephoneApp.swift
//  StrategisingHealthInTelephone
//
//  Created by Michael Kilvington on 2/5/2026.
//

import SwiftUI
import SwiftData

@main
struct StrategisingHealthInTelephoneApp: App {
    @StateObject private var appTheme = AppTheme.shared
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FoodItem.self,
            Meal.self,
            DailyLog.self,
            UserProfile.self,
            WeightLog.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .environmentObject(appTheme)
        }
    }
}
