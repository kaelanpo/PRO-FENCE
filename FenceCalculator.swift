// ============================================================
// FenceCalculator.swift
// Pure calculation functions — no UI, no side effects
// ============================================================

import Foundation

// ─────────────────────────────────────────────
// TYPES
// ─────────────────────────────────────────────

enum FenceType {
    case woodPrivacy
    case woodPicket
    case chainLink
    case vinyl
    case aluminum
    case splitRail
}

enum Terrain {
    case flat
    case slope
    case hilly
}

struct GateCount {
    let walk: Int
    let drive: Int
}

struct ContractorPricing: Codable, Equatable {
    var postCost: Double
    var railCost: Double
    var picketCost: Double
    var panelCost: Double
    var concreteCost: Double
    var hardwareKitCost: Double
    var walkGateCost: Double
    var driveGateCost: Double
    var laborRatePerFoot: Double
    var gateInstallRate: Double
    var markupPercent: Double
    var wastePercent: Double
    
    static let `default` = ContractorPricing(
        postCost: 12.00,
        railCost: 8.00,
        picketCost: 2.50,
        panelCost: 45.00,
        concreteCost: 7.00,
        hardwareKitCost: 35.00,
        walkGateCost: 85.00,
        driveGateCost: 225.00,
        laborRatePerFoot: 8.00,
        gateInstallRate: 75.00,
        markupPercent: 20.0,
        wastePercent: 10.0
    )
}

struct MaterialQuantities {
    let posts: Int
    let rails: Int
    let pickets: Int
    let panels: Int
    let postCaps: Int
    let concreteBags: Int
    let hardwareKits: Int
    let walkGates: Int
    let driveGates: Int
}

struct MaterialLineItem {
    let label: String
    let qty: Int
    let unit: String
    let unitCost: Double
    let subtotal: Double
}

struct CostBreakdown {
    let materialCostRaw: Double
    let materialCostMarked: Double
    let laborCost: Double
    let gateLabor: Double
    let total: Double
    let perLinearFoot: Double
}

struct EstimateResult {
    let quantities: MaterialQuantities
    let costs: CostBreakdown
    let lineItems: [MaterialLineItem]
}

// ─────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────

let postSpacing: [FenceType: Double] = [
    .chainLink: 10.0,
    .woodPrivacy: 8.0,
    .woodPicket: 8.0,
    .vinyl: 8.0,
    .aluminum: 8.0,
    .splitRail: 8.0
]

let terrainMultiplier: [Terrain: Double] = [
    .flat: 1.0,
    .slope: 1.15,
    .hilly: 1.30
]

let picketsPerFoot: [FenceType: Double] = [
    .woodPrivacy: 2.0,
    .woodPicket: 1.5,
    .chainLink: 0.0,
    .vinyl: 0.0,
    .aluminum: 0.0,
    .splitRail: 0.0
]

let railsPerSection: [FenceType: Double] = [
    .woodPrivacy: 3.0,
    .woodPicket: 3.0,
    .chainLink: 1.0,
    .splitRail: 2.0,
    .vinyl: 0.0,
    .aluminum: 0.0
]

// ─────────────────────────────────────────────
// PURE FUNCTIONS
// ─────────────────────────────────────────────

func calculatePosts(linearFeet: Double, fenceType: FenceType) -> Int {
    guard linearFeet > 0 else { return 0 }
    let spacing = postSpacing[fenceType] ?? 8.0
    return Int(ceil(linearFeet / spacing)) + 1
}

