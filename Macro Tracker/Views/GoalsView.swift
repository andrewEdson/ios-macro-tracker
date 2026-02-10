//
//  GoalsView.swift
//  Macro Tracker
//

import SwiftUI
import SwiftData

struct GoalsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService
    @Environment(\.modelContext) private var modelContext

    @State private var carbs: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var hasLoaded = false
    @State private var savedMessage: String?

    private var userId: String? { authService.userId }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("0", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Fat (g)")
                        Spacer()
                        TextField("0", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Calories")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(calculatedCalories)) kcal")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Daily macro targets")
                }

                Section {
                    Button("Save goals") {
                        saveGoals()
                    }
                    .disabled(!isValidInput)

                    if let msg = savedMessage {
                        Text(msg)
                            .foregroundColor(.secondary)
                    }

                }

                Section {
                    Button("Sign out", role: .destructive) {
                        try? authService.signOut()
                    }
                }
            }
            .navigationTitle("Goals")
            .onAppear { loadGoals() }
        }
    }

    private var calculatedCalories: Double {
        let c = Double(carbs) ?? 0
        let p = Double(protein) ?? 0
        let f = Double(fat) ?? 0
        return (c * 4) + (p * 4) + (f * 9)
    }

    private var isValidInput: Bool {
        guard let c = Double(carbs), let p = Double(protein), let f = Double(fat) else { return false }
        return c >= 0 && p >= 0 && f >= 0
    }

    private func loadGoals() {
        guard let uid = userId else { return }
        let descriptor = FetchDescriptor<MacroGoals>(predicate: #Predicate { $0.userId == uid })
        guard let existing = try? modelContext.fetch(descriptor).first else {
            if !hasLoaded {
                carbs = "0"
                protein = "0"
                fat = "0"
                hasLoaded = true
            }
            return
        }
        carbs = format(existing.carbs)
        protein = format(existing.protein)
        fat = format(existing.fat)
        hasLoaded = true
    }

    private func format(_ value: Double) -> String {
        value == floor(value) ? "\(Int(value))" : "\(value)"
    }

    private func saveGoals() {
        guard let uid = userId,
              let c = Double(carbs), let p = Double(protein), let f = Double(fat),
              c >= 0, p >= 0, f >= 0 else { return }

        let descriptor = FetchDescriptor<MacroGoals>(predicate: #Predicate { $0.userId == uid })
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let now = Date()

        if let first = existing.first {
            first.carbs = c
            first.protein = p
            first.fat = f
            first.updatedAt = now
        } else {
            let goals = MacroGoals(userId: uid, carbs: c, protein: p, fat: f, updatedAt: now)
            modelContext.insert(goals)
        }
        try? modelContext.save()
        savedMessage = "Saved"
        Task {
            if let g = try? modelContext.fetch(FetchDescriptor<MacroGoals>(predicate: #Predicate { $0.userId == uid })).first {
                await syncService.pushGoals(g)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            savedMessage = nil
        }
    }
}

struct GoalsView_Previews: PreviewProvider {
    static var previews: some View {
        GoalsView()
            .environmentObject(AuthService())
            .environmentObject(SyncService(authService: AuthService()))
            .modelContainer(for: [MacroGoals.self], inMemory: true)
    }
}
