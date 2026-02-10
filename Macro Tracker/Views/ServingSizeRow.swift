//
//  ServingSizeRow.swift
//  Macro Tracker
//

import SwiftUI

struct ServingSizeRow: View {
    @Binding var servingSize: String
    @Binding var servingUnit: ServingUnit

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Serving size")
                Spacer()
                TextField("100", text: $servingSize)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                Text(servingUnit.displayName)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
            }
            Picker("Unit", selection: $servingUnit) {
                ForEach(ServingUnit.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
