//
//  LogEntry.swift
//  Macro Tracker
//

import Foundation
import SwiftData

enum MealType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack

    var displayName: String {
        rawValue.capitalized
    }
}

@Model
final class LogEntry {
    var id: UUID
    var userId: String
    var date: Date
    var mealType: String
    var foodName: String
    var carbs: Double
    var protein: Double
    var fat: Double
    var calories: Double?
    var barcode: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        date: Date,
        mealType: MealType,
        foodName: String,
        carbs: Double,
        protein: Double,
        fat: Double,
        calories: Double? = nil,
        barcode: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.mealType = mealType.rawValue
        self.foodName = foodName
        self.carbs = carbs
        self.protein = protein
        self.fat = fat
        self.calories = calories
        self.barcode = barcode
        self.createdAt = createdAt
    }

    var mealTypeEnum: MealType {
        get { MealType(rawValue: mealType) ?? .snack }
        set { mealType = newValue.rawValue }
    }
}
