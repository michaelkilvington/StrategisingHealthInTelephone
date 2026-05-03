import Foundation
import SwiftData

enum MealType: String, CaseIterable, Codable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snacks = "Snacks"
}

enum Sex: String, CaseIterable, Codable {
    case male = "Male"
    case female = "Female"
}

enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary = "Sedentary"
    case light = "Lightly Active"
    case moderate = "Moderately Active"
    case active = "Very Active"
    case extraActive = "Extra Active"
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .extraActive: return 1.9
        }
    }
}

@Model
final class FoodItem {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String? = nil
    var calories: Double = 0.0
    var protein: Double = 0.0
    var carbs: Double = 0.0
    var fat: Double = 0.0
    var fiber: Double = 0.0
    var sugar: Double = 0.0
    var sodium: Double = 0.0
    var servingSize: Double = 100.0
    var servingUnit: String = "g"
    var barcode: String? = nil
    var offId: String? = nil
    var dateAdded: Date = Date()
    
    var meal: Meal? = nil
    
    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double = 0,
        sugar: Double = 0,
        sodium: Double = 0,
        servingSize: Double = 100,
        servingUnit: String = "g",
        barcode: String? = nil,
        offId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.barcode = barcode
        self.offId = offId
        self.dateAdded = Date()
    }
}

@Model
final class Meal {
    var id: UUID = UUID()
    var type: MealType = MealType.breakfast
    var date: Date = Date()
    
    @Relationship(deleteRule: .cascade, inverse: \FoodItem.meal)
    var foodItems: [FoodItem]? = []
    
    var dailyLog: DailyLog? = nil
    
    init(
        id: UUID = UUID(),
        type: MealType,
        foodItems: [FoodItem] = [],
        date: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.foodItems = foodItems
        self.date = date
    }
    
    var totalCalories: Double {
        (foodItems ?? []).reduce(0) { $0 + $1.calories }
    }
    
    var totalProtein: Double {
        (foodItems ?? []).reduce(0) { $0 + $1.protein }
    }
    
    var totalCarbs: Double {
        (foodItems ?? []).reduce(0) { $0 + $1.carbs }
    }
    
    var totalFat: Double {
        (foodItems ?? []).reduce(0) { $0 + $1.fat }
    }
}

@Model
final class DailyLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var isCompleted: Bool = false
    var completionDate: Date? = nil
    
    @Relationship(deleteRule: .cascade, inverse: \Meal.dailyLog)
    var meals: [Meal]? = []
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        meals: [Meal] = [],
        isCompleted: Bool = false
    ) {
        self.id = id
        self.date = date
        self.meals = meals
        self.isCompleted = isCompleted
    }
    
    var totalCalories: Double {
        (meals ?? []).reduce(0) { $0 + $1.totalCalories }
    }
    
    var totalProtein: Double {
        (meals ?? []).reduce(0) { $0 + $1.totalProtein }
    }
    
    var totalCarbs: Double {
        (meals ?? []).reduce(0) { $0 + $1.totalCarbs }
    }
    
    var totalFat: Double {
        (meals ?? []).reduce(0) { $0 + $1.totalFat }
    }
    
    func projectedWeightLoss(currentWeight: Double, targetCalories: Double) -> Double {
        let bmr = UserProfile.calculateBMR(weight: currentWeight, height: 170, age: 30, sex: .male)
        let dailyDeficit = bmr - totalCalories
        let weeklyDeficit = dailyDeficit * 7
        let caloriesPerKg = 7700.0
        return (weeklyDeficit / caloriesPerKg) * 5
    }
}

@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var sex: Sex = Sex.male
    var birthDate: Date = Date()
    var height: Double = 170.0
    var currentWeight: Double = 70.0
    var goalWeight: Double = 65.0
    var weeklyWeightLossGoal: Double = 0.5
    var activityLevel: ActivityLevel = ActivityLevel.moderate
    var dailyCalorieTarget: Double = 2000.0
    var proteinTarget: Double = 150.0
    var carbsTarget: Double = 250.0
    var fatTarget: Double = 65.0
    
    init(
        id: UUID = UUID(),
        name: String = "",
        sex: Sex = .male,
        birthDate: Date = Date(),
        height: Double = 170,
        currentWeight: Double = 70,
        goalWeight: Double = 65,
        weeklyWeightLossGoal: Double = 0.5,
        activityLevel: ActivityLevel = .moderate,
        dailyCalorieTarget: Double = 2000,
        proteinTarget: Double = 150,
        carbsTarget: Double = 250,
        fatTarget: Double = 65
    ) {
        self.id = id
        self.name = name
        self.sex = sex
        self.birthDate = birthDate
        self.height = height
        self.currentWeight = currentWeight
        self.goalWeight = goalWeight
        self.weeklyWeightLossGoal = weeklyWeightLossGoal
        self.activityLevel = activityLevel
        self.dailyCalorieTarget = dailyCalorieTarget
        self.proteinTarget = proteinTarget
        self.carbsTarget = carbsTarget
        self.fatTarget = fatTarget
    }
    
    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
    }
    
    static func calculateBMR(weight: Double, height: Double, age: Int, sex: Sex) -> Double {
        switch sex {
        case .male:
            return 10 * weight + 6.25 * height - 5 * Double(age) + 5
        case .female:
            return 10 * weight + 6.25 * height - 5 * Double(age) - 161
        }
    }
    
    func calculateTDEE() -> Double {
        let bmr = UserProfile.calculateBMR(weight: currentWeight, height: height, age: age, sex: sex)
        return bmr * activityLevel.multiplier
    }
    
    func calculateDailyCalorieTarget() -> Double {
        let tdee = calculateTDEE()
        let caloriesPerKg = 7700.0
        let dailyDeficit = (weeklyWeightLossGoal * caloriesPerKg) / 7
        return max(1200, tdee - dailyDeficit)
    }
    
    func calculateMacroTargets() -> (protein: Double, carbs: Double, fat: Double) {
        let calories = dailyCalorieTarget
        let protein = (calories * 0.3) / 4
        let carbs = (calories * 0.4) / 4
        let fat = (calories * 0.3) / 9
        return (protein, carbs, fat)
    }
}

@Model
final class WeightLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var weight: Double = 0.0
    var photo: Data? = nil
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        weight: Double,
        photo: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.photo = photo
    }
}
