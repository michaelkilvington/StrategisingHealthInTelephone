import SwiftUI
import SwiftData

struct DailyDiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var allDailyLogs: [DailyLog]
    
    @State private var selectedMealType: MealType?
    @State private var showingFoodSearch = false
    @State private var showingBarcodeScanner = false
    @State private var showingCompletionAlert = false
    @State private var projectedWeightLoss: Double = 0
    
    var todaysLogs: [DailyLog] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return allDailyLogs.filter { $0.date >= startOfDay && $0.date < endOfDay }
    }
    
    var currentLog: DailyLog {
        if let existing = todaysLogs.first {
            return existing
        }
        let newLog = DailyLog(date: Date())
        for mealType in MealType.allCases {
            newLog.meals.append(Meal(type: mealType, date: Date()))
        }
        modelContext.insert(newLog)
        try? modelContext.save()
        return newLog
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    calorieProgressSection
                    
                    macroProgressSection
                    
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        MealSectionView(
                            mealType: mealType,
                            meal: currentLog.meals.first { $0.type == mealType },
                            onAddFood: {
                                selectedMealType = mealType
                                showingFoodSearch = true
                            }
                        )
                    }
                    
                    if !currentLog.isCompleted {
                        completeDiaryButton
                    } else {
                        Text("Diary Completed")
                            .foregroundColor(.green)
                            .font(.headline)
                    }
                }
                .padding()
            }
            .navigationTitle("Today's Diary")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingBarcodeScanner = true
                    }) {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $showingFoodSearch) {
                if let mealType = selectedMealType {
                    FoodSearchView(mealType: mealType, dailyLog: currentLog)
                }
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView { barcode in
                    handleBarcodeScan(barcode)
                }
            }
            .alert("5-Week Projection", isPresented: $showingCompletionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("If you maintain this calorie intake daily for 5 weeks, you will lose approximately \(String(format: "%.1f", projectedWeightLoss)) kg")
            }
        }
    }
    
    var calorieProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Calories")
                    .font(.headline)
                Spacer()
                if let profile = profiles.first {
                    Text("\(Int(currentLog.totalCalories)) / \(Int(profile.dailyCalorieTarget)) kcal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            SwiftUI.ProgressView(value: currentLog.totalCalories, total: profiles.first?.dailyCalorieTarget ?? 2000)
                .progressViewStyle(LinearProgressViewStyle())
                .tint(currentLog.totalCalories > (profiles.first?.dailyCalorieTarget ?? 2000) ? .red : .green)
            
            if let profile = profiles.first {
                Text("\(Int(profile.dailyCalorieTarget - currentLog.totalCalories)) kcal remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    var macroProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macronutrients")
                .font(.headline)
            
            if let profile = profiles.first {
                MacroProgressRow(name: "Protein", current: currentLog.totalProtein, target: profile.proteinTarget, color: .blue)
                MacroProgressRow(name: "Carbs", current: currentLog.totalCarbs, target: profile.carbsTarget, color: .orange)
                MacroProgressRow(name: "Fat", current: currentLog.totalFat, target: profile.fatTarget, color: .red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    var completeDiaryButton: some View {
        Button(action: completeDiary) {
            Text("Complete Diary & See Projection")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
        }
    }
    
    func completeDiary() {
        currentLog.isCompleted = true
        currentLog.completionDate = Date()
        
        if let profile = profiles.first {
            projectedWeightLoss = currentLog.projectedWeightLoss(
                currentWeight: profile.currentWeight,
                targetCalories: profile.dailyCalorieTarget
            )
        }
        
        try? modelContext.save()
        showingCompletionAlert = true
    }
    
    func handleBarcodeScan(_ barcode: String) {
        Task {
            do {
                if let foodItem = try await EdamamService.shared.lookupBarcode(barcode) {
                    modelContext.insert(foodItem)
                }
            } catch {
                print("Barcode lookup failed: \(error)")
            }
        }
    }
}

struct MacroProgressRow: View {
    let name: String
    let current: Double
    let target: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(current))g / \(Int(target))g")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            SwiftUI.ProgressView(value: min(current, target), total: target)
                .progressViewStyle(LinearProgressViewStyle())
                .tint(color)
        }
    }
}

struct MealSectionView: View {
    let mealType: MealType
    let meal: Meal?
    let onAddFood: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mealType.rawValue)
                    .font(.headline)
                Spacer()
                if let meal = meal {
                    Text("\(Int(meal.totalCalories)) kcal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Button(action: onAddFood) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            if let meal = meal, !meal.foodItems.isEmpty {
                ForEach(meal.foodItems, id: \.id) { food in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(food.name)
                                .font(.subheadline)
                            Text("\(Int(food.calories)) kcal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("No items added")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
