//
//  AddTabView.swift
//  Macro Tracker
//

import SwiftUI
import SwiftData

struct AddTabView: View {
    @EnvironmentObject var barcodeAPIService: BarcodeAPIService
    @Environment(\.modelContext) private var modelContext

    @State private var showManualEntry = false
    @State private var showBarcodeScanner = false
    @State private var showBarcodeConfirm = false
    @State private var showLookupError = false
    @State private var showFoodSearch = false
    @State private var scannedProduct: BarcodeProduct?
    @State private var scannerDismissed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Hero section
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Log Your Food")
                        .font(.system(size: 24, weight: .bold))
                    Text("Choose how you'd like to add your meal")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.accentColor.opacity(0.08))
                
                // Action buttons
                VStack(spacing: 16) {
                    ActionButton(
                        title: "Search food",
                        subtitle: "Find nutrition info from database",
                        icon: "magnifyingglass",
                        color: .accentColor
                    ) {
                        showFoodSearch = true
                    }
                    
                    ActionButton(
                        title: "Scan barcode",
                        subtitle: "Quick scan with your camera",
                        icon: "barcode.viewfinder",
                        color: Color("ProteinColor")
                    ) {
                        showBarcodeScanner = true
                    }
                    
                    ActionButton(
                        title: "Add manually",
                        subtitle: "Enter nutrition details yourself",
                        icon: "square.and.pencil",
                        color: Color("CarbsColor")
                    ) {
                        showManualEntry = true
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                
                Spacer()
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if barcodeAPIService.isLoading {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Looking up product…")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .sheet(isPresented: $showManualEntry) {
                AddFoodView()
            }
            .sheet(isPresented: $showFoodSearch) {
                FoodSearchView { product in
                    scannedProduct = product
                    showBarcodeConfirm = true
                }
            }
            .sheet(isPresented: $showBarcodeScanner, onDismiss: {
                scannerDismissed = true
            }) {
                BarcodeScannerView(onScan: { barcode in
                    scannerDismissed = false
                    showBarcodeScanner = false
                    lookupBarcode(barcode)
                })
            }
            .sheet(isPresented: $showBarcodeConfirm) {
                if let product = scannedProduct {
                    BarcodeConfirmView(product: product)
                }
            }
            .alert("Lookup failed", isPresented: $showLookupError) {
                Button("Enter manually") {
                    showManualEntry = true
                }
                Button("Try again") {
                    showBarcodeScanner = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(barcodeAPIService.errorMessage ?? "Could not find this product.")
            }
        }
    }

struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

    private func lookupBarcode(_ barcode: String) {
        Task {
            let product = await barcodeAPIService.lookup(barcode: barcode, modelContext: modelContext)
            // Wait for scanner sheet dismiss animation to finish
            while !scannerDismissed {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            if let product {
                scannedProduct = product
                showBarcodeConfirm = true
            } else {
                showLookupError = true
            }
        }
    }
}

struct AddTabView_Previews: PreviewProvider {
    static var previews: some View {
        AddTabView()
            .environmentObject(AuthService())
            .environmentObject(SyncService(authService: AuthService()))
            .environmentObject(BarcodeAPIService())
            .modelContainer(for: [LogEntry.self, CachedFood.self], inMemory: true)
    }
}
