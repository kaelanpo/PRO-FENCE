//
//  JobSnapshot.swift
//  fencing app test
//
//  Contractor-grade job snapshot for local storage. Offline-first; no network.
//

import Foundation
import SwiftData

@Model
final class JobSnapshot {
    var customerName: String
    var address: String
    var date: Date
    var fenceType: String
    var measurements: String
    var finalPrice: Double
    var materialList: String
    var supplierUsed: String
    
    init(
        customerName: String,
        address: String,
        date: Date,
        fenceType: String,
        measurements: String,
        finalPrice: Double,
        materialList: String,
        supplierUsed: String
    ) {
        self.customerName = customerName
        self.address = address
        self.date = date
        self.fenceType = fenceType
        self.measurements = measurements
        self.finalPrice = finalPrice
        self.materialList = materialList
        self.supplierUsed = supplierUsed
    }
}
