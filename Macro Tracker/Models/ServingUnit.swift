//
//  ServingUnit.swift
//  Macro Tracker
//

import Foundation

enum ServingUnit: Equatable, Identifiable {
    case grams
    case ounces
    case cups
    case custom(label: String, gramsPerServing: Double)

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
        case .custom(_, let gramsPerServing): return gramsPerServing
        }
    }

    func toGrams(_ value: Double) -> Double { value * gramsPerUnit }
    func fromGrams(_ grams: Double) -> Double { grams / gramsPerUnit }
    
    static var standardUnits: [ServingUnit] {
        [.grams, .ounces, .cups]
    }
}
