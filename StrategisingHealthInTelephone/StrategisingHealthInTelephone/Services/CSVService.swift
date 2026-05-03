import Foundation
import SwiftData

class CSVService {
    static let shared = CSVService()
    private init() {}
    
    // MARK: - Export
    
    func exportDailyLogs(modelContext: ModelContext) -> URL? {
        let descriptor = FetchDescriptor<DailyLog>(
            sortBy: [SortDescriptor(\DailyLog.date, order: .forward)]
        )
        guard let logs = try? modelContext.fetch(descriptor) else { return nil }
        
        var csv = "Date,Total Calories,Total Protein (g),Total Carbs (g),Total Fat (g),Completed\n"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        for log in logs {
            csv += "\(formatter.string(from: log.date)),"
            csv += "\(String(format: "%.1f", log.totalCalories)),"
            csv += "\(String(format: "%.1f", log.totalProtein)),"
            csv += "\(String(format: "%.1f", log.totalCarbs)),"
            csv += "\(String(format: "%.1f", log.totalFat)),"
            csv += "\(log.isCompleted ? "Yes" : "No")\n"
        }
        
        return writeToTemp(csv, filename: "daily_logs.csv")
    }
    
    func exportWeightLogs(modelContext: ModelContext) -> URL? {
        let descriptor = FetchDescriptor<WeightLog>(
            sortBy: [SortDescriptor(\WeightLog.date, order: .forward)]
        )
        guard let logs = try? modelContext.fetch(descriptor) else { return nil }
        
        var csv = "Date,Weight (kg)\n"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        for log in logs {
            csv += "\(formatter.string(from: log.date)),"
            csv += "\(String(format: "%.1f", log.weight))\n"
        }
        
        return writeToTemp(csv, filename: "weight_logs.csv")
    }
    
    func exportAllData(modelContext: ModelContext) -> URL? {
        let dailyDescriptor = FetchDescriptor<DailyLog>(
            sortBy: [SortDescriptor(\DailyLog.date, order: .forward)]
        )
        let weightDescriptor = FetchDescriptor<WeightLog>(
            sortBy: [SortDescriptor(\WeightLog.date, order: .forward)]
        )
        
        guard let dailyLogs = try? modelContext.fetch(dailyDescriptor),
              let weightLogs = try? modelContext.fetch(weightDescriptor) else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        var csv = "=== DAILY LOGS ===\n"
        csv += "Date,Total Calories,Total Protein (g),Total Carbs (g),Total Fat (g),Completed\n"
        for log in dailyLogs {
            csv += "\(formatter.string(from: log.date)),"
            csv += "\(String(format: "%.1f", log.totalCalories)),"
            csv += "\(String(format: "%.1f", log.totalProtein)),"
            csv += "\(String(format: "%.1f", log.totalCarbs)),"
            csv += "\(String(format: "%.1f", log.totalFat)),"
            csv += "\(log.isCompleted ? "Yes" : "No")\n"
        }
        
        csv += "\n=== WEIGHT LOGS ===\n"
        csv += "Date,Weight (kg)\n"
        for log in weightLogs {
            csv += "\(formatter.string(from: log.date)),"
            csv += "\(String(format: "%.1f", log.weight))\n"
        }
        
        return writeToTemp(csv, filename: "all_data.csv")
    }
    
    // MARK: - CSV Import
    
    func importMyFitnessPalWeightCSV(url: URL, modelContext: ModelContext) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return }
        
        let formatter = DateFormatter()
        let dateFormats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy"]
        
        for line in lines.dropFirst() {
            let columns = line.components(separatedBy: ",")
            guard columns.count >= 2 else { continue }
            
            let dateString = columns[0].trimmingCharacters(in: .whitespaces)
            let weightString = columns[1].trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: " lb", with: "")
                .replacingOccurrences(of: " kg", with: "")
            
            guard let weight = Double(weightString) else { continue }
            
            var parsedDate: Date?
            for format in dateFormats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) {
                    parsedDate = date
                    break
                }
            }
            
            guard let date = parsedDate else { continue }
            
            let checkDate = date
            let descriptor = FetchDescriptor<WeightLog>(
                predicate: #Predicate { $0.date == checkDate }
            )
            if (try? modelContext.fetch(descriptor).isEmpty) ?? true {
                modelContext.insert(WeightLog(date: date, weight: weight))
            }
        }
        
        try? modelContext.save()
    }
    
    // MARK: - JSON Import
    
    // ✅ startYear is now passed in from the UI instead of hardcoded
    func importMyFitnessPalWeightJSON(url: URL, modelContext: ModelContext, startYear: Int) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode(MFPWeightExport.self, from: data) else {
            print("Failed to parse MFP JSON")
            return
        }
        
        let allResults = json.outcome.results
        guard !allResults.isEmpty else { return }
        
        var inferredYear = startYear
        var lastMonth: Int? = nil
        let calendar = Calendar.current
        var lastImportedWeight: Double? = nil
        
        for entry in allResults {
            let parts = entry.date.components(separatedBy: "/")
            guard parts.count == 2,
                  let month = Int(parts[0]),
                  let day = Int(parts[1]) else { continue }
            
            // ✅ Increment year at each 12→1 boundary
            if let last = lastMonth, month < last {
                inferredYear += 1
            }
            lastMonth = month
            
            // ✅ Skip zero entries — no weigh-in recorded
            guard entry.total > 0 else { continue }
            
            // ✅ Skip forward-filled duplicates — only import on weight change
            if entry.total == lastImportedWeight { continue }
            lastImportedWeight = entry.total
            
            // ✅ Build date from components — reliable and locale-independent
            var components = DateComponents()
            components.year = inferredYear
            components.month = month
            components.day = day
            components.hour = 0
            components.minute = 0
            components.second = 0
            
            guard let date = calendar.date(from: components) else { continue }
            
            // ✅ Skip future dates
            guard date <= Date() else { continue }
            
            // ✅ Skip duplicates already in the database
            let startOfDay = calendar.startOfDay(for: date)
            let descriptor = FetchDescriptor<WeightLog>(
                predicate: #Predicate { $0.date == startOfDay }
            )
            if (try? modelContext.fetch(descriptor).isEmpty) ?? true {
                modelContext.insert(WeightLog(date: startOfDay, weight: entry.total))
            }
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Private
    
    private func writeToTemp(_ content: String, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("CSV write error: \(error)")
            return nil
        }
    }
}

// MARK: - MFP JSON Models

private struct MFPWeightExport: Codable {
    let outcome: MFPOutcome
}

private struct MFPOutcome: Codable {
    let results: [MFPWeightEntry]
}

private struct MFPWeightEntry: Codable {
    let date: String
    let total: Double
}
