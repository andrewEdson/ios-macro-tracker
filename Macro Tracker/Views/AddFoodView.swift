//
//  AddFoodView.swift
//  Macro Tracker
//

import SwiftUI
import SwiftData

struct AddFoodView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var foodName = ""
    @State private var carbsStr = ""
    @State private var proteinStr = ""
    @State private var fatStr = ""
    @State private var selectedMeal: MealType = .breakfast
    @State private var selectedDate = Date()
    @State private var showBarcodeScanner = false
    @State private var saved = false

    private var userId: String? { authService.userId }

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
                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("0", text: $carbsStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                    }
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("0", text: $proteinStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                    }
                    HStack {
                        Text("Fat (g)")
                        Spacer()
                        TextField("0", text: $fatStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                    }
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
            .navigationTitle("Add food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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
              let c = Double(carbsStr), let p = Double(proteinStr), let f = Double(fatStr) else { return }
        let cal = Double(calculatedCalories)
        let date = Calendar.current.startOfDay(for: selectedDate)

        let entry = LogEntry(
            userId: uid,
            date: date,
            mealType: selectedMeal,
            foodName: foodName.trimmingCharacters(in: .whitespaces),
            carbs: c,
            protein: p,
            fat: f,
            calories: cal
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

struct AddFoodView_Previews: PreviewProvider {
    static var previews: some View {
        AddFoodView()
            .environmentObject(AuthService())
            .environmentObject(SyncService(authService: AuthService()))
            .modelContainer(for: LogEntry.self, inMemory: true)
    }
}
