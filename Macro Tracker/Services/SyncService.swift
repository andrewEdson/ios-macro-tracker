//
//  SyncService.swift
//  Macro Tracker
//

import Foundation
import FirebaseFirestore
import SwiftData

@MainActor
final class SyncService: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncError: String?

    private let db = Firestore.firestore()
    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    private func usersRef() -> DocumentReference? {
        guard let uid = authService.userId else { return nil }
        return db.collection("users").document(uid)
    }

    private func goalsRef() -> DocumentReference? {
        usersRef()?.collection("data").document("goals")
    }

    private func entriesRef() -> CollectionReference? {
        usersRef()?.collection("entries")
    }

    // MARK: - Goals

    func pushGoals(_ goals: MacroGoals) async {
        guard let ref = goalsRef() else { return }
        isSyncing = true
        lastSyncError = nil
        do {
            try await ref.setData([
                "carbs": goals.carbs,
                "protein": goals.protein,
                "fat": goals.fat,
                "updatedAt": Timestamp(date: goals.updatedAt),
            ] as [String: Any])
        } catch {
            lastSyncError = error.localizedDescription
        }
        isSyncing = false
    }

    func pullGoals(modelContext: ModelContext) async {
        guard let ref = goalsRef() else { return }
        isSyncing = true
        lastSyncError = nil
        do {
            let snapshot = try await ref.getDocument()
            guard let uid = authService.userId else { return }
            if let data = snapshot.data() {
                let carbs = data["carbs"] as? Double ?? 0
                let protein = data["protein"] as? Double ?? 0
                let fat = data["fat"] as? Double ?? 0
                let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

                let descriptor = FetchDescriptor<MacroGoals>(predicate: #Predicate { $0.userId == uid })
                let existing = try modelContext.fetch(descriptor)
                if let first = existing.first {
                    first.carbs = carbs
                    first.protein = protein
                    first.fat = fat
                    first.updatedAt = updatedAt
                } else {
                    let goals = MacroGoals(userId: uid, carbs: carbs, protein: protein, fat: fat, updatedAt: updatedAt)
                    modelContext.insert(goals)
                }
                try modelContext.save()
            }
        } catch {
            lastSyncError = error.localizedDescription
        }
        isSyncing = false
    }

    // MARK: - Log entries

    func pushEntry(_ entry: LogEntry) async {
        guard let ref = entriesRef() else { return }
        isSyncing = true
        lastSyncError = nil
        do {
            var data: [String: Any] = [
                "userId": entry.userId,
                "date": Timestamp(date: entry.date),
                "mealType": entry.mealType,
                "foodName": entry.foodName,
                "carbs": entry.carbs,
                "protein": entry.protein,
                "fat": entry.fat,
                "createdAt": Timestamp(date: entry.createdAt),
            ]
            if let cal = entry.calories { data["calories"] = cal }
            if let bar = entry.barcode { data["barcode"] = bar }
            let docRef = ref.document(entry.id.uuidString)
            try await docRef.setData(data)
        } catch {
            lastSyncError = error.localizedDescription
        }
        isSyncing = false
    }

    func deleteEntry(_ entry: LogEntry) async {
        guard let ref = entriesRef() else { return }
        isSyncing = true
        lastSyncError = nil
        do {
            try await ref.document(entry.id.uuidString).delete()
        } catch {
            lastSyncError = error.localizedDescription
        }
        isSyncing = false
    }

    func pullEntries(modelContext: ModelContext) async {
        guard let ref = entriesRef(), let uid = authService.userId else { return }
        isSyncing = true
        lastSyncError = nil
        do {
            let snapshot = try await ref.getDocuments()
            for doc in snapshot.documents {
                let data = doc.data()
                guard let entryId = UUID(uuidString: doc.documentID) else { continue }
                let existingDescriptor = FetchDescriptor<LogEntry>(predicate: #Predicate<LogEntry> { $0.id == entryId })
                let existing = try modelContext.fetch(existingDescriptor)
                if existing.isEmpty {
                    let date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
                    let mealType = data["mealType"] as? String ?? MealType.snack.rawValue
                    let foodName = data["foodName"] as? String ?? ""
                    let carbs = data["carbs"] as? Double ?? 0
                    let protein = data["protein"] as? Double ?? 0
                    let fat = data["fat"] as? Double ?? 0
                    let calories = data["calories"] as? Double
                    let barcode = data["barcode"] as? String
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let entry = LogEntry(
                        id: entryId,
                        userId: uid,
                        date: date,
                        mealType: MealType(rawValue: mealType) ?? .snack,
                        foodName: foodName,
                        carbs: carbs,
                        protein: protein,
                        fat: fat,
                        calories: calories,
                        barcode: barcode,
                        createdAt: createdAt
                    )
                    modelContext.insert(entry)
                }
            }
            try modelContext.save()
        } catch {
            lastSyncError = error.localizedDescription
        }
        isSyncing = false
    }

    /// Call after sign-in or on app launch when online.
    func fullSync(modelContext: ModelContext) async {
        await pullGoals(modelContext: modelContext)
        await pullEntries(modelContext: modelContext)
    }
}
