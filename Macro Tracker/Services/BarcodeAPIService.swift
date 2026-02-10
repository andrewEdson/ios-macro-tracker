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
            servingSize: nil
        )
    }

    private func cache(product: BarcodeProduct, modelContext: ModelContext) {
        let food = CachedFood(
            barcode: product.barcode,
            foodName: product.name,
            carbs: product.carbs,
            protein: product.protein,
            fat: product.fat,
            calories: product.calories
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
