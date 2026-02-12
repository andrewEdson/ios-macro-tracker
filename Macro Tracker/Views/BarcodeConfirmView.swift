//
//  BarcodeConfirmView.swift
//  Macro Tracker
//
//  Shown after a barcode scan + API lookup. Displays the product name and
//  macros (pre-filled from Open Food Facts) and lets the user edit values,
//  pick a meal type, and save as a log entry.
//

import SwiftUI
import SwiftData

struct BarcodeConfirmView: View {
    let product: BarcodeProduct

    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var foodName: String = ""
    @State private var carbsStr: String = ""
    @State private var proteinStr: String = ""
    @State private var fatStr: String = ""
    @State private var selectedMeal: MealType = .breakfast
    @State private var selectedDate = Date()
    @State private var servingSize: String = "100"
    @State private var servingUnit: ServingUnit = .grams
    @State private var previousUnit: ServingUnit = .grams
    @State private var availableUnits: [ServingUnit] = ServingUnit.standardUnits
    @State private var saved = false

    private var userId: String? { authService.userId }

    private var calculatedCalories: Int {
        let c = Double(carbsStr) ?? 0
        let p = Double(proteinStr) ?? 0
        let f = Double(fatStr) ?? 0
        return Int((c * 4) + (p * 4) + (f * 9))
    }

    // MARK: - Computed serving values

    /// Factor to scale per-100g values to the entered serving size.
    private var servingFactor: Double {
        guard let value = Double(servingSize), value > 0 else { return 1 }
        return servingUnit.toGrams(value) / 100.0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Name", text: $foodName)

                    ServingSizeRow(
                        servingSize: $servingSize,
                        servingUnit: $servingUnit,
                        availableUnits: availableUnits
                    )
                        .onChange(of: servingSize) { _ in
                            recalculate()
                        }
                        .onChange(of: servingUnit) { _ in
                            if let value = Double(servingSize), value > 0 {
                                let grams = previousUnit.toGrams(value)
                                let converted = servingUnit.fromGrams(grams)
                                servingSize = formatted(converted)
                            }
                            previousUnit = servingUnit
                            recalculate()
                        }

                    if let info = product.servingSize {
                        Text("Label serving: \(info)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Macros") {
                    macroRow(label: "Carbs (g)", text: $carbsStr)
                    macroRow(label: "Protein (g)", text: $proteinStr)
                    macroRow(label: "Fat (g)", text: $fatStr)
                    HStack {
                        Text("Calories")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(calculatedCalories) kcal")
                            .foregroundColor(.secondary)
                    }
                }

                Section("When") {
                    Picker("Meal", selection: $selectedMeal) {
                        ForEach(MealType.allCases, id: \.self) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }

                Section {
                    Button("Save entry") {
                        saveEntry()
                    }
                    .disabled(!canSave)

                    if saved {
                        Text("Saved")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Confirm food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                prefill()
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func macroRow(label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
        }
    }

    private func prefill() {
        foodName = product.name
        
        // Auto-detect and populate serving size from label
        if let parsed = BarcodeAPIService.parseServingSize(product.servingSize) {
            servingSize = formatted(parsed.value)
            
            // Create custom unit if descriptor is not a standard weight unit
            if !BarcodeAPIService.isWeightUnit(parsed.descriptor) {
                // Custom descriptor like "cookies", "crackers", etc.
                // gramsPerServing is the total grams for the entire serving
                // We need gramsPerUnit which is grams per single item
                let gramsPerUnit = parsed.value > 0 ? parsed.gramsPerServing / parsed.value : parsed.gramsPerServing
                let customUnit = ServingUnit.custom(label: parsed.descriptor, gramsPerUnit: gramsPerUnit)
                servingUnit = customUnit
                previousUnit = customUnit
                availableUnits = ServingUnit.standardUnits + [customUnit]
            } else {
                // Standard weight unit - use grams
                servingUnit = .grams
                previousUnit = .grams
            }
        }
        
        recalculate()
    }

    private func recalculate() {
        let f = servingFactor
        carbsStr = formatted(product.carbs * f)
        proteinStr = formatted(product.protein * f)
        fatStr = formatted(product.fat * f)
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private var canSave: Bool {
        guard !foodName.trimmingCharacters(in: .whitespaces).isEmpty,
              userId != nil,
              let c = Double(carbsStr), let p = Double(proteinStr), let f = Double(fatStr),
              c >= 0, p >= 0, f >= 0 else { return false }
        return true
    }

    private func saveEntry() {
        guard let uid = userId,
              let c = Double(carbsStr),
              let p = Double(proteinStr),
              let f = Double(fatStr) else { return }
        let cal = Double(Int((c * 4) + (p * 4) + (f * 9)))
        let date = Calendar.current.startOfDay(for: selectedDate)

        let entry = LogEntry(
            userId: uid,
            date: date,
            mealType: selectedMeal,
            foodName: foodName.trimmingCharacters(in: .whitespaces),
            carbs: c,
            protein: p,
            fat: f,
            calories: cal,
            barcode: product.barcode
        )
        modelContext.insert(entry)
        try? modelContext.save()
        Task {
            await syncService.pushEntry(entry)
        }
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            saved = false
            dismiss()
        }
    }
}
