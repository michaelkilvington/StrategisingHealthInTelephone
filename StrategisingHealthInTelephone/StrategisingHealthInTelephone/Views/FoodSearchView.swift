import SwiftUI
import SwiftData

struct FoodSearchView: View {
    let mealType: MealType
    let dailyLog: DailyLog
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var searchResults: [FoodItem] = []
    @State private var isSearching = false
    @State private var selectedFood: FoodItem?
    @State private var showingDetail = false
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    TextField("Search food...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: searchFood) {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(searchText.isEmpty || isSearching)
                }
                .padding()
                
                contentView
            }
            .navigationTitle("Add \(mealType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let food = selectedFood {
                    FoodDetailView(food: food, mealType: mealType, dailyLog: dailyLog)
                }
            }
            .onSubmit(of: .text) {
                searchFood()
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isSearching {
            ProgressView("Searching...")
        } else if searchResults.isEmpty && !searchText.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No results found")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(searchResults, id: \.id) { food in
                FoodResultRow(food: food) {
                    selectedFood = food
                    showingDetail = true
                }
            }
        }
    }
    
    func searchFood() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        searchResults = []
        
        Task {
            do {
                let results = try await EdamamService.shared.searchFood(query: searchText)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    print("Search error: \(error)")
                }
            }
        }
    }
}

struct FoodResultRow: View {
    let food: FoodItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let brand = food.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("\(Int(food.calories)) kcal | P: \(Int(food.protein))g C: \(Int(food.carbs))g F: \(Int(food.fat))g")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FoodDetailView: View {
    let food: FoodItem
    let mealType: MealType
    let dailyLog: DailyLog
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var servings: Double = 1.0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Food Information") {
                    Text(food.name)
                        .font(.headline)
                    if let brand = food.brand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Serving") {
                    Stepper("Servings: \(String(format: "%.1f", servings))", value: $servings, in: 0.5...10, step: 0.5)
                    Text("Serving size: \(Int(food.servingSize))\(food.servingUnit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Nutrition per Serving") {
                    NutritionRow(label: "Calories", value: food.calories * servings, unit: "kcal")
                    NutritionRow(label: "Protein", value: food.protein * servings, unit: "g")
                    NutritionRow(label: "Carbohydrates", value: food.carbs * servings, unit: "g")
                    NutritionRow(label: "Fat", value: food.fat * servings, unit: "g")
                    NutritionRow(label: "Fiber", value: food.fiber * servings, unit: "g")
                    NutritionRow(label: "Sugar", value: food.sugar * servings, unit: "g")
                    NutritionRow(label: "Sodium", value: food.sodium * servings, unit: "mg")
                }
                
                Section {
                    Button("Add to \(mealType.rawValue)") {
                        addFoodToMeal()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Food Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func addFoodToMeal() {
        let adjustedFood = FoodItem(
            name: food.name,
            brand: food.brand,
            calories: food.calories * servings,
            protein: food.protein * servings,
            carbs: food.carbs * servings,
            fat: food.fat * servings,
            fiber: food.fiber * servings,
            sugar: food.sugar * servings,
            sodium: food.sodium * servings,
            servingSize: food.servingSize * servings,
            servingUnit: food.servingUnit,
            barcode: food.barcode,
            edamamId: food.edamamId
        )
        
        modelContext.insert(adjustedFood)
        
        if let meal = dailyLog.meals.first(where: { $0.type == mealType }) {
            meal.foodItems.append(adjustedFood)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

struct NutritionRow: View {
    let label: String
    let value: Double
    let unit: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(String(format: "%.1f", value)) \(unit)")
                .foregroundColor(.secondary)
        }
    }
}
