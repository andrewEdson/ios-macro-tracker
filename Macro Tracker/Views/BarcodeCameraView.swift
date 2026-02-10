//
//  BarcodeCameraView.swift
//  Macro Tracker
//

import SwiftUI
import AVFoundation

struct BarcodeCameraView: View {
    var onScan: (String) -> Void
    @State private var showManualEntry = false
    @State private var manualCode = ""

    var body: some View {
        ZStack {
            BarcodeScannerRepresentable(onScan: onScan)
                .ignoresSafeArea()

            VStack {
                Spacer()
                Button("Enter barcode manually") {
                    showManualEntry = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showManualEntry) {
            VStack(spacing: 16) {
                Text("Enter barcode")
                    .font(.headline)
                TextField("Barcode number", text: $manualCode)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .padding(.horizontal)
                Button("Use this barcode") {
                    if !manualCode.isEmpty {
                        onScan(manualCode)
                        showManualEntry = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let vc = BarcodeScannerViewController()
        vc.onBarcodeScanned = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {
        uiViewController.onBarcodeScanned = onScan
    }
}
