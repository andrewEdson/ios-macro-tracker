//
//  BarcodeAPIService.swift
//  Macro Tracker
//
//  Calls Open Food Facts to look up nutrition data by barcode,
//  with a local SwiftData cache (CachedFood) to avoid repeat network hits.
//

import Foundation
import SwiftData

/// Result of a successful barcode lookup.
struct BarcodeProduct {
    let barcode: String
    let name: String
    let carbs: Double     // per 100 g
    let protein: Double   // per 100 g
    let fat: Double       // per 100 g
    let calories: Double? // kcal per 100 g
    let servingSize: String? // e.g. "30 g" — nil if API doesn't provide it
}

@MainActor
final class BarcodeAPIService: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public

    /// Look up a barcode. Checks the local cache first; falls back to the network.
    func lookup(barcode: String, modelContext: ModelContext) async -> BarcodeProduct? {
        isLoading = true
        errorMessage = nil

        // 1. Check cache
        if let cached = fetchCached(barcode: barcode, modelContext: modelContext) {
            isLoading = false
            return cached
        }

        // 2. Network request
        let product = await fetchFromAPI(barcode: barcode)

        // 3. Cache the result
        if let product {
            cache(product: product, modelContext: modelContext)
        }

        isLoading = false
        return product
    }

    /// Search Open Food Facts by food name. Returns up to 25 results.
    func searchFood(query: String) async -> [BarcodeProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encoded)&search_simple=1&action=process&json=1&page_size=25") else {
            return []
        }

        isLoading = true
        errorMessage = nil

        var request = URLRequest(url: url)
        request.setValue("MacroTracker iOS App - github.com", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await session.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let products = json?["products"] as? [[String: Any]] else {
                isLoading = false
                return []
            }

            let results: [BarcodeProduct] = products.compactMap { product in
                let name = product["product_name"] as? String ?? ""
                guard !name.isEmpty else { return nil }
                let nutriments = product["nutriments"] as? [String: Any] ?? [:]
                let carbs = nutrimentValue(nutriments, key: "carbohydrates_100g")
                let protein = nutrimentValue(nutriments, key: "proteins_100g")
                let fat = nutrimentValue(nutriments, key: "fat_100g")
                let calories = nutrimentOptional(nutriments, key: "energy-kcal_100g")
                let servingSize = product["serving_size"] as? String
                let code = product["code"] as? String ?? ""
                return BarcodeProduct(
                    barcode: code,
                    name: name,
                    carbs: carbs,
                    protein: protein,
                    fat: fat,
                    calories: calories,
                    servingSize: servingSize
                )
            }

            isLoading = false
            return results
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return []
        }
    }

    // MARK: - Cache

    private func fetchCached(barcode: String, modelContext: ModelContext) -> BarcodeProduct? {
        let descriptor = FetchDescriptor<CachedFood>(
            predicate: #Predicate { $0.barcode == barcode }
        )
        guard let cached = try? modelContext.fetch(descriptor).first else { return nil }
        return BarcodeProduct(
            barcode: cached.barcode,
            name: cached.foodName,
            carbs: cached.carbs,
            protein: cached.protein,
            fat: cached.fat,
            calories: cached.calories,
            servingSize: cached.servingSize
        )
    }

    private func cache(product: BarcodeProduct, modelContext: ModelContext) {
        let food = CachedFood(
            barcode: product.barcode,
            foodName: product.name,
            carbs: product.carbs,
            protein: product.protein,
            fat: product.fat,
            calories: product.calories,
            servingSize: product.servingSize
        )
        modelContext.insert(food)
        try? modelContext.save()
    }

    // MARK: - Open Food Facts API

    private func fetchFromAPI(barcode: String) async -> BarcodeProduct? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else {
            errorMessage = "Invalid barcode."
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("MacroTracker iOS App - github.com", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                errorMessage = "Unexpected response."
                return nil
            }
            guard http.statusCode == 200 else {
                errorMessage = "Product not found (HTTP \(http.statusCode))."
                return nil
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let status = json?["status"] as? Int, status == 1,
                  let product = json?["product"] as? [String: Any] else {
                errorMessage = "Product not found in Open Food Facts."
                return nil
            }

            let nutriments = product["nutriments"] as? [String: Any] ?? [:]

            let name = product["product_name"] as? String ?? "Unknown product"
            let carbs = nutrimentValue(nutriments, key: "carbohydrates_100g")
            let protein = nutrimentValue(nutriments, key: "proteins_100g")
            let fat = nutrimentValue(nutriments, key: "fat_100g")
            let calories = nutrimentOptional(nutriments, key: "energy-kcal_100g")
            let servingSize = product["serving_size"] as? String

            return BarcodeProduct(
                barcode: barcode,
                name: name,
                carbs: carbs,
                protein: protein,
                fat: fat,
                calories: calories,
                servingSize: servingSize
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Helpers

    /// Parse serving size string from API (e.g., "30 g", "2 cookies") into value and unit.
    /// Returns (value, descriptor, gramsPerServing) tuple.
    /// - For weight-based servings (g, oz), gramsPerServing is the total weight
    /// - For item-based servings (cookies, crackers), gramsPerServing equals value (treated as grams)
    static func parseServingSize(_ servingSize: String?) -> (value: Double, descriptor: String, gramsPerServing: Double)? {
        guard let serving = servingSize?.trimmingCharacters(in: .whitespaces), !serving.isEmpty else {
            return nil
        }
        
        // Try to extract number from the beginning
        let numberPattern = "^([0-9]*\\.?[0-9]+)"
        guard let regex = try? NSRegularExpression(pattern: numberPattern),
              let match = regex.firstMatch(in: serving, range: NSRange(serving.startIndex..., in: serving)),
              let range = Range(match.range(at: 1), in: serving),
              let value = Double(String(serving[range])) else {
            return nil
        }
        
        // Extract the rest as descriptor
        var descriptor = serving[serving.index(range.upperBound, offsetBy: 0)...]
            .trimmingCharacters(in: .whitespaces)
        
        // Try to extract grams info from parentheses (e.g., "2 cookies (28g)")
        var gramsFromParens: Double? = nil
        let parensPattern = "\\(([0-9]*\\.?[0-9]+)\\s*g\\)"
        if let parensRegex = try? NSRegularExpression(pattern: parensPattern),
           let parensMatch = parensRegex.firstMatch(in: descriptor, range: NSRange(descriptor.startIndex..., in: descriptor)),
           let gramsRange = Range(parensMatch.range(at: 1), in: descriptor) {
            gramsFromParens = Double(String(descriptor[gramsRange]))
            // Remove the parenthetical part from descriptor
            descriptor = parensRegex.stringByReplacingMatches(
                in: descriptor,
                range: NSRange(descriptor.startIndex..., in: descriptor),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespaces)
        }
        
        // Calculate grams per serving based on the descriptor
        let gramsPerServing: Double
        let lowerDescriptor = descriptor.lowercased()
        
        if lowerDescriptor == "g" || lowerDescriptor == "grams" || lowerDescriptor == "gram" {
            gramsPerServing = value
        } else if lowerDescriptor == "oz" || lowerDescriptor == "ounce" || lowerDescriptor == "ounces" {
            gramsPerServing = value * 28.3495
        } else if lowerDescriptor == "ml" || lowerDescriptor == "milliliter" || lowerDescriptor == "milliliters" {
            gramsPerServing = value  // Approximate 1:1 for liquids
        } else {
            // For custom descriptors (cookies, crackers, etc.)
            // If we found grams in parentheses, use that; otherwise use value as grams
            gramsPerServing = gramsFromParens ?? value
        }
        
        return (value, descriptor.isEmpty ? "g" : descriptor, gramsPerServing)
    }

    /// Open Food Facts sometimes returns numbers as Int, Double, or String.
    private func nutrimentValue(_ dict: [String: Any], key: String) -> Double {
        nutrimentOptional(dict, key: key) ?? 0
    }

    private func nutrimentOptional(_ dict: [String: Any], key: String) -> Double? {
        if let d = dict[key] as? Double { return d }
        if let i = dict[key] as? Int { return Double(i) }
        if let s = dict[key] as? String, let d = Double(s) { return d }
        return nil
    }
}
