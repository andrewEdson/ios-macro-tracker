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
            ScrollView {
                VStack(spacing: 24) {
                    // Hero section
                    VStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.system(size: 54))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.accentColor, Color("ProteinColor")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Your Daily Goals")
                            .font(.system(size: 24, weight: .bold))
                        Text("Set your macro targets to fuel your fitness journey")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(Color.accentColor.opacity(0.08))
                    
                    VStack(spacing: 16) {
                        MacroInputCard(
                            label: "Carbs",
                            icon: "leaf.fill",
                            color: Color("CarbsColor"),
                            value: $carbs
                        )
                        
                        MacroInputCard(
                            label: "Protein",
                            icon: "bolt.fill",
                            color: Color("ProteinColor"),
                            value: $protein
                        )
                        
                        MacroInputCard(
                            label: "Fat",
                            icon: "drop.fill",
                            color: Color("FatColor"),
                            value: $fat
                        )
                        
                        // Calculated Calories
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(Color("CaloriesColor"))
                                .font(.system(size: 20, weight: .semibold))
                            Text("Total Calories")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text("\(Int(calculatedCalories)) kcal")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color("CaloriesColor"))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("CaloriesColor").opacity(0.1))
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Save button
                    Button(action: saveGoals) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                            Text("Save Goals")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: isValidInput ? [.accentColor, .accentColor.opacity(0.8)] : [Color.gray.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .disabled(!isValidInput)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    if let msg = savedMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                            Text(msg)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Sign out button
                    Button(action: { try? authService.signOut() }) {
                        Text("Sign Out")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadGoals() }
        }
    }

struct MacroInputCard: View {
    let label: String
    let icon: String
    let color: Color
    @Binding var value: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 80)
            
            Text("g")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
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
