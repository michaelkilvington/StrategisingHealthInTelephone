import Foundation

struct EdamamConfig {
    static var appId: String {
        Bundle.main.object(forInfoDictionaryKey: "EDAMAM_APP_ID") as? String ?? ""
    }
    static var appKey: String {
        Bundle.main.object(forInfoDictionaryKey: "EDAMAM_APP_KEY") as? String ?? ""
    }
}

class EdamamService {
    static let shared = EdamamService()
    
    private let baseURL = "https://api.edamam.com/api/food-database/v2"
    
    private init() {}
    
    func searchFood(query: String) async throws -> [FoodItem] {
        guard !EdamamConfig.appId.isEmpty, !EdamamConfig.appKey.isEmpty else {
            throw EdamamError.notConfigured
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/parser?app_id=\(EdamamConfig.appId)&app_key=\(EdamamConfig.appKey)&ingr=\(encodedQuery)&nutrition-type=logging"
        
        guard let url = URL(string: urlString) else {
            throw EdamamError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EdamamError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200: break
        case 401: throw EdamamError.unauthorized
        case 429: throw EdamamError.rateLimited
        default: throw EdamamError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(EdamamSearchResponse.self, from: data)
        
        return result.hints.compactMap { hint in
            let food = hint.food
            let nutrients = food.nutrients
            
            return FoodItem(
                name: food.label,
                brand: food.brand,
                calories: nutrients.ENERC_KCAL ?? 0,
                protein: nutrients.PROCNT ?? 0,
                carbs: nutrients.CHOCDF ?? 0,
                fat: nutrients.FAT ?? 0,
                fiber: nutrients.FIBTG ?? 0,
                sugar: nutrients.SUGAR ?? 0,
                sodium: nutrients.NA ?? 0,
                servingSize: hint.measures.first?.weight ?? 100,
                servingUnit: "g",
                barcode: nil,
                offId: food.foodId
            )
        }
    }
    
    func lookupBarcode(_ barcode: String) async throws -> FoodItem? {
        guard !EdamamConfig.appId.isEmpty, !EdamamConfig.appKey.isEmpty else {
            throw EdamamError.notConfigured
        }
        
        // ✅ Log the barcode being sent so we can verify the format
        print("Looking up barcode: '\(barcode)'")
        
        let urlString = "\(baseURL)/parser?app_id=\(EdamamConfig.appId)&app_key=\(EdamamConfig.appKey)&upc=\(barcode)&nutrition-type=logging"
        print("Request URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw EdamamError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EdamamError.invalidResponse
        }
        
        // ✅ Log the actual status code and raw response body
        print("Barcode lookup status: \(httpResponse.statusCode)")
        print("Response body: \(String(data: data, encoding: .utf8) ?? "unreadable")")
        
        switch httpResponse.statusCode {
        case 200: break
        case 401: throw EdamamError.unauthorized
        case 429: throw EdamamError.rateLimited
        default: throw EdamamError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(EdamamSearchResponse.self, from: data)
        
        guard let firstHint = result.hints.first else {
            throw EdamamError.noResults
        }
        
        let food = firstHint.food
        let nutrients = food.nutrients
        
        return FoodItem(
            name: food.label,
            brand: food.brand,
            calories: nutrients.ENERC_KCAL ?? 0,
            protein: nutrients.PROCNT ?? 0,
            carbs: nutrients.CHOCDF ?? 0,
            fat: nutrients.FAT ?? 0,
            fiber: nutrients.FIBTG ?? 0,
            sugar: nutrients.SUGAR ?? 0,
            sodium: nutrients.NA ?? 0,
            servingSize: firstHint.measures.first?.weight ?? 100,
            servingUnit: "g",
            barcode: barcode,
            offId: food.foodId
        )
    }
}

enum EdamamError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Edamam API keys not configured. Go to Settings to add them."
        case .invalidURL: return "Invalid request URL."
        case .invalidResponse: return "Unexpected response from Edamam."
        case .unauthorized: return "Invalid Edamam API credentials. Check your App ID and App Key in Settings."
        case .rateLimited: return "Edamam API rate limit reached. Please wait a moment and try again."
        case .noResults: return "No food found for this barcode."
        }
    }
}

struct EdamamSearchResponse: Codable {
    let hints: [Hint]
}

struct Hint: Codable {
    let food: EdamamFood
    let measures: [EdamamMeasure]
}

struct EdamamFood: Codable {
    let foodId: String
    let label: String
    let brand: String?
    let nutrients: EdamamNutrients
    let category: String?
}

struct EdamamNutrients: Codable {
    let ENERC_KCAL: Double?
    let PROCNT: Double?
    let CHOCDF: Double?
    let FAT: Double?
    let FIBTG: Double?
    let SUGAR: Double?
    let NA: Double?
}

struct EdamamMeasure: Codable {
    let label: String
    let weight: Double
    let qualified: [EdamamQualified]?
}

struct EdamamQualified: Codable {
    let qualifiers: [EdamamQualifier]
    let weight: Double
}

struct EdamamQualifier: Codable {
    let label: String
}
