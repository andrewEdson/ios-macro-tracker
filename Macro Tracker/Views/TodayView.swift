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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                }

                if let goals = goalsForUser() {
                    Section("Progress") {
                        MacroProgressRow(label: "Carbs", consumed: totalCarbs, target: goals.carbs)
                        MacroProgressRow(label: "Protein", consumed: totalProtein, target: goals.protein)
                        MacroProgressRow(label: "Fat", consumed: totalFat, target: goals.fat)
                    }
                }

                ForEach(entriesByMeal, id: \.0) { meal, items in
                    Section(meal.displayName) {
                        if items.isEmpty {
                            Text("No entries")
                                .foregroundColor(.secondary)
                        } else {
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

    private var remaining: Double { target - consumed }
    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, consumed / target)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(consumed)) / \(Int(target)) g")
                    .foregroundColor(.secondary)
            }
            ProgressView(value: progress)
                .tint(progress > 1 ? .orange : .accentColor)
            if remaining != 0 {
                Text(remaining > 0 ? "\(Int(remaining)) g remaining" : "\(Int(-remaining)) g over")
                    .font(.caption)
                    .foregroundColor(remaining > 0 ? .secondary : .orange)
            }
        }
        .padding(.vertical, 2)
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.foodName)
                .font(.headline)
            Text("C: \(Int(entry.carbs))  P: \(Int(entry.protein))  F: \(Int(entry.fat))")
                .font(.caption)
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
