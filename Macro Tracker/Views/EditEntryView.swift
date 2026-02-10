//
//  EditEntryView.swift
//  Macro Tracker
//
//  Edit an existing log entry. Pre-fills all fields from the entry.
//

import SwiftUI
import SwiftData

struct EditEntryView: View {
    @Bindable var entry: LogEntry

    @EnvironmentObject var syncService: SyncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var foodName: String = ""
    @State private var carbsStr: String = ""
    @State private var proteinStr: String = ""
    @State private var fatStr: String = ""
    @State private var selectedMeal: MealType = .breakfast
    @State private var selectedDate: Date = Date()
    @State private var servingSize: String = ""
    @State private var servingUnit: ServingUnit = .grams
    @State private var saved = false

    private var calculatedCalories: Int {
        let c = Double(carbsStr) ?? 0
        let p = Double(proteinStr) ?? 0
        let f = Double(fatStr) ?? 0
        return Int((c * 4) + (p * 4) + (f * 9))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $foodName)
                    ServingSizeRow(servingSize: $servingSize, servingUnit: $servingUnit)
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
                    Button("Save changes") {
                        saveChanges()
                    }
                    .disabled(!canSave)

                    if saved {
                        Text("Saved")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Edit entry")
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
        foodName = entry.foodName
        carbsStr = formatted(entry.carbs)
        proteinStr = formatted(entry.protein)
        fatStr = formatted(entry.fat)
        selectedMeal = entry.mealTypeEnum
        selectedDate = entry.date
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private var canSave: Bool {
        guard !foodName.trimmingCharacters(in: .whitespaces).isEmpty,
              let c = Double(carbsStr), let p = Double(proteinStr), let f = Double(fatStr),
              c >= 0, p >= 0, f >= 0 else { return false }
        return true
    }

    private func saveChanges() {
        guard let c = Double(carbsStr),
              let p = Double(proteinStr),
              let f = Double(fatStr) else { return }

        entry.foodName = foodName.trimmingCharacters(in: .whitespaces)
        entry.carbs = c
        entry.protein = p
        entry.fat = f
        entry.calories = Double(calculatedCalories)
        entry.mealTypeEnum = selectedMeal
        entry.date = Calendar.current.startOfDay(for: selectedDate)

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
