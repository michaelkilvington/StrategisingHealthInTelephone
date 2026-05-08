import SwiftUI
import SwiftData

struct FoodSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let brand: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let sodium: Double
    let servingSize: Double
    let servingUnit: String
    let barcode: String?
    let offId: String?
}

struct FoodSearchView: View {
    let mealType: MealType
    let dailyLog: DailyLog
    let onFoodAdded: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var searchResults: [FoodSearchResult] = []
    @State private var isSearching = false
    @State private var showingAddCustomFood = false

    @State private var detailFood: FoodSearchResult?
    @State private var errorMessage: String?
    @State private var showingBarcodeScanner = false
    @State private var isBarcodeSearching = false
    
    @Query(sort: \FoodItem.dateAdded, order: .reverse) private var allFoodItems: [FoodItem]

    var recentFoodItems: [FoodItem] {
        var seen = Set<String>()
        return allFoodItems.filter { seen.insert($0.name).inserted }.prefix(10).map { $0 }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search food...", text: $searchText)
                            .onSubmit { searchFood() }
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchResults = []
                                errorMessage = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                    
                    Button(action: searchFood) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundColor(searchText.isEmpty || isSearching ? .gray : .blue)
                    }
                    .disabled(searchText.isEmpty || isSearching)
                    
                    Button(action: { showingBarcodeScanner = true }) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                
                foodSearchResultsView
            }
            .navigationTitle("Add \(mealType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingAddCustomFood = true }) {
                        Image(systemName: "plus.square")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $detailFood) { food in
                FoodDetailView(
                    food: food,
                    mealType: mealType,
                    dailyLog: dailyLog,
                    onFoodAdded: {
                        dismiss()
                        onFoodAdded()
                    }
                )
            }
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView { barcode in
                    showingBarcodeScanner = false
                    handleBarcodeScan(barcode)
                }
            }
            .sheet(isPresented: $showingAddCustomFood) {
                AddCustomFoodView()
            }
        }
    }
    
    @ViewBuilder
    private var foodSearchResultsView: some View {
        if isSearching || isBarcodeSearching {
            VStack(spacing: 16) {
                Spacer()
                SwiftUI.ProgressView()
                    .scaleEffect(1.2)
                Text(isBarcodeSearching ? "Looking up barcode..." : "Searching...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else if let error = errorMessage {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button(action: {
                    errorMessage = nil
                    searchResults = []
                }) {
                    Text("Try Again")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(20)
                }
                Spacer()
            }
        } else if !searchResults.isEmpty {
            List(searchResults, id: \.id) { food in
                FoodResultRow(food: food) {
                    detailFood = food
                }
            }
            .listStyle(.plain)
        } else if !searchText.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 56))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("No results for")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\"\(searchText)\"")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Try a different search term or scan a barcode")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
        } else {
            VStack(spacing: 0) {
                if !recentFoodItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text("Recently Logged")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        List(recentFoodItems, id: \.id) { food in
                            FoodResultRow(food: FoodSearchResult(from: food)) {
                                detailFood = FoodSearchResult(from: food)
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: "magnifyingglass.circle")
                            .font(.system(size: 64))
                            .foregroundColor(.blue.opacity(0.3))
                        VStack(spacing: 8) {
                            Text("Find your food")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("Search by name or scan a barcode\nto add food to \(mealType.rawValue)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        HStack(spacing: 10) {
                            TipPill(icon: "text.magnifyingglass", text: "Search by name")
                            TipPill(icon: "barcode.viewfinder", text: "Scan barcode")
                        }
                        Spacer()
                    }
                }
            }
        }
    }
    
    func searchFood() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        searchResults = []
        errorMessage = nil
        
        Task {
            do {
                async let offResults = OpenFoodFactsService.shared.searchFood(query: searchText)
                async let customResults = CustomFoodService.shared.searchFoods(query: searchText)
                
                // ✅ Await separately so we can log each independently
                let custom = try await customResults
                let off = try await offResults
                
                print("🔵 OFF results: \(off.count)")
                print("🟢 Custom DB results: \(custom.count)")
                custom.forEach { print("   Custom: \($0.name)") }
                
                await MainActor.run {
                    var seen = Set<String>()
                    var merged: [FoodSearchResult] = []
                    
                    for food in custom + off.map({ FoodSearchResult(from: $0) }) {
                        if seen.insert(food.name.lowercased()).inserted {
                            merged.append(food)
                        }
                    }
                    
                    print("🟡 Merged total: \(merged.count)")
                    
                    searchResults = merged
                    isSearching = false
                    
                    if searchResults.isEmpty {
                        errorMessage = "No results found for \"\(searchText)\""
                    }
                }
            } catch {
                print("❌ Search error: \(error)")
                await MainActor.run {
                    isSearching = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func handleBarcodeScan(_ barcode: String) {
        isBarcodeSearching = true
        errorMessage = nil
        
        Task {
            do {
                // ✅ Check custom DB first, then fall back to OFF
                let customResult = try? await CustomFoodService.shared.lookupBarcode(barcode)
                
                if let result = customResult {
                    await MainActor.run {
                        isBarcodeSearching = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            detailFood = result
                        }
                    }
                    return
                }
                
                // Fall back to Open Food Facts
                if let foodItem = try await OpenFoodFactsService.shared.lookupBarcode(barcode) {
                    let result = FoodSearchResult(from: foodItem)
                    await MainActor.run {
                        isBarcodeSearching = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            detailFood = result
                        }
                    }
                } else {
                    await MainActor.run {
                        isBarcodeSearching = false
                        errorMessage = "No food found for this barcode."
                    }
                }
            } catch {
                await MainActor.run {
                    isBarcodeSearching = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func addFoodToMeal(_ food: FoodSearchResult, servings: Double) {
        let newFood = FoodItem(
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
            offId: food.offId
        )
        newFood.servings = servings
        modelContext.insert(newFood)
        
        if let meal = (dailyLog.meals ?? []).first(where: { $0.type == mealType }) {
            if meal.foodItems == nil {
                meal.foodItems = [newFood]
            } else {
                meal.foodItems?.append(newFood)
            }
        }
        
        try? modelContext.save()
        dismiss()
        onFoodAdded()
    }
}

struct TipPill: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .cornerRadius(20)
        .foregroundColor(.secondary)
    }
}

struct FoodResultRow: View {
    let food: FoodSearchResult
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
    let food: FoodSearchResult
    let mealType: MealType
    let dailyLog: DailyLog
    let onFoodAdded: () -> Void
    var existingItem: FoodItem? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var servings: Double = 1.0
    @FocusState private var servingsFocused: Bool
    
    private var adjustedCalories: Double { food.calories * servings }
    private var adjustedProtein: Double { food.protein * servings }
    private var adjustedCarbs: Double { food.carbs * servings }
    private var adjustedFat: Double { food.fat * servings }
    private var adjustedFiber: Double { food.fiber * servings }
    private var adjustedSugar: Double { food.sugar * servings }
    private var adjustedSodium: Double { food.sodium * servings }
    
    var isEditing: Bool { existingItem != nil }
    
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
                    HStack {
                        Text("Servings")
                        Spacer()
                        TextField("1.0", value: $servings, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($servingsFocused)
                    }
                    Text("Serving size: \(String(format: "%.1f", food.servingSize * servings))\(food.servingUnit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Nutrition per Serving") {
                    NutritionRow(label: "Calories", value: adjustedCalories, unit: "kcal")
                    NutritionRow(label: "Protein", value: adjustedProtein, unit: "g")
                    NutritionRow(label: "Carbohydrates", value: adjustedCarbs, unit: "g")
                    NutritionRow(label: "Fat", value: adjustedFat, unit: "g")
                    NutritionRow(label: "Fiber", value: adjustedFiber, unit: "g")
                    NutritionRow(label: "Sugar", value: adjustedSugar, unit: "g")
                    NutritionRow(label: "Sodium", value: adjustedSodium, unit: "mg")
                }
            }
            .navigationTitle(isEditing ? "Edit Food" : "Food Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(role: .destructive, action: removeFoodItem) {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isEditing ? updateFoodItem() : addFoodToMeal()
                    }) {
                        Text(isEditing ? "Update" : "Add")
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        servingsFocused = false
                    }
                }
            }
            .onAppear {
                if let existing = existingItem {
                    servings = existing.servings > 0 ? existing.servings : 1.0
                }
            }
        }
    }
    
    func addFoodToMeal() {
        let newFood = FoodItem(
            name: food.name,
            brand: food.brand,
            calories: adjustedCalories,
            protein: adjustedProtein,
            carbs: adjustedCarbs,
            fat: adjustedFat,
            fiber: adjustedFiber,
            sugar: adjustedSugar,
            sodium: adjustedSodium,
            servingSize: food.servingSize * servings,
            servingUnit: food.servingUnit,
            barcode: food.barcode,
            offId: food.offId
        )
        newFood.servings = servings
        modelContext.insert(newFood)
        if let meal = (dailyLog.meals ?? []).first(where: { $0.type == mealType }) {
            if meal.foodItems == nil {
                meal.foodItems = [newFood]
            } else {
                meal.foodItems?.append(newFood)
            }
        }
        try? modelContext.save()
        dismiss()
        onFoodAdded()
    }
    
    func updateFoodItem() {
        guard let existing = existingItem else { return }
        existing.calories = adjustedCalories
        existing.protein = adjustedProtein
        existing.carbs = adjustedCarbs
        existing.fat = adjustedFat
        existing.fiber = adjustedFiber
        existing.sugar = adjustedSugar
        existing.sodium = adjustedSodium
        existing.servingSize = food.servingSize * servings
        existing.servings = servings
        try? modelContext.save()
        dismiss()
    }
    
    func removeFoodItem() {
        guard let existing = existingItem else { return }
        modelContext.delete(existing)
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

extension FoodSearchResult {
    init(from item: FoodItem) {
        self.init(
            name: item.name,
            brand: item.brand,
            calories: item.calories,
            protein: item.protein,
            carbs: item.carbs,
            fat: item.fat,
            fiber: item.fiber,
            sugar: item.sugar,
            sodium: item.sodium,
            servingSize: item.servingSize,
            servingUnit: item.servingUnit,
            barcode: item.barcode,
            offId: item.offId
        )
    }
}
