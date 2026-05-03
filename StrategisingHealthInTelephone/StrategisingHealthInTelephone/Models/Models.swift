import Foundation
import SwiftData

enum MealType: String, CaseIterable, Codable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snacks = "Snacks"
}

enum Gender: String, CaseIterable, Codable {
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
    var id: UUID
    var name: String
    var brand: String?
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var sodium: Double
    var servingSize: Double
    var servingUnit: String
    var barcode: String?
    var edamamId: String?
    var dateAdded: Date
    
    init(id: UUID = UUID(), name: String, brand: String? = nil, calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double = 0, sugar: Double = 0, sodium: Double = 0, servingSize: Double = 100, servingUnit: String = "g", barcode: String? = nil, edamamId: String? = nil) {
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
        self.edamamId = edamamId
        self.dateAdded = Date()
    }
}

@Model
final class Meal {
    var id: UUID
    var type: MealType
    var foodItems: [FoodItem]
    var date: Date
    
    init(id: UUID = UUID(), type: MealType, foodItems: [FoodItem] = [], date: Date = Date()) {
        self.id = id
        self.type = type
        self.foodItems = foodItems
        self.date = date
    }
    
    var totalCalories: Double {
        foodItems.reduce(0) { $0 + $1.calories }
    }
    
    var totalProtein: Double {
        foodItems.reduce(0) { $0 + $1.protein }
    }
    
    var totalCarbs: Double {
        foodItems.reduce(0) { $0 + $1.carbs }
    }
    
    var totalFat: Double {
        foodItems.reduce(0) { $0 + $1.fat }
    }
}

@Model
final class DailyLog {
    var id: UUID
    var date: Date
    var meals: [Meal]
    var isCompleted: Bool
    var completionDate: Date?
    
    init(id: UUID = UUID(), date: Date = Date(), meals: [Meal] = [], isCompleted: Bool = false) {
        self.id = id
        self.date = date
        self.meals = meals
        self.isCompleted = isCompleted
    }
    
    var totalCalories: Double {
        meals.reduce(0) { $0 + $1.totalCalories }
    }
    
    var totalProtein: Double {
        meals.reduce(0) { $0 + $1.totalProtein }
    }
    
    var totalCarbs: Double {
        meals.reduce(0) { $0 + $1.totalCarbs }
    }
    
    var totalFat: Double {
        meals.reduce(0) { $0 + $1.totalFat }
    }
    
    func projectedWeightLoss(currentWeight: Double, targetCalories: Double) -> Double {
        let bmr = UserProfile.calculateBMR(weight: currentWeight, height: 170, age: 30, gender: .male)
        let dailyDeficit = bmr - totalCalories
        let weeklyDeficit = dailyDeficit * 7
        let caloriesPerKg = 7700.0
        return (weeklyDeficit / caloriesPerKg) * 5
    }
}

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var gender: Gender
    var birthDate: Date
    var height: Double
    var currentWeight: Double
    var goalWeight: Double
    var weeklyWeightLossGoal: Double
    var activityLevel: ActivityLevel
    var dailyCalorieTarget: Double
    var proteinTarget: Double
    var carbsTarget: Double
    var fatTarget: Double
    
    init(id: UUID = UUID(), name: String = "", gender: Gender = .male, birthDate: Date = Date(), height: Double = 170, currentWeight: Double = 70, goalWeight: Double = 65, weeklyWeightLossGoal: Double = 0.5, activityLevel: ActivityLevel = .moderate, dailyCalorieTarget: Double = 2000, proteinTarget: Double = 150, carbsTarget: Double = 250, fatTarget: Double = 65) {
        self.id = id
        self.name = name
        self.gender = gender
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
    
    static func calculateBMR(weight: Double, height: Double, age: Int, gender: Gender) -> Double {
        switch gender {
        case .male:
            return 10 * weight + 6.25 * height - 5 * Double(age) + 5
        case .female:
            return 10 * weight + 6.25 * height - 5 * Double(age) - 161
        }
    }
    
    func calculateTDEE() -> Double {
        let bmr = UserProfile.calculateBMR(weight: currentWeight, height: height, age: age, gender: gender)
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
    var id: UUID
    var date: Date
    var weight: Double
    var photo: Data?  // ✅ Added for progress photo support
    
    init(id: UUID = UUID(), date: Date = Date(), weight: Double, photo: Data? = nil) {
        self.id = id
        self.date = date
        self.weight = weight
        self.photo = photo
    }
}
