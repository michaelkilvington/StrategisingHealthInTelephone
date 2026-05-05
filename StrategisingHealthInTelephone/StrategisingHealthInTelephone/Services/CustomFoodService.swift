import Foundation
import CloudKit
import UIKit

class CustomFoodService {
    static let shared = CustomFoodService()
    
    private let container = CKContainer(identifier: "iCloud.com.michaelkilvington.StrategisingHealthInTelephone")
    private var publicDB: CKDatabase { container.publicCloudDatabase }
    
    private init() {}
    
    // MARK: - Search
    
    func searchFoods(query: String) async throws -> [FoodSearchResult] {
        print("🔍 CustomFoodService searching for: '\(query)'")
        
        //Always search lowercase — single query, no variants needed
        let predicate = NSPredicate(format: "nameLower BEGINSWITH %@", query.lowercased())
        let ckQuery = CKQuery(recordType: "CustomFood", predicate: predicate)
        ckQuery.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let result = try await publicDB.records(matching: ckQuery, resultsLimit: 25)
            print("CloudKit returned \(result.matchResults.count) records")
            
            let results: [FoodSearchResult] = result.matchResults.compactMap { (_, recordResult) -> FoodSearchResult? in
                switch recordResult {
                case .success(let record):
                    print("Record: \(record["name"] as? String ?? "unnamed")")
                    return foodSearchResult(from: record)
                case .failure(let error):
                    print("Record fetch failed: \(error)")
                    return nil
                }
            }
            
            print("CustomFoodService returning \(results.count) results")
            return results
        } catch {
            print("CloudKit query failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Submit
    
    func submitFood(_ food: CustomFoodSubmission) async throws {
        let record = CKRecord(recordType: "CustomFood")
        record["name"] = food.name as NSString
        record["nameLower"] = food.name.lowercased() as NSString
        record["brand"] = (food.brand.isEmpty ? "" : food.brand) as NSString
        record["calories"] = food.calories as NSNumber
        record["protein"] = food.protein as NSNumber
        record["carbs"] = food.carbs as NSNumber
        record["fat"] = food.fat as NSNumber
        record["fiber"] = food.fiber as NSNumber
        record["sugar"] = food.sugar as NSNumber
        record["sodium"] = food.sodium as NSNumber
        record["servingSize"] = food.servingSize as NSNumber
        record["servingUnit"] = food.servingUnit as NSString
        record["barcode"] = (food.barcode ?? "") as NSString
        record["submittedBy"] = food.submittedBy as NSString
        record["createdAt"] = Date() as NSDate
        
        do {
            let saved = try await publicDB.save(record)
            print("✅ CustomFood saved successfully: \(saved.recordID)")
        } catch {
            print("❌ CustomFood save failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Barcode Lookup
    
    func lookupBarcode(_ barcode: String) async throws -> FoodSearchResult? {
        let predicate = NSPredicate(format: "barcode == %@", barcode)
        let ckQuery = CKQuery(recordType: "CustomFood", predicate: predicate)
        
        let result = try await publicDB.records(matching: ckQuery, resultsLimit: 1)
        
        let results: [FoodSearchResult] = result.matchResults.compactMap { (_, recordResult) -> FoodSearchResult? in
            guard case .success(let record) = recordResult else { return nil }
            return foodSearchResult(from: record)
        }
        return results.first
    }
    
    // MARK: - Private
    
    private func foodSearchResult(from record: CKRecord) -> FoodSearchResult? {
        guard let name = record["name"] as? String, !name.isEmpty else { return nil }
        
        let brand = record["brand"] as? String
        
        return FoodSearchResult(
            name: name,
            brand: brand?.isEmpty == true ? nil : brand,
            calories: record["calories"] as? Double ?? 0,
            protein: record["protein"] as? Double ?? 0,
            carbs: record["carbs"] as? Double ?? 0,
            fat: record["fat"] as? Double ?? 0,
            fiber: record["fiber"] as? Double ?? 0,
            sugar: record["sugar"] as? Double ?? 0,
            sodium: record["sodium"] as? Double ?? 0,
            servingSize: record["servingSize"] as? Double ?? 100,
            servingUnit: record["servingUnit"] as? String ?? "g",
            barcode: record["barcode"] as? String,
            offId: nil
        )
    }
}

// MARK: - Submission model

struct CustomFoodSubmission {
    var name: String = ""
    var brand: String = ""
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0
    var sugar: Double = 0
    var sodium: Double = 0
    var servingSize: Double = 100
    var servingUnit: String = "g"
    var barcode: String? = nil
    var submittedBy: String = UIDevice.current.name
}
