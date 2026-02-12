//
//  ServingUnit.swift
//  Macro Tracker
//

import Foundation

/// Represents a serving unit for food items.
/// For standard units (grams, ounces, cups), gramsPerUnit is a fixed conversion factor.
/// For custom units (e.g., "cookies", "Oreos"), gramsPerUnit is the weight per single item.
enum ServingUnit: Hashable, Identifiable {
    case grams
    case ounces
    case cups
    /// Custom unit with label (e.g., "cookies") and weight per single unit in grams
    case custom(label: String, gramsPerUnit: Double)

    var id: String {
        switch self {
        case .grams: return "g"
        case .ounces: return "oz"
        case .cups: return "cups"
        case .custom(let label, _): return "custom_\(label)"
        }
    }
    
    var displayName: String {
        switch self {
        case .grams: return "g"
        case .ounces: return "oz"
        case .cups: return "cups"
        case .custom(let label, _): return label
        }
    }

    var gramsPerUnit: Double {
        switch self {
        case .grams:  return 1.0
        case .ounces: return 28.3495
        case .cups:   return 240.0
        case .custom(_, let gramsPerUnit): return gramsPerUnit
        }
    }

    func toGrams(_ value: Double) -> Double { value * gramsPerUnit }
    func fromGrams(_ grams: Double) -> Double { grams / gramsPerUnit }
    
    static var standardUnits: [ServingUnit] {
        [.grams, .ounces, .cups]
    }
}
