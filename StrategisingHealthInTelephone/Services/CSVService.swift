import Foundation
import SwiftData

class CSVService {
    static let shared = CSVService()
    
    private init() {}
    
    func exportDailyLogs(modelContext: ModelContext) -> URL? {
        let descriptor = FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\DailyLog.date, order: .forward)])
        guard let logs = try? modelContext.fetch(descriptor) else { return nil }
        
        var csvString = "Date,Breakfast Calories,Lunch Calories,Dinner Calories,Snacks Calories,Total Calories,Protein (g),Carbs (g),Fat (g),Completed\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for log in logs {
            let dateStr = dateFormatter.string(from: log.date)
            let breakfastCal = log.meals.first { $0.type == .breakfast }?.totalCalories ?? 0
            let lunchCal = log.meals.first { $0.type == .lunch }?.totalCalories ?? 0
            let dinnerCal = log.meals.first { $0.type == .dinner }?.totalCalories ?? 0
            let snacksCal = log.meals.first { $0.type == .snacks }?.totalCalories ?? 0
            
            csvString += "\(dateStr),\(Int(breakfastCal)),\(Int(lunchCal)),\(Int(dinnerCal)),\(Int(snacksCal)),\(Int(log.totalCalories)),\(String(format: "%.1f", log.totalProtein)),\(String(format: "%.1f", log.totalCarbs)),\(String(format: "%.1f", log.totalFat)),\(log.isCompleted)\n"
        }
        
        return saveToTemporaryFile(content: csvString, filename: "daily_logs_export.csv")
    }
    
    func exportWeightLogs(modelContext: ModelContext) -> URL? {
        let descriptor = FetchDescriptor<WeightLog>(sortBy: [SortDescriptor(\WeightLog.date, order: .forward)])
        guard let logs = try? modelContext.fetch(descriptor) else { return nil }
        
        var csvString = "Date,Weight (kg)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for log in logs {
            let dateStr = dateFormatter.string(from: log.date)
            csvString += "\(dateStr),\(String(format: "%.1f", log.weight))\n"
        }
        
        return saveToTemporaryFile(content: csvString, filename: "weight_logs_export.csv")
    }
    
    func exportAllData(modelContext: ModelContext) -> URL? {
        let descriptor = FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\DailyLog.date, order: .forward)])
        guard let logs = try? modelContext.fetch(descriptor) else { return nil }
        
        var csvString = "Date,Meal Type,Food Name,Brand,Calories,Protein (g),Carbs (g),Fat (g),Fiber (g),Sugar (g),Sodium (mg),Serving Size (g)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for log in logs {
            for meal in log.meals {
                for food in meal.foodItems {
                    let dateStr = dateFormatter.string(from: log.date)
                    let brand = food.brand ?? ""
                    csvString += "\(dateStr),\(meal.type.rawValue),\"\(food.name)\",\"\(brand)\",\(Int(food.calories)),\(String(format: "%.1f", food.protein)),\(String(format: "%.1f", food.carbs)),\(String(format: "%.1f", food.fat)),\(String(format: "%.1f", food.fiber)),\(String(format: "%.1f", food.sugar)),\(String(format: "%.1f", food.sodium)),\(Int(food.servingSize))\n"
                }
            }
        }
        
        return saveToTemporaryFile(content: csvString, filename: "complete_nutrition_export.csv")
    }
    
    func importMyFitnessPalWeightCSV(url: URL, modelContext: ModelContext) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            guard lines.count > 1 else { return }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for line in lines.dropFirst() where !line.isEmpty {
                let columns = parseCSVLine(line)
                guard columns.count >= 2,
                      let date = dateFormatter.date(from: columns[0]),
                      let weight = Double(columns[1]) else { continue }
                
                let weightLog = WeightLog(date: date, weight: weight)
                modelContext.insert(weightLog)
            }
            
            try? modelContext.save()
        } catch {
            print("CSV import error: \(error)")
        }
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current.trimmingCharacters(in: .whitespaces))
        
        return result
    }
    
    private func saveToTemporaryFile(content: String, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving CSV: \(error)")
            return nil
        }
    }
}