func calculateMaterials(
    linearFeet: Double,
    fenceType: FenceType,
    gateCount: GateCount,
    pricing: ContractorPricing
) -> MaterialQuantities {
    guard linearFeet > 0 else {
        return MaterialQuantities(
            posts: 0,
            rails: 0,
            pickets: 0,
            panels: 0,
            postCaps: 0,
            concreteBags: 0,
            hardwareKits: 0,
            walkGates: gateCount.walk,
            driveGates: gateCount.drive
        )
    }
    
    let wasteFactor = 1.0 + (pricing.wastePercent / 100.0)
    let spacing = postSpacing[fenceType] ?? 8.0
    let sections = Int(ceil(linearFeet / spacing))
    
    let posts = calculatePosts(linearFeet: linearFeet, fenceType: fenceType)
    let concreteBags = Int(ceil(Double(posts) * 1.5))
    let rails = Int(ceil(Double(sections) * (railsPerSection[fenceType] ?? 0.0)))
    
    let pickets: Int
    if fenceType == .woodPrivacy || fenceType == .woodPicket {
        let picketsPerFootValue = picketsPerFoot[fenceType] ?? 0.0
        pickets = Int(ceil(linearFeet * picketsPerFootValue * wasteFactor))
    } else {
        pickets = 0
    }
    
    let panels: Int
    if fenceType == .vinyl || fenceType == .aluminum {
        panels = Int(ceil(Double(sections) * wasteFactor))
    } else {
        panels = 0
    }
    
    let hardwareKits = Int(ceil(linearFeet / 50.0))
    
    return MaterialQuantities(
        posts: posts,
        rails: rails,
        pickets: pickets,
        panels: panels,
        postCaps: posts,
        concreteBags: concreteBags,
        hardwareKits: hardwareKits,
        walkGates: gateCount.walk,
        driveGates: gateCount.drive
    )
}

func calculateCosts(
    quantities: MaterialQuantities,
    pricing: ContractorPricing,
    terrain: Terrain,
    linearFeet: Double,
    gateCount: GateCount
) -> CostBreakdown {
    let materialCostRaw =
        Double(quantities.posts) * pricing.postCost +
        Double(quantities.rails) * pricing.railCost +
        Double(quantities.pickets) * pricing.picketCost +
        Double(quantities.panels) * pricing.panelCost +
        Double(quantities.concreteBags) * pricing.concreteCost +
        Double(quantities.hardwareKits) * pricing.hardwareKitCost +
        Double(quantities.walkGates) * pricing.walkGateCost +
        Double(quantities.driveGates) * pricing.driveGateCost
    
    let materialCostMarked = materialCostRaw * (1.0 + pricing.markupPercent / 100.0)
    
    let terrainMult = terrainMultiplier[terrain] ?? 1.0
    let laborCost = linearFeet * pricing.laborRatePerFoot * terrainMult
    
    let gateLabor = Double(gateCount.walk + gateCount.drive) * pricing.gateInstallRate
    
    let total = materialCostMarked + laborCost + gateLabor
    
    let perLinearFoot = linearFeet > 0 ? total / linearFeet : 0.0
    
    return CostBreakdown(
        materialCostRaw: materialCostRaw,
        materialCostMarked: materialCostMarked,
        laborCost: laborCost,
        gateLabor: gateLabor,
        total: total,
        perLinearFoot: perLinearFoot
    )
}

func generateLineItems(
    quantities: MaterialQuantities,
    pricing: ContractorPricing
) -> [MaterialLineItem] {
    var items: [MaterialLineItem] = []
    
    if quantities.posts > 0 {
        items.append(MaterialLineItem(
            label: "Posts (4×4×8)",
            qty: quantities.posts,
            unit: "ea",
            unitCost: pricing.postCost,
            subtotal: Double(quantities.posts) * pricing.postCost
        ))
    }
    
    if quantities.rails > 0 {
        items.append(MaterialLineItem(
            label: "Rails (2×4×8)",
            qty: quantities.rails,
            unit: "ea",
            unitCost: pricing.railCost,
            subtotal: Double(quantities.rails) * pricing.railCost
        ))
    }
    
    if quantities.pickets > 0 {
        items.append(MaterialLineItem(
            label: "Pickets (1×6×6)",
            qty: quantities.pickets,
            unit: "ea",
            unitCost: pricing.picketCost,
            subtotal: Double(quantities.pickets) * pricing.picketCost
        ))
    }
    
    if quantities.panels > 0 {
        items.append(MaterialLineItem(
            label: "Fence Panels",
            qty: quantities.panels,
            unit: "ea",
            unitCost: pricing.panelCost,
            subtotal: Double(quantities.panels) * pricing.panelCost
        ))
    }
    
    if quantities.concreteBags > 0 {
        items.append(MaterialLineItem(
            label: "Concrete (80lb bag)",
            qty: quantities.concreteBags,
            unit: "bags",
            unitCost: pricing.concreteCost,
            subtotal: Double(quantities.concreteBags) * pricing.concreteCost
        ))
    }
    
    if quantities.hardwareKits > 0 {
        items.append(MaterialLineItem(
            label: "Hardware Kit",
            qty: quantities.hardwareKits,
            unit: "kits",
            unitCost: pricing.hardwareKitCost,
            subtotal: Double(quantities.hardwareKits) * pricing.hardwareKitCost
        ))
    }
    
    if quantities.walkGates > 0 {
        items.append(MaterialLineItem(
            label: "Walk Gate",
            qty: quantities.walkGates,
            unit: "ea",
            unitCost: pricing.walkGateCost,
            subtotal: Double(quantities.walkGates) * pricing.walkGateCost
        ))
    }
    
    if quantities.driveGates > 0 {
        items.append(MaterialLineItem(
            label: "Drive Gate",
            qty: quantities.driveGates,
            unit: "ea",
            unitCost: pricing.driveGateCost,
            subtotal: Double(quantities.driveGates) * pricing.driveGateCost
        ))
    }
    
    return items
}

