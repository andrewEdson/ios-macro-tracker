//
//  BarcodeScannerView.swift
//  Macro Tracker
//
//  Placeholder; camera implementation in BarcodeScannerViewController.
//

import SwiftUI

struct BarcodeScannerView: View {
    var onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            BarcodeCameraView { barcode in
                onScan(barcode)
                dismiss()
            }
            .ignoresSafeArea()
            .navigationTitle("Scan barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
