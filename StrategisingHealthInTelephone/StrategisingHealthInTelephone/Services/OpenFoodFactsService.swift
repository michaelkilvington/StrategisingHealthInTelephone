//
//  OpenFoodFactsService.swift
//  StrategisingHealthInTelephone
//
//  Created by Michael Kilvington on 3/5/2026.
//
import Foundation

class OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    
    private let baseURL = "https://world.openfoodfacts.org"
    // Required by OFF to identify your app
    private let userAgent = "StrategisingHealthInTelephone/1.0 (mkilvington@me.com)"
    
    private init() {}
    
    // MARK: - Text Search
    
    func searchFood(query: String) async throws -> [FoodItem] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "https://search.openfoodfacts.org/search?q=\(encoded)&page_size=25&fields=product_name,brands,nutriments,serving_size,code"
        
        guard let url = URL(string: urlString) else {
            throw OFFError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OFFError.invalidResponse
        }
        
        print("Search status: \(httpResponse.statusCode)")
        print("Response body: \(String(data: data, encoding: .utf8)?.prefix(500) ?? "unreadable")")
        
        switch httpResponse.statusCode {
        case 200: break
        case 429: throw OFFError.rateLimited
        case 503: throw OFFError.serverUnavailable
        default: throw OFFError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(OFFSearchALiciousResponse.self, from: data)
        
        return result.hits.compactMap { product in
            guard let name = product.productName, !name.isEmpty else { return nil }
            return foodItem(from: product, barcode: product.code)
        }
    }
    
    // MARK: - Barcode Lookup
    
    func lookupBarcode(_ barcode: String) async throws -> FoodItem? {
        let urlString = "\(baseURL)/api/v2/product/\(barcode).json?fields=product_name,brands,nutriments,serving_size,code"
        
        guard let url = URL(string: urlString) else {
            throw OFFError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OFFError.invalidResponse
        }
        
        print("Barcode status: \(httpResponse.statusCode)")
            print("Barcode response: \(String(data: data, encoding: .utf8)?.prefix(1000) ?? "unreadable")")
            
        
        switch httpResponse.statusCode {
        case 200: break
        case 429: throw OFFError.rateLimited
        default: throw OFFError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        
        // ✅ status 0 means not found, 1 means found
        guard result.status == 1, let product = result.product else {
            throw OFFError.noResults
        }
        
        return foodItem(from: product, barcode: barcode)
    }
    
    // MARK: - Shared mapping
    
    private func foodItem(from product: OFFProduct, barcode: String?) -> FoodItem {

        let nutriments = product.nutriments ?? OFFNutriments.empty
        let name = product.productName ?? "Unknown Product"
        let brand = product.brands?.joined(separator: ", ")
        
        let servingSize = parseServingSize(product.servingSize)
        let useServing = servingSize > 0
        
        let calories = useServing
            ? (nutriments.energyKcalServing ?? nutriments.energyKcal100g ?? 0)
            : (nutriments.energyKcal100g ?? 0)
        let protein = useServing
            ? (nutriments.proteinsServing ?? nutriments.proteins100g ?? 0)
            : (nutriments.proteins100g ?? 0)
        let carbs = useServing
            ? (nutriments.carbohydratesServing ?? nutriments.carbohydrates100g ?? 0)
            : (nutriments.carbohydrates100g ?? 0)
        let fat = useServing
            ? (nutriments.fatServing ?? nutriments.fat100g ?? 0)
            : (nutriments.fat100g ?? 0)
        let fiber = useServing
            ? (nutriments.fiberServing ?? nutriments.fiber100g ?? 0)
            : (nutriments.fiber100g ?? 0)
        let sugar = useServing
            ? (nutriments.sugarsServing ?? nutriments.sugars100g ?? 0)
            : (nutriments.sugars100g ?? 0)
        let sodiumG = useServing
            ? (nutriments.sodiumServing ?? nutriments.sodium100g ?? 0)
            : (nutriments.sodium100g ?? 0)
        
        return FoodItem(
            name: name,
            brand: brand,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sugar: sugar,
            sodium: sodiumG * 1000,
            servingSize: useServing ? servingSize : 100,
            servingUnit: useServing ? "serving" : "g",
            barcode: barcode,
            offId: nil
        )
    }
    
    private func parseServingSize(_ servingString: String?) -> Double {
        guard let str = servingString else { return 0 }
        // Extract first number from strings like "30g", "1 cup (240ml)", "250 mL"
        let digits = str.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .joined()
        return Double(digits) ?? 0
    }
}

// MARK: - Errors

enum OFFError: LocalizedError {
    case invalidURL
    case invalidResponse
    case rateLimited
    case noResults
    case serverUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "Invalid request URL."
        case .invalidResponse:  return "Unexpected response from Open Food Facts."
        case .rateLimited:      return "Too many requests. Please wait a moment and try again."
        case .noResults:        return "No food found for this barcode."
        case .serverUnavailable: return "The server is currently unavailable."
        }
    }
}

// MARK: - Response Models

private struct OFFSearchALiciousResponse: Codable {
    let hits: [OFFProduct]
}

private struct OFFProductResponse: Codable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFProduct: Codable {
    let code: String?
    let productName: String?
    let brands: [String]?
    let nutriments: OFFNutriments?
    let servingSize: String?
    
    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case nutriments
        case servingSize = "serving_size"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        productName = try container.decodeIfPresent(String.self, forKey: .productName)
        nutriments = try container.decodeIfPresent(OFFNutriments.self, forKey: .nutriments)
        servingSize = try container.decodeIfPresent(String.self, forKey: .servingSize)
        

        if let brandsArray = try? container.decodeIfPresent([String].self, forKey: .brands) {
            brands = brandsArray
        } else if let brandsString = try? container.decodeIfPresent(String.self, forKey: .brands) {
            brands = brandsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            brands = nil
        }
    }
}

private struct OFFNutriments: Codable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let sugars100g: Double?
    let sodium100g: Double?
    let energyKcalServing: Double?
    let proteinsServing: Double?
    let carbohydratesServing: Double?
    let fatServing: Double?
    let fiberServing: Double?
    let sugarsServing: Double?
    let sodiumServing: Double?
    
    static let empty = OFFNutriments(
        energyKcal100g: nil, proteins100g: nil, carbohydrates100g: nil,
        fat100g: nil, fiber100g: nil, sugars100g: nil, sodium100g: nil,
        energyKcalServing: nil, proteinsServing: nil, carbohydratesServing: nil,
        fatServing: nil, fiberServing: nil, sugarsServing: nil, sodiumServing: nil
    )
    
    enum CodingKeys: String, CodingKey {
        case energyKcal100g         = "energy-kcal_100g"
        case proteins100g           = "proteins_100g"
        case carbohydrates100g      = "carbohydrates_100g"
        case fat100g                = "fat_100g"
        case fiber100g              = "fiber_100g"
        case sugars100g             = "sugars_100g"
        case sodium100g             = "sodium_100g"
        case energyKcalServing      = "energy-kcal_serving"
        case proteinsServing        = "proteins_serving"
        case carbohydratesServing   = "carbohydrates_serving"
        case fatServing             = "fat_serving"
        case fiberServing           = "fiber_serving"
        case sugarsServing          = "sugars_serving"
        case sodiumServing          = "sodium_serving"
    }
}
