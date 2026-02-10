//
//  MacroGoals.swift
//  Macro Tracker
//

import Foundation
import SwiftData

@Model
final class MacroGoals {
    var userId: String
    var carbs: Double
    var protein: Double
    var fat: Double
    var updatedAt: Date

    init(userId: String, carbs: Double, protein: Double, fat: Double, updatedAt: Date = Date()) {
        self.userId = userId
        self.carbs = carbs
        self.protein = protein
        self.fat = fat
        self.updatedAt = updatedAt
    }
}
