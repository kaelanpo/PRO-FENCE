//
//  ZipCodeService.swift
//  fencing app test
//
//  Regional pricing layer. Applies market index to materials and labor by zip.
//  Structured for future BigBox/API hook (e.g. real-time 4×4 post at nearest store).
//

import Foundation

/// Multipliers applied to raw material cost and loaded labor for a region.
struct RegionalMultipliers: Equatable {
    let materialIndex: Double   // e.g. 1.2 = 20% higher materials (Cedar in Northeast)
    let laborIndex: Double     // e.g. 0.95 = 5% lower labor (TN vs national)
    let regionName: String
    let stateCode: String
}

/// Lookup table: zip (prefix or full) → regional multipliers.
/// Uses first 3 digits (ZIP prefix) for region; full zip can override for specific cities.
struct RegionalMultiplierTable {
    /// ZIP prefix (e.g. "371") or full zip (e.g. "37167") → multipliers
    private let table: [String: RegionalMultipliers]

    init(table: [String: RegionalMultipliers]) {
        self.table = table
    }

    /// Lookup by full zip first, then by 3-digit prefix.
    func multipliers(for zipCode: String) -> RegionalMultipliers? {
        let normalized = zipCode.trimmingCharacters(in: .whitespacesAndNewlines).prefix(5)
        let full = String(normalized)
        let prefix = String(normalized.prefix(3))
        return table[full] ?? table[prefix]
    }
}

/// Service that resolves zip to regional multipliers. Can be extended for BigBox API.
final class ZipCodeService {
    private let table: RegionalMultiplierTable

    init(table: RegionalMultiplierTable) {
        self.table = table
    }

    /// Returns multipliers for the given zip, or nil if unknown (caller uses 1.0, 1.0).
    func regionalMultipliers(zipCode: String) -> RegionalMultipliers? {
        guard !zipCode.isEmpty else { return nil }
        return table.multipliers(for: zipCode)
    }
}

// MARK: - Default US table (sample regions; expand as needed)
extension RegionalMultiplierTable {
    /// Sample table: TN (Smyrna), NY, TX, CA. Material index = relative material cost; labor = relative wage.
    static let defaultUS: RegionalMultiplierTable = {
        var t: [String: RegionalMultipliers] = [
            // Smyrna, TN 37167 — baseline
            "371": RegionalMultipliers(materialIndex: 1.0, laborIndex: 0.95, regionName: "Middle TN", stateCode: "TN"),
            "37167": RegionalMultipliers(materialIndex: 1.0, laborIndex: 0.95, regionName: "Smyrna, TN", stateCode: "TN"),
            // NY — higher labor and materials
            "100": RegionalMultipliers(materialIndex: 1.2, laborIndex: 1.35, regionName: "NYC Metro", stateCode: "NY"),
            "10": RegionalMultipliers(materialIndex: 1.2, laborIndex: 1.35, regionName: "New York", stateCode: "NY"),
            // Texas
            "75": RegionalMultipliers(materialIndex: 0.95, laborIndex: 0.90, regionName: "North TX", stateCode: "TX"),
            "77": RegionalMultipliers(materialIndex: 0.95, laborIndex: 0.90, regionName: "Houston", stateCode: "TX"),
            // California
            "90": RegionalMultipliers(materialIndex: 1.15, laborIndex: 1.25, regionName: "California", stateCode: "CA"),
        ]
        return RegionalMultiplierTable(table: t)
    }()
}
