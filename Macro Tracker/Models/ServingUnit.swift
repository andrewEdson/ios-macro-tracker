//
//  ServingUnit.swift
//  Macro Tracker
//

import Foundation

enum ServingUnit: String, CaseIterable, Identifiable {
    case grams = "g"
    case ounces = "oz"
    case cups = "cups"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var gramsPerUnit: Double {
        switch self {
        case .grams:  return 1.0
        case .ounces: return 28.3495
        case .cups:   return 240.0
        }
    }

    func toGrams(_ value: Double) -> Double { value * gramsPerUnit }
    func fromGrams(_ grams: Double) -> Double { grams / gramsPerUnit }
}
