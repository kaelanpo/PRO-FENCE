//
//  FenceQuoteViewModel.swift
//  fencing app test
//
//  Single source of truth. Every input binds here; estimate recalculates on any change.
//

import Foundation
import SwiftUI

// MARK: - Display struct for the estimate section (live values)
struct ComputedEstimate {
    var materialCost: Double
    var salesTaxAmount: Double
    var laborCost: Double
    var totalCost: Double
    var effectivePricePerLF: Double
    var materialList: [MaterialLineItem]
}

// MARK: - Single source of truth
@Observable
final class FenceQuoteViewModel {
    // Inputs — every control binds to one of these
    var contractorName: String = ""
    var selectedFenceType: FenceType = .woodPrivacy
    /// TextField binds here; engine uses computed linearFeet
    var linearFeetString: String = ""
    var walkGates: Int = 0
    var driveGates: Int = 0
    var terrainType: Terrain = .flat
    var zipCode: String = ""

    // Layout Details (construction takeoff)
    var corners90: Int = 0
    var endsAtHouse: Bool = false
    var sectionLength: SectionLength = .standard8ft
    var pricing: ContractorPricing = .default {
        didSet { savePricing() }
    }

    // UI state (not persisted)
    var showPricingSheet: Bool = false
    var showMaterialList: Bool = false
    var editingContractorName: Bool = false

    // Persistence keys
    private let pricingKey = "fencing.contractorPricing"
    private let nameKey = "contractor_name"

    init() {
        loadPricing()
        contractorName = UserDefaults.standard.string(forKey: nameKey) ?? ""
    }

    // MARK: - Derived for engine (no manual refresh)
    var linearFeet: Double {
        Double(linearFeetString.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    var gateCount: GateCount {
        GateCount(walk: walkGates, drive: driveGates)
    }

    var layoutDetails: LayoutDetails {
        LayoutDetails(corners90: corners90, endsAtHouse: endsAtHouse, sectionLength: sectionLength)
    }

    /// Recalculates on every state change. No delay, no button.
    var computedEstimate: ComputedEstimate? {
        guard linearFeet > 0 else { return nil }
        let result = runEstimate(
            linearFeet: linearFeet,
            fenceType: selectedFenceType,
            gateCount: gateCount,
            terrain: terrainType,
            pricing: pricing,
            zipCode: zipCode.isEmpty ? nil : zipCode,
            layout: layoutDetails
        )
        return ComputedEstimate(
            materialCost: result.costs.materialCostRaw,
            salesTaxAmount: result.costs.salesTaxAmount,
            laborCost: result.costs.laborCost + result.costs.gateLabor,
            totalCost: result.costs.total,
            effectivePricePerLF: result.costs.perLinearFoot,
            materialList: result.lineItems
        )
    }

    /// Full result when needed for quote text / supplier list
    var fullEstimateResult: EstimateResult? {
        guard linearFeet > 0 else { return nil }
        return runEstimate(
            linearFeet: linearFeet,
            fenceType: selectedFenceType,
            gateCount: gateCount,
            terrain: terrainType,
            pricing: pricing,
            zipCode: zipCode.isEmpty ? nil : zipCode,
            layout: layoutDetails
        )
    }

    // MARK: - Persistence
    private func loadPricing() {
        guard let data = UserDefaults.standard.data(forKey: pricingKey),
              let decoded = try? JSONDecoder().decode(ContractorPricing.self, from: data) else {
            return
        }
        pricing = decoded
    }

    private func savePricing() {
        guard let data = try? JSONEncoder().encode(pricing) else { return }
        UserDefaults.standard.set(data, forKey: pricingKey)
    }

    func saveContractorName() {
        UserDefaults.standard.set(contractorName, forKey: nameKey)
    }

    /// Close Job: clear measurement inputs only. Pricing and contractor name unchanged.
    func clearMeasurementInputsOnly() {
        linearFeetString = ""
        walkGates = 0
        driveGates = 0
        terrainType = .flat
        corners90 = 0
        endsAtHouse = false
        sectionLength = .standard8ft
    }
}
