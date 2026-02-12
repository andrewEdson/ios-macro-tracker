//
//  TodayView.swift
//  Macro Tracker
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [LogEntry]

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var entryToEdit: LogEntry?

    private var userId: String? { authService.userId }

    private var dayStart: Date {
        Calendar.current.startOfDay(for: selectedDate)
    }
    private var dayEnd: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    }

    private var entriesForDay: [LogEntry] {
        entries.filter { $0.userId == userId && $0.date >= dayStart && $0.date < dayEnd }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var entriesByMeal: [(MealType, [LogEntry])] {
        MealType.allCases.map { meal in
            (meal, entriesForDay.filter { $0.mealTypeEnum == meal })
        }
    }

    private var totalCarbs: Double { entriesForDay.reduce(0) { $0 + $1.carbs } }
    private var totalProtein: Double { entriesForDay.reduce(0) { $0 + $1.protein } }
    private var totalFat: Double { entriesForDay.reduce(0) { $0 + $1.fat } }
    private var totalCalories: Double {
        entriesForDay.reduce(0) { $0 + ($1.calories ?? ($1.carbs * 4 + $1.protein * 4 + $1.fat * 9)) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }

                if let goals = goalsForUser() {
                    Section {
                        MacroProgressRow(label: "Calories", consumed: totalCalories, target: goals.calorieGoal, unit: "kcal")
                        MacroProgressRow(label: "Carbs", consumed: totalCarbs, target: goals.carbs)
                        MacroProgressRow(label: "Protein", consumed: totalProtein, target: goals.protein)
                        MacroProgressRow(label: "Fat", consumed: totalFat, target: goals.fat)
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Progress")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.accentColor)
                        .textCase(.none)
                    }
                }

                ForEach(entriesByMeal, id: \.0) { meal, items in
                    Section(meal.displayName) {
                        if items.isEmpty {
                            Text("No entries")
                                .foregroundColor(.secondary)
                        } else {
                            mealTotals(items)
                            ForEach(items, id: \.id) { entry in
                                LogEntryRow(entry: entry)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        entryToEdit = entry
                                    }
                            }
                            .onDelete { offsets in
                                deleteEntries(items: items, at: offsets)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if syncService.isSyncing {
                        ProgressView()
                    } else if syncService.lastSyncError != nil {
                        Image(systemName: "exclamationmark.icloud")
                            .foregroundColor(.orange)
                    }
                }
            }
            .sheet(item: $entryToEdit) { entry in
                EditEntryView(entry: entry)
            }
        }
    }

    private func mealTotals(_ items: [LogEntry]) -> some View {
        let c = items.reduce(0) { $0 + $1.carbs }
        let p = items.reduce(0) { $0 + $1.protein }
        let f = items.reduce(0) { $0 + $1.fat }
        let cal = items.reduce(0) { $0 + ($1.calories ?? ($1.carbs * 4 + $1.protein * 4 + $1.fat * 9)) }
        return HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color("CaloriesColor"))
                Text("\(Int(cal))")
                    .font(.system(size: 13, weight: .semibold))
            }
            Divider()
                .frame(height: 12)
            HStack(spacing: 4) {
                Text("C")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color("CarbsColor"))
                Text("\(Int(c))")
                    .font(.system(size: 12, weight: .medium))
            }
            HStack(spacing: 4) {
                Text("P")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color("ProteinColor"))
                Text("\(Int(p))")
                    .font(.system(size: 12, weight: .medium))
            }
            HStack(spacing: 4) {
                Text("F")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color("FatColor"))
                Text("\(Int(f))")
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .foregroundColor(.secondary)
        .padding(.vertical, 4)
    }

    private func deleteEntries(items: [LogEntry], at offsets: IndexSet) {
        for index in offsets {
            let entry = items[index]
            Task {
                await syncService.deleteEntry(entry)
            }
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }

    private func goalsForUser() -> MacroGoals? {
        guard let uid = userId else { return nil }
        let descriptor = FetchDescriptor<MacroGoals>(predicate: #Predicate { $0.userId == uid })
        return try? modelContext.fetch(descriptor).first
    }
}

struct MacroProgressRow: View {
    let label: String
    let consumed: Double
    let target: Double
    var unit: String = "g"

    private var remaining: Double { target - consumed }
    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, consumed / target)
    }
    
    private var macroColor: Color {
        switch label {
        case "Calories": return Color("CaloriesColor")
        case "Carbs": return Color("CarbsColor")
        case "Protein": return Color("ProteinColor")
        case "Fat": return Color("FatColor")
        default: return .accentColor
        }
    }
    
    private var macroIcon: String {
        switch label {
        case "Calories": return "flame.fill"
        case "Carbs": return "leaf.fill"
        case "Protein": return "bolt.fill"
        case "Fat": return "drop.fill"
        default: return "circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: macroIcon)
                    .foregroundColor(macroColor)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(Int(consumed)) / \(Int(target)) \(unit)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [macroColor.opacity(0.8), macroColor]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
            
            if remaining != 0 {
                Text(remaining > 0 ? "\(Int(remaining)) \(unit) remaining" : "\(Int(-remaining)) \(unit) over")
                    .font(.caption)
                    .foregroundColor(remaining > 0 ? .secondary : Color("CaloriesColor"))
            }
        }
        .padding(.vertical, 4)
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.foodName)
                    .font(.system(size: 16, weight: .medium))
                HStack(spacing: 12) {
                    MacroBadge(value: entry.carbs, color: Color("CarbsColor"), label: "C")
                    MacroBadge(value: entry.protein, color: Color("ProteinColor"), label: "P")
                    MacroBadge(value: entry.fat, color: Color("FatColor"), label: "F")
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct MacroBadge: View {
    let value: Double
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
            Text("\(Int(value))")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

struct TodayView_Previews: PreviewProvider {
    static var previews: some View {
        TodayView()
            .environmentObject(AuthService())
            .environmentObject(SyncService(authService: AuthService()))
            .modelContainer(for: [LogEntry.self, MacroGoals.self], inMemory: true)
    }
}
