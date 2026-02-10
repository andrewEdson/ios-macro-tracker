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
    @State private var caloriesStr: String = ""
    @State private var selectedMeal: MealType = .breakfast
    @State private var selectedDate = Date()
    @State private var servingGrams: String = "100"
    @State private var saved = false

    private var userId: String? { authService.userId }

    // MARK: - Computed serving values

    /// Factor to scale per-100g values to the entered serving size.
    private var servingFactor: Double {
        guard let g = Double(servingGrams), g > 0 else { return 1 }
        return g / 100.0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Name", text: $foodName)

                    HStack {
                        Text("Serving size (g)")
                        Spacer()
                        TextField("100", text: $servingGrams)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .onChange(of: servingGrams) { _ in
                                recalculate()
                            }
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
                    macroRow(label: "Calories (optional)", text: $caloriesStr)
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
        recalculate()
    }

    private func recalculate() {
        let f = servingFactor
        carbsStr = formatted(product.carbs * f)
        proteinStr = formatted(product.protein * f)
        fatStr = formatted(product.fat * f)
        if let cal = product.calories {
            caloriesStr = formatted(cal * f)
        } else {
            caloriesStr = ""
        }
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
        let cal: Double? = Double(caloriesStr.trimmingCharacters(in: .whitespaces)).flatMap { $0 >= 0 ? $0 : nil }
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
