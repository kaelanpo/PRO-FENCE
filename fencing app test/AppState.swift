//
//  AppState.swift
//  fencing app test
//
//  Single source of truth for the estimate form. All persistence is local (offline-first).
//

import Foundation
import SwiftUI

private let pricingKey = "fencing.contractorPricing"
private let nameKey = "contractor_name"

@Observable
final class AppState {
    // Job / customer
    var customerName: String = ""
    var address: String = ""
    var jobDate: Date = Date()
    var supplierUsed: String = ""

    // Measurements
    var linearFeetStr: String = ""
    var fenceType: FenceType = .woodPrivacy
    var gateWalk: Int = 0
    var gateDrive: Int = 0
    var terrain: Terrain = .flat

    // Contractor (for quotes)
    var contractorName: String = ""
    var editingContractorName: Bool = false

    // Pricing config (persisted to UserDefaults)
    var pricing: ContractorPricing {
        didSet { savePricing() }
    }

    // UI state
    var showPricingSheet: Bool = false
    var showMaterialList: Bool = false
    var showProfitPreview: Bool = false

    var gateCount: GateCount { GateCount(walk: gateWalk, drive: gateDrive) }

    var linearFeet: Double {
        Double(linearFeetStr.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    var estimate: EstimateResult? {
        guard linearFeet > 0 else { return nil }
        return runEstimate(
            linearFeet: linearFeet,
            fenceType: fenceType,
            gateCount: gateCount,
            terrain: terrain,
            pricing: pricing
        )
    }

    init() {
        self.pricing = Self.loadPricing()
        self.contractorName = UserDefaults.standard.string(forKey: nameKey) ?? ""
    }

    static func loadPricing() -> ContractorPricing {
        guard let data = UserDefaults.standard.data(forKey: pricingKey),
              let decoded = try? JSONDecoder().decode(ContractorPricing.self, from: data) else {
            return .default
        }
        return decoded
    }

    func savePricing() {
        guard let data = try? JSONEncoder().encode(pricing) else { return }
        UserDefaults.standard.set(data, forKey: pricingKey)
    }

    func saveContractorName() {
        UserDefaults.standard.set(contractorName, forKey: nameKey)
    }

    /// Clear job and measurement inputs; pricing and fence type stay intact.
    func clearJobInputs() {
        customerName = ""
        address = ""
        jobDate = Date()
        supplierUsed = ""
        linearFeetStr = ""
        gateWalk = 0
        gateDrive = 0
        terrain = .flat
    }

    /// Legacy: clear form only (no snapshot). Prefer clearJobInputs after saving.
    func resetForm() {
        linearFeetStr = ""
        gateWalk = 0
        gateDrive = 0
        terrain = .flat
    }
}
