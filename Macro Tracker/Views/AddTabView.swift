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
    @State private var scannedProduct: BarcodeProduct?

    var body: some View {
        NavigationStack {
            List {
                Button {
                    showManualEntry = true
                } label: {
                    Label("Add food manually", systemImage: "square.and.pencil")
                }
                Button {
                    showBarcodeScanner = true
                } label: {
                    Label("Scan barcode", systemImage: "barcode.viewfinder")
                }
            }
            .navigationTitle("Add")
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
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(onScan: { barcode in
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

    private func lookupBarcode(_ barcode: String) {
        Task {
            let product = await barcodeAPIService.lookup(barcode: barcode, modelContext: modelContext)
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
