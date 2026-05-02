import Foundation
import CloudKit
import SwiftData

class CloudKitService {
    static let shared = CloudKitService()
    private let container = CKContainer.default()
    private let database: CKDatabase
    
    private init() {
        self.database = container.privateCloudDatabase
    }
    
    func saveUserProfile(_ profile: UserProfile) async throws {
        let record = CKRecord(recordType: "UserProfile")
        record["name"] = profile.name as NSString
        record["gender"] = profile.gender.rawValue as NSString
        record["birthDate"] = profile.birthDate as NSDate
        record["height"] = profile.height as NSNumber
        record["currentWeight"] = profile.currentWeight as NSNumber
        record["goalWeight"] = profile.goalWeight as NSNumber
        record["weeklyWeightLossGoal"] = profile.weeklyWeightLossGoal as NSNumber
        record["activityLevel"] = profile.activityLevel.rawValue as NSString
        record["dailyCalorieTarget"] = profile.dailyCalorieTarget as NSNumber
        
        try await database.save(record)
    }
    
    func saveWeightLog(_ weightLog: WeightLog) async throws {
        let record = CKRecord(recordType: "WeightLog")
        record["date"] = weightLog.date as NSDate
        record["weight"] = weightLog.weight as NSNumber
        
        try await database.save(record)
    }
    
    func saveDailyLog(_ dailyLog: DailyLog) async throws {
        let record = CKRecord(recordType: "DailyLog")
        record["date"] = dailyLog.date as NSDate
        record["isCompleted"] = dailyLog.isCompleted as NSNumber
        if let completionDate = dailyLog.completionDate {
            record["completionDate"] = completionDate as NSDate
        }
        
        try await database.save(record)
    }
    
    func fetchWeightLogs() async throws -> [WeightLog] {
        let query = CKQuery(recordType: "WeightLog", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        let result = try await database.records(matching: query)
        return result.matchResults.compactMap { _, result in
            if case .success(let record) = result {
                let date = record["date"] as? Date ?? Date()
                let weight = record["weight"] as? Double ?? 0.0
                return WeightLog(date: date, weight: weight)
            }
            return nil
        }
    }
    
    func fetchDailyLogs() async throws -> [DailyLog] {
        let query = CKQuery(recordType: "DailyLog", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        let result = try await database.records(matching: query)
        return result.matchResults.compactMap { _, result in
            if case .success(let record) = result {
                let date = record["date"] as? Date ?? Date()
                let isCompleted = record["isCompleted"] as? Bool ?? false
                return DailyLog(date: date, isCompleted: isCompleted)
            }
            return nil
        }
    }
    
    func checkiCloudStatus() async -> Bool {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                return true
            default:
                return false
            }
        } catch {
            return false
        }
    }
    
    func syncAllData(modelContext: ModelContext) async {
        do {
            let iCloudAvailable = await checkiCloudStatus()
            guard iCloudAvailable else { return }
            
            let weightLogs = try await fetchWeightLogs()
            for log in weightLogs {
                let logDate = log.date
                let descriptor = FetchDescriptor<WeightLog>(
                    predicate: #Predicate { $0.date == logDate }
                )
                if (try? modelContext.fetch(descriptor).isEmpty) ?? true {
                    modelContext.insert(log)
                }
            }
            
            try? modelContext.save()
        } catch {
            print("Sync error: \(error)")
        }
    }
}