func runEstimate(
    linearFeet: Double,
    fenceType: FenceType,
    gateCount: GateCount,
    terrain: Terrain,
    pricing: ContractorPricing
) -> EstimateResult {
    let quantities = calculateMaterials(
        linearFeet: linearFeet,
        fenceType: fenceType,
        gateCount: gateCount,
        pricing: pricing
    )
    
    let costs = calculateCosts(
        quantities: quantities,
        pricing: pricing,
        terrain: terrain,
        linearFeet: linearFeet,
        gateCount: gateCount
    )
    
    let lineItems = generateLineItems(
        quantities: quantities,
        pricing: pricing
    )
    
    return EstimateResult(
        quantities: quantities,
        costs: costs,
        lineItems: lineItems
    )
}

// ─────────────────────────────────────────────
// QUOTE & FORMATTING (pure, no side effects)
// ─────────────────────────────────────────────

func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? "$0"
}

private func fenceTypeLabel(_ t: FenceType) -> String {
    switch t {
    case .woodPrivacy: return "Wood Privacy"
    case .woodPicket: return "Wood Picket"
    case .chainLink: return "Chain Link"
    case .vinyl: return "Vinyl"
    case .aluminum: return "Aluminum"
    case .splitRail: return "Split Rail"
    }
}

private func terrainLabel(_ t: Terrain) -> String {
    switch t {
    case .flat: return "Flat"
    case .slope: return "Slope"
    case .hilly: return "Hilly"
    }
}

func generateQuoteText(
    estimate: EstimateResult,
    linearFeet: Double,
    fenceType: FenceType,
    gateCount: GateCount,
    terrain: Terrain,
    contractorName: String
) -> String {
    let costs = estimate.costs
    let date = Date()
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    let dateStr = formatter.string(from: date)
    let totalGates = gateCount.walk + gateCount.drive
    let gateStr = totalGates > 0 ? "\(gateCount.walk) walk, \(gateCount.drive) drive" : "None"
    let company = contractorName.isEmpty ? "YOUR FENCE CO." : contractorName.uppercased()
    return """
    ═══════════════════════════════
             FENCE ESTIMATE
    \(company)
    Date: \(dateStr)
    ═══════════════════════════════
    Fence Type: \(fenceTypeLabel(fenceType))
    Linear Feet: \(Int(linearFeet)) LF
    Gates: \(gateStr)
    Terrain: \(terrainLabel(terrain))
    ───────────────────────────────
    Materials:          \(formatCurrency(costs.materialCostMarked))
    Labor:              \(formatCurrency(costs.laborCost + costs.gateLabor))
    ───────────────────────────────
    TOTAL INSTALLED:    \(formatCurrency(costs.total))
    Per Linear Foot:    \(formatCurrency(costs.perLinearFoot))/ft
    ═══════════════════════════════
    Valid for 30 days
    """
}

func generateSupplierList(estimate: EstimateResult, contractorName: String) -> String {
    let rows = estimate.lineItems.map { item in
        "\(item.label)\t\(item.qty) \(item.unit)\t@ \(formatCurrency(item.unitCost))\t= \(formatCurrency(item.subtotal))"
    }
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    let dateStr = formatter.string(from: Date())
    let header = contractorName.isEmpty ? "" : "For: \(contractorName)"
    return (["MATERIAL ORDER — \(dateStr)", header, String(repeating: "─", count: 60)] + rows + [String(repeating: "─", count: 60), "TOTAL MATERIALS:    \(formatCurrency(estimate.costs.materialCostRaw))"]).filter { !$0.isEmpty }.joined(separator: "\n")
}
