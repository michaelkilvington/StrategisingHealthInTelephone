import SwiftUI
import SwiftData

struct DailyDiaryView: View {
    @EnvironmentObject var appTheme: AppTheme
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var allDailyLogs: [DailyLog]
    
    @State private var foodSearchConfig: FoodSearchConfig?
    @State private var showingCompletionAlert = false
    @State private var projectedWeightLoss: Double = 0
    @State private var dailyLog: DailyLog?
    @State private var selectedDate: Date = Date()
    @State private var showingDatePicker = false
    
    var todaysLogs: [DailyLog] {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return allDailyLogs.filter { $0.date >= startOfDay && $0.date < endOfDay }
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    var navigationTitle: String {
        if isToday { return "Today's Diary" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: selectedDate)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if appTheme.useGradientBackground {
                    AppTheme.diaryGradient
                        .ignoresSafeArea()
                } else {
                    Color.black
                        .ignoresSafeArea()
                }
                
                List {
                    Section {
                        dateNavigationBar
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    
                    if let log = dailyLog {
                        Section {
                            calorieProgressSection(log: log)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        
                        Section {
                            macroProgressSection(log: log)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        
                        ForEach(MealType.allCases, id: \.self) { mealType in
                            let meal = (log.meals ?? []).first { $0.type == mealType }
                            Section {
                                HStack {
                                    Text(mealType.rawValue)
                                        .font(.headline)
                                    Spacer()
                                    if let meal = meal {
                                        Text("\(Int(meal.totalCalories)) kcal")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Button(action: {
                                        foodSearchConfig = FoodSearchConfig(
                                            mealType: mealType,
                                            dailyLog: log
                                        )
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                if let meal = meal, !(meal.foodItems ?? []).isEmpty {
                                    ForEach(meal.foodItems ?? [], id: \.id) { food in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(food.name)
                                                    .font(.subheadline)
                                                Text("\(Int(food.calories)) kcal")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                deleteFoodItem(food)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                } else {
                                    Text("No items added")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .listRowBackground(
                                appTheme.useGradientBackground
                                    ? Color.white.opacity(0.15)
                                    : Color.white.opacity(0.08)
                            )
                        }
                        
                        Section {
                            Button(action: { showProjection(log: log) }) {
                                Text("See 5-Week Projection")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 10, leading: 5, bottom: 10, trailing: 5))
                            .listRowBackground(Color.clear)
                        }
                        
                    } else {
                        Section {
                            SwiftUI.ProgressView("Loading...")
                                .frame(maxWidth: .infinity)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(navigationTitle)
            .onAppear { setupDailyLog() }
            .onChange(of: allDailyLogs) {
                if dailyLog == nil { setupDailyLog() }
            }
            .onChange(of: selectedDate) {
                dailyLog = nil
                setupDailyLog()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingDatePicker.toggle() }) {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(selectedDate: $selectedDate)
            }
            .sheet(item: $foodSearchConfig) { config in
                FoodSearchView(
                    mealType: config.mealType,
                    dailyLog: config.dailyLog,
                    onFoodAdded: { foodSearchConfig = nil }
                )
            }
            .alert("Calorie Projection", isPresented: $showingCompletionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("If you maintain this calorie intake daily for 5 weeks, you will lose approximately \(String(format: "%.1f", projectedWeightLoss)) kg")
            }
        }
    }
    
    var dateNavigationBar: some View {
        HStack {
            Button(action: {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.blue)
            }
            Spacer()
            Button(action: { showingDatePicker.toggle() }) {
                Text(isToday ? "Today" : navigationTitle)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            Spacer()
            Button(action: {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(isToday ? .gray : .blue)
            }
            .disabled(isToday)
        }
        .padding(.vertical, 4)
    }
    
    func setupDailyLog() {
        if let existing = todaysLogs.first {
            let existingMeals = existing.meals ?? []
            for mealType in MealType.allCases {
                if !existingMeals.contains(where: { $0.type == mealType }) {
                    if existing.meals == nil {
                        existing.meals = [Meal(type: mealType, date: selectedDate)]
                    } else {
                        existing.meals?.append(Meal(type: mealType, date: selectedDate))
                    }
                }
            }
            dailyLog = existing
        } else {
            let newLog = DailyLog(date: Calendar.current.startOfDay(for: selectedDate))
            for mealType in MealType.allCases {
                if newLog.meals == nil {
                    newLog.meals = [Meal(type: mealType, date: selectedDate)]
                } else {
                    newLog.meals?.append(Meal(type: mealType, date: selectedDate))
                }
            }
            modelContext.insert(newLog)
            dailyLog = newLog
        }
        try? modelContext.save()
    }
    
    func showProjection(log: DailyLog) {
        if let profile = profiles.first {
            projectedWeightLoss = log.projectedWeightLoss(
                currentWeight: profile.currentWeight,
                targetCalories: profile.dailyCalorieTarget
            )
        }
        showingCompletionAlert = true
    }
    
    func deleteFoodItem(_ food: FoodItem) {
        modelContext.delete(food)
        try? modelContext.save()
    }
    
    func calorieProgressSection(log: DailyLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Calories")
                    .font(.headline)
                Spacer()
                if let profile = profiles.first {
                    Text("\(Int(log.totalCalories)) / \(Int(profile.dailyCalorieTarget)) kcal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            SwiftUI.ProgressView(value: log.totalCalories, total: profiles.first?.dailyCalorieTarget ?? 2000)
                .progressViewStyle(LinearProgressViewStyle())
                .tint(log.totalCalories > (profiles.first?.dailyCalorieTarget ?? 2000) ? .red : .green)
            if let profile = profiles.first {
                Text("\(Int(profile.dailyCalorieTarget - log.totalCalories)) kcal remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            appTheme.useGradientBackground
                ? Color.white.opacity(0.15)
                : Color.white.opacity(0.08)
        )
        .cornerRadius(10)
    }
    
    func macroProgressSection(log: DailyLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macronutrients")
                .font(.headline)
            if let profile = profiles.first {
                MacroProgressRow(name: "Protein", current: log.totalProtein, target: profile.proteinTarget, color: .blue)
                MacroProgressRow(name: "Carbs", current: log.totalCarbs, target: profile.carbsTarget, color: .orange)
                MacroProgressRow(name: "Fat", current: log.totalFat, target: profile.fatTarget, color: .red)
            }
        }
        .padding()
        .background(
            appTheme.useGradientBackground
                ? Color.white.opacity(0.15)
                : Color.white.opacity(0.08)
        )
        .cornerRadius(10)
    }
}

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
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

struct FoodSearchConfig: Identifiable {
    let id = UUID()
    let mealType: MealType
    let dailyLog: DailyLog
}
