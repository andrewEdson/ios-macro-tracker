//
//  CachedFood.swift
//  Macro Tracker
//

import Foundation
import SwiftData

@Model
final class CachedFood {
    var barcode: String
    var foodName: String
    var carbs: Double
    var protein: Double
    var fat: Double
    var calories: Double?
    var cachedAt: Date
    var servingSize: String?  // e.g., "30 g", "2 cookies"

    init(
        barcode: String,
        foodName: String,
        carbs: Double,
        protein: Double,
        fat: Double,
        calories: Double? = nil,
        cachedAt: Date = Date(),
        servingSize: String? = nil
    ) {
        self.barcode = barcode
        self.foodName = foodName
        self.carbs = carbs
        self.protein = protein
        self.fat = fat
        self.calories = calories
        self.cachedAt = cachedAt
        self.servingSize = servingSize
    }
}
