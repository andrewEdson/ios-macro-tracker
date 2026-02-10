//
//  FoodSearchView.swift
//  Macro Tracker
//
//  Search Open Food Facts by food name and select a product to log.
//

import SwiftUI

struct FoodSearchView: View {
    @EnvironmentObject var barcodeAPIService: BarcodeAPIService
    @Environment(\.dismiss) private var dismiss

    let onSelect: (BarcodeProduct) -> Void

    @State private var query = ""
    @State private var results: [BarcodeProduct] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if barcodeAPIService.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Searching…")
                        Spacer()
                    }
                } else if !query.isEmpty && results.isEmpty {
                    Text("No results found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(results, id: \.barcode) { product in
                        Button {
                            onSelect(product)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name)
                                    .foregroundColor(.primary)
                                Text("C: \(Int(product.carbs))  P: \(Int(product.protein))  F: \(Int(product.fat))  \(Int((product.carbs * 4) + (product.protein * 4) + (product.fat * 9))) kcal")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search foods…")
            .onChange(of: query) { _ in
                debounceSearch()
            }
            .navigationTitle("Search food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func debounceSearch() {
        searchTask?.cancel()
        let currentQuery = query
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, !currentQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
                if currentQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    results = []
                }
                return
            }
            let found = await barcodeAPIService.searchFood(query: currentQuery)
            if !Task.isCancelled {
                results = found
            }
        }
    }
}
