// ============================================================
// FenceCalculator.swift
// Real calculation engine — provable formulas, no placeholders.
// ============================================================

import Foundation

// MARK: - Fence-type constants (Wood Privacy = reference)

/// Post spacing in feet between posts.
let postSpacing: [FenceType: Double] = [
    .woodPrivacy: 8.0,
    .woodPicket: 8.0,
    .chainLink: 10.0,
    .vinyl: 8.0,
    .aluminum: 8.0,
    .splitRail: 8.0
]

/// Rails per section (between two posts).
let railsPerSection: [FenceType: Double] = [
    .woodPrivacy: 3.0,
    .woodPicket: 3.0,
    .chainLink: 1.0,
    .splitRail: 2.0,
    .vinyl: 0.0,
    .aluminum: 0.0
]

/// Pickets per linear foot of fence.
let picketsPerFoot: [FenceType: Double] = [
    .woodPrivacy: 2.0,
    .woodPicket: 1.5,
    .chainLink: 0.0,
    .vinyl: 0.0,
    .aluminum: 0.0,
    .splitRail: 0.0
]

/// Bags of concrete per post (e.g. 1.5 = 1–2 bags per post).
let concreteBagsPerPost: [FenceType: Double] = [
    .woodPrivacy: 1.5,
    .woodPicket: 1.5,
    .chainLink: 1.5,
    .vinyl: 1.5,
    .aluminum: 1.5,
    .splitRail: 1.5
]

/// Labor hours per linear foot of fence.
let laborHoursPerLinearFoot: [FenceType: Double] = [
    .woodPrivacy: 0.25,
    .woodPicket: 0.22,
    .chainLink: 0.15,
    .vinyl: 0.20,
    .aluminum: 0.20,
    .splitRail: 0.18
]

/// Labor hours per walk gate install.
let laborHoursPerWalkGate: Double = 2.0

/// Labor hours per drive gate install.
let laborHoursPerDriveGate: Double = 4.0

/// Terrain multiplier for labor: Flat 1.0x, Sloped 1.25x, Difficult/Rocky 1.5x.
let terrainMultiplier: [Terrain: Double] = [
    .flat: 1.0,
    .slope: 1.25,
    .difficult: 1.5
]

/// Rounds value up to the nearest step (e.g. roundUpToNearest(1234, 25) → 1250).
func roundUpToNearest(_ value: Double, _ step: Double) -> Double {
    guard step > 0 else { return value }
    return ceil(value / step) * step
}

/// Max rail section length for wood (ft). Sections longer than this are split to prevent sagging.
let maxWoodRailSectionLength: Double = 8.0

/// Splits a run into segments of at most maxLen (e.g. 10ft → [5, 5] for wood).
func normalizedStretchLengths(length: Double, fenceType: FenceType, maxSectionLength: Double = maxWoodRailSectionLength) -> [Double] {
    guard length > 0 else { return [] }
    let isWood = fenceType == .woodPrivacy || fenceType == .woodPicket || fenceType == .splitRail
    let maxLen = isWood ? min(maxSectionLength, postSpacing[fenceType] ?? 8.0) : (postSpacing[fenceType] ?? 8.0)
    if length <= maxLen { return [length] }
    var segments: [Double] = []
    var remaining = length
    while remaining > 0 {
        let segment = min(remaining, maxLen)
        segments.append(segment)
        remaining -= segment
    }
    return segments
}

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

enum Terrain: String, CaseIterable, Codable {
    case flat
    case slope
    case difficult  // Difficult/Rocky — 1.5x labor
}

/// Section length: 8ft Standard or 6ft Heavy Duty.
enum SectionLength: Double, CaseIterable, Codable {
    case standard8ft = 8.0
    case heavyDuty6ft = 6.0
}

/// Layout geometry for takeoff: corners, termination, section length.
struct LayoutDetails {
    var corners90: Int
    var endsAtHouse: Bool
    var sectionLength: SectionLength
}

struct GateCount {
    let walk: Int
    let drive: Int
}

// MARK: - Stretch-based fence layout (how fences are actually built)
/// A single continuous "run" of fence. Terminals (ends/corners/gate posts) are counted separately.
struct FenceRun: Equatable {
    var length: Double
    var isCorner: Bool  // run ends at a corner (shared post with next run)
    var isEnd: Bool     // run ends at job boundary (not shared)
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
    /// Margin-first: Price = Cost / (1 - margin). Default 0.30 = 30% margin.
    var desiredMarginPercent: Double
    var wastePercent: Double
    var overheadEnabled: Bool
    var overheadPercent: Double
    var hourlyRate: Double
    var laborHoursPerLinearFoot: Double
    var laborHoursPerWalkGate: Double
    var laborHoursPerDriveGate: Double
    /// Line post (4×4×8 PT) — used when quantities have linePostCount.
    var linePostCost: Double
    /// Terminal post (6×6×8 PT) — ends, corners, gate posts.
    var terminalPostCost: Double
    /// Gate hardware kit $ per gate (added to material subtotal per gate).
    var gateHardwarePerGate: Double

    /// 2026 Smyrna TN Wood Privacy defaults.
    static let `default` = ContractorPricing(
        postCost: 16.50,
        railCost: 8.00,
        picketCost: 2.50,
        panelCost: 45.00,
        concreteCost: 10.50,
        hardwareKitCost: 35.00,
        walkGateCost: 85.00,
        driveGateCost: 225.00,
        laborRatePerFoot: 18.50,
        gateInstallRate: 75.00,
        markupPercent: 20.0,
        desiredMarginPercent: 30.0,
        wastePercent: 10.0,
        overheadEnabled: false,
        overheadPercent: 10.0,
        hourlyRate: 50.00,
        laborHoursPerLinearFoot: 0.25,
        laborHoursPerWalkGate: 2.0,
        laborHoursPerDriveGate: 4.0,
        linePostCost: 16.50,
        terminalPostCost: 38.00,
        gateHardwarePerGate: 65.00
    )

    init(postCost: Double, railCost: Double, picketCost: Double, panelCost: Double,
         concreteCost: Double, hardwareKitCost: Double, walkGateCost: Double, driveGateCost: Double,
         laborRatePerFoot: Double, gateInstallRate: Double, markupPercent: Double, desiredMarginPercent: Double, wastePercent: Double,
         overheadEnabled: Bool, overheadPercent: Double,
         hourlyRate: Double, laborHoursPerLinearFoot: Double, laborHoursPerWalkGate: Double, laborHoursPerDriveGate: Double,
         linePostCost: Double, terminalPostCost: Double, gateHardwarePerGate: Double) {
        self.postCost = postCost
        self.railCost = railCost
        self.picketCost = picketCost
        self.panelCost = panelCost
        self.concreteCost = concreteCost
        self.hardwareKitCost = hardwareKitCost
        self.walkGateCost = walkGateCost
        self.driveGateCost = driveGateCost
        self.laborRatePerFoot = laborRatePerFoot
        self.gateInstallRate = gateInstallRate
        self.markupPercent = markupPercent
        self.desiredMarginPercent = desiredMarginPercent
        self.wastePercent = wastePercent
        self.overheadEnabled = overheadEnabled
        self.overheadPercent = overheadPercent
        self.hourlyRate = hourlyRate
        self.laborHoursPerLinearFoot = laborHoursPerLinearFoot
        self.laborHoursPerWalkGate = laborHoursPerWalkGate
        self.laborHoursPerDriveGate = laborHoursPerDriveGate
        self.linePostCost = linePostCost
        self.terminalPostCost = terminalPostCost
        self.gateHardwarePerGate = gateHardwarePerGate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        postCost = try c.decode(Double.self, forKey: .postCost)
        railCost = try c.decode(Double.self, forKey: .railCost)
        picketCost = try c.decode(Double.self, forKey: .picketCost)
        panelCost = try c.decode(Double.self, forKey: .panelCost)
        concreteCost = try c.decode(Double.self, forKey: .concreteCost)
        hardwareKitCost = try c.decode(Double.self, forKey: .hardwareKitCost)
        walkGateCost = try c.decode(Double.self, forKey: .walkGateCost)
        driveGateCost = try c.decode(Double.self, forKey: .driveGateCost)
        laborRatePerFoot = try c.decode(Double.self, forKey: .laborRatePerFoot)
        gateInstallRate = try c.decode(Double.self, forKey: .gateInstallRate)
        markupPercent = try c.decode(Double.self, forKey: .markupPercent)
        desiredMarginPercent = try c.decodeIfPresent(Double.self, forKey: .desiredMarginPercent) ?? 30.0
        wastePercent = try c.decode(Double.self, forKey: .wastePercent)
        overheadEnabled = try c.decodeIfPresent(Bool.self, forKey: .overheadEnabled) ?? false
        overheadPercent = try c.decodeIfPresent(Double.self, forKey: .overheadPercent) ?? 10.0
        hourlyRate = try c.decodeIfPresent(Double.self, forKey: .hourlyRate) ?? 50.0
        laborHoursPerLinearFoot = try c.decodeIfPresent(Double.self, forKey: .laborHoursPerLinearFoot) ?? 0.25
        laborHoursPerWalkGate = try c.decodeIfPresent(Double.self, forKey: .laborHoursPerWalkGate) ?? 2.0
        laborHoursPerDriveGate = try c.decodeIfPresent(Double.self, forKey: .laborHoursPerDriveGate) ?? 4.0
        linePostCost = try c.decodeIfPresent(Double.self, forKey: .linePostCost) ?? postCost
        terminalPostCost = try c.decodeIfPresent(Double.self, forKey: .terminalPostCost) ?? postCost
        gateHardwarePerGate = try c.decodeIfPresent(Double.self, forKey: .gateHardwarePerGate) ?? 65.0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(postCost, forKey: .postCost)
        try c.encode(railCost, forKey: .railCost)
        try c.encode(picketCost, forKey: .picketCost)
        try c.encode(panelCost, forKey: .panelCost)
        try c.encode(concreteCost, forKey: .concreteCost)
        try c.encode(hardwareKitCost, forKey: .hardwareKitCost)
        try c.encode(walkGateCost, forKey: .walkGateCost)
        try c.encode(driveGateCost, forKey: .driveGateCost)
        try c.encode(laborRatePerFoot, forKey: .laborRatePerFoot)
        try c.encode(gateInstallRate, forKey: .gateInstallRate)
        try c.encode(markupPercent, forKey: .markupPercent)
        try c.encode(desiredMarginPercent, forKey: .desiredMarginPercent)
        try c.encode(wastePercent, forKey: .wastePercent)
        try c.encode(overheadEnabled, forKey: .overheadEnabled)
        try c.encode(overheadPercent, forKey: .overheadPercent)
        try c.encode(hourlyRate, forKey: .hourlyRate)
        try c.encode(laborHoursPerLinearFoot, forKey: .laborHoursPerLinearFoot)
        try c.encode(laborHoursPerWalkGate, forKey: .laborHoursPerWalkGate)
        try c.encode(laborHoursPerDriveGate, forKey: .laborHoursPerDriveGate)
        try c.encode(linePostCost, forKey: .linePostCost)
        try c.encode(terminalPostCost, forKey: .terminalPostCost)
        try c.encode(gateHardwarePerGate, forKey: .gateHardwarePerGate)
    }

    private enum CodingKeys: String, CodingKey {
        case postCost, railCost, picketCost, panelCost, concreteCost, hardwareKitCost
        case walkGateCost, driveGateCost, laborRatePerFoot, gateInstallRate
        case markupPercent, desiredMarginPercent, wastePercent, overheadEnabled, overheadPercent
        case hourlyRate, laborHoursPerLinearFoot, laborHoursPerWalkGate, laborHoursPerDriveGate
        case linePostCost, terminalPostCost, gateHardwarePerGate
    }
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
    /// Line posts (4×4 intermediate). Used for assembly takeoff.
    let linePostCount: Int
    /// Terminal posts (ends, corners, gate posts — often 6×6, 1.5× concrete).
    let terminalPostCount: Int
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
    let overheadAmount: Double
    let total: Double
    let perLinearFoot: Double
    let laborHours: Double
    let subtotalBeforeMarkup: Double
    /// Sales tax (Smyrna TN 9.75%) on materials only.
    let salesTaxAmount: Double
    /// Total cost (materials + tax + labor) before margin — for profit display.
    var totalCost: Double { subtotalBeforeMarkup }
    /// Estimated profit: FinalPrice - TotalCost.
    var estimatedProfit: Double { total - subtotalBeforeMarkup }
    var finalPrice: Double { total }
    var markupAmount: Double { materialCostMarked - materialCostRaw }
    func profitAmount(rawMaterial: Double) -> Double {
        total - rawMaterial - laborCost - gateLabor - overheadAmount
    }
    func profitPercent(rawMaterial: Double) -> Double {
        let costBeforeProfit = rawMaterial + laborCost + gateLabor + overheadAmount
        guard costBeforeProfit > 0 else { return 0 }
        return (total - costBeforeProfit) / costBeforeProfit * 100
    }
}

struct EstimateResult {
    let quantities: MaterialQuantities
    let costs: CostBreakdown
    let lineItems: [MaterialLineItem]
}

// ─────────────────────────────────────────────
// STRETCH-BASED POST LOGIC
// ─────────────────────────────────────────────
// Formula: total_posts = (∑ ceil(Li/S)) + 1 + N_gates*2 − N_shared_corners.
// Line posts = interior posts; terminal posts = ends, corners, gate posts (1.5× concrete).

/// Returns (linePostCount, terminalPostCount, totalPosts, sectionCount, totalLinearFeet) from runs.
/// Formula: total_posts = (∑ ceil(Li/S)) + 1 + N_gates*2 − N_shared_corners. Terminal = ends + gate posts.
func calculatePostsFromRuns(
    runs: [FenceRun],
    fenceType: FenceType,
    gateCount: GateCount,
    sharedCornerCount: Int
) -> (linePosts: Int, terminalPosts: Int, totalPosts: Int, sections: Int, totalLinearFeet: Double) {
    let spacing = postSpacing[fenceType] ?? 8.0
    let gatePosts = 2 * (gateCount.walk + gateCount.drive)
    var totalLinearFeet: Double = 0
    var sections = 0

    for run in runs {
        let segments = normalizedStretchLengths(length: run.length, fenceType: fenceType)
        for seg in segments {
            guard seg > 0 else { continue }
            totalLinearFeet += seg
            sections += Int(ceil(seg / spacing))
        }
    }

    // total_posts = sections + 1 + gatePosts - sharedCornerCount
    let totalPosts = sections + 1 + gatePosts - sharedCornerCount
    // Terminal posts = 2 ends per run − shared corners + 2 per gate (each gate has 2 posts)
    let terminalCount = 2 * runs.count - sharedCornerCount + gatePosts
    let clampedTerminal = min(max(0, terminalCount), totalPosts)
    let clampedLine = max(0, totalPosts - clampedTerminal)
    return (clampedLine, clampedTerminal, totalPosts, sections, totalLinearFeet)
}

/// Single-run convenience: one stretch of linearFeet, no shared corners, no gates in count (gates added separately).
func calculatePosts(linearFeet: Double, fenceType: FenceType) -> Int {
    guard linearFeet > 0 else { return 0 }
    let spacing = postSpacing[fenceType] ?? 8.0
    let segments = normalizedStretchLengths(length: linearFeet, fenceType: fenceType)
    let sections = segments.reduce(0) { $0 + Int(ceil($1 / spacing)) }
    return sections + 1
}

func calculateSections(linearFeet: Double, fenceType: FenceType) -> Int {
    guard linearFeet > 0 else { return 0 }
    let spacing = postSpacing[fenceType] ?? 8.0
    let segments = normalizedStretchLengths(length: linearFeet, fenceType: fenceType)
    return segments.reduce(0) { $0 + Int(ceil($1 / spacing)) }
}

/// 2026 structural: line posts 2 bags (80lb) per hole; terminal/gate 3.5 bags per hole.
let concreteBagsPerLinePostTakeoff: Double = 2.0
let concreteBagsPerTerminalPostTakeoff: Double = 3.5

/// Smyrna, TN sales tax (9.75%). Applied to materials subtotal only.
let smyrnaTNSalesTaxRate: Double = 0.0975

/// Material waste buffer on wood products (Rails, Pickets) — 10%.
let materialWasteFactorWood: Double = 0.10

/// Layout-based takeoff (construction standard):
/// TotalIntervals = ceil(linearFeet / sectionLength)
/// TerminalPosts = (Corners×1) + (WalkGates×2) + (DriveGates×2) + (EndsAtHouse ? 0 : 1)
/// LinePosts = TotalIntervals + 1 - TerminalPosts
/// Concrete: 2 bags per line post, 3.5 per terminal/gate post.
func calculatePostsAndConcreteFromLayout(
    linearFeet: Double,
    gateCount: GateCount,
    layout: LayoutDetails
) -> (linePosts: Int, terminalPosts: Int, concreteBags: Int) {
    guard linearFeet > 0 else {
        return (0, 0, 0)
    }
    let sectionLength = layout.sectionLength.rawValue
    let totalIntervals = Int(ceil(linearFeet / sectionLength))
    let terminalPosts =
        layout.corners90 * 1 +
        gateCount.walk * 2 +
        gateCount.drive * 2 +
        (layout.endsAtHouse ? 0 : 1)
    let totalPosts = totalIntervals + 1
    let terminalClamped = min(max(0, terminalPosts), totalPosts)
    let linePosts = max(0, totalPosts - terminalClamped)
    let concreteBags = Int(ceil(Double(linePosts) * concreteBagsPerLinePostTakeoff + Double(terminalClamped) * concreteBagsPerTerminalPostTakeoff))
    return (linePosts, terminalClamped, concreteBags)
}

/// Single-run path: builds one FenceRun and delegates to stretch logic.
/// When layout is provided, uses layout-based post/concrete formulas instead.
func calculateMaterials(
    linearFeet: Double,
    fenceType: FenceType,
    gateCount: GateCount,
    pricing: ContractorPricing,
    layout: LayoutDetails? = nil
) -> MaterialQuantities {
    if let layout = layout, linearFeet > 0 {
        let (linePosts, terminalPosts, concreteBags) = calculatePostsAndConcreteFromLayout(
            linearFeet: linearFeet,
            gateCount: gateCount,
            layout: layout
        )
        let totalPosts = linePosts + terminalPosts
        let spacing = layout.sectionLength.rawValue
        let sections = Int(ceil(linearFeet / spacing))
        let railsPerSec = railsPerSection[fenceType] ?? 0.0
        let picketsPerFt = picketsPerFoot[fenceType] ?? 0.0
        let wasteFactor = pricing.wastePercent / 100.0
        let rails = Int(ceil(Double(sections) * railsPerSec))
        let pickets = picketsPerFt > 0
            ? Int(ceil(linearFeet * picketsPerFt * (1.0 + wasteFactor)))
            : 0
        let hardwareKits = Int(ceil(linearFeet / 50.0))
        return MaterialQuantities(
            posts: totalPosts,
            rails: rails,
            pickets: pickets,
            panels: 0,
            postCaps: totalPosts,
            concreteBags: concreteBags,
            hardwareKits: hardwareKits,
            walkGates: gateCount.walk,
            driveGates: gateCount.drive,
            linePostCount: linePosts,
            terminalPostCount: terminalPosts
        )
    }
    let runs = linearFeet > 0 ? [FenceRun(length: linearFeet, isCorner: false, isEnd: true)] : []
    return calculateMaterialsFromRuns(
        runs: runs,
        fenceType: fenceType,
        gateCount: gateCount,
        sharedCornerCount: 0,
        pricing: pricing
    )
}

/// Stretch-based material takeoff. Terminal posts get 1.5× concrete.
func calculateMaterialsFromRuns(
    runs: [FenceRun],
    fenceType: FenceType,
    gateCount: GateCount,
    sharedCornerCount: Int,
    pricing: ContractorPricing
) -> MaterialQuantities {
    var (linePosts, terminalPosts, totalPosts, sections, totalLinearFeet) = calculatePostsFromRuns(
        runs: runs,
        fenceType: fenceType,
        gateCount: gateCount,
        sharedCornerCount: sharedCornerCount
    )

    let isWoodPrivacy = (fenceType == .woodPrivacy)
    if isWoodPrivacy {
        // For every walk gate: add 2 terminal posts, remove 2 line posts.
        let swap = 2 * gateCount.walk
        terminalPosts += swap
        linePosts = max(0, linePosts - swap)
    }

    guard totalLinearFeet > 0 else {
        return MaterialQuantities(
            posts: 0,
            rails: 0,
            pickets: 0,
            panels: 0,
            postCaps: 0,
            concreteBags: 0,
            hardwareKits: 0,
            walkGates: gateCount.walk,
            driveGates: gateCount.drive,
            linePostCount: 0,
            terminalPostCount: 0
        )
    }

    let railsPerSec = railsPerSection[fenceType] ?? 0.0
    let picketsPerFt = picketsPerFoot[fenceType] ?? 0.0
    let wasteFactor = pricing.wastePercent / 100.0

    let rails = Int(ceil(Double(sections) * railsPerSec))
    let pickets = picketsPerFt > 0
        ? Int(ceil(totalLinearFeet * picketsPerFt * (1.0 + wasteFactor)))
        : 0
    let concreteBags = Int(ceil(Double(linePosts) * concreteBagsPerLinePostTakeoff + Double(terminalPosts) * concreteBagsPerTerminalPostTakeoff))

    let panels: Int
    if fenceType == .vinyl || fenceType == .aluminum {
        panels = Int(ceil(Double(sections) * (1.0 + wasteFactor)))
    } else {
        panels = 0
    }

    let hardwareKits = Int(ceil(totalLinearFeet / 50.0))

    return MaterialQuantities(
        posts: totalPosts,
        rails: rails,
        pickets: pickets,
        panels: panels,
        postCaps: totalPosts,
        concreteBags: concreteBags,
        hardwareKits: hardwareKits,
        walkGates: gateCount.walk,
        driveGates: gateCount.drive,
        linePostCount: linePosts,
        terminalPostCount: terminalPosts
    )
}

/// MaterialCost = sum(quantity × unitPrice); optional regional multipliers apply market index.
/// Labor cost × terrain; optional regional labor index.
/// FinalPrice: margin-first Cost/(1−margin) or markup fallback, rounded to $25.
func calculateCosts(
    quantities: MaterialQuantities,
    pricing: ContractorPricing,
    terrain: Terrain,
    linearFeet: Double,
    gateCount: GateCount,
    fenceType: FenceType,
    regional: RegionalMultipliers? = nil
) -> CostBreakdown {
    let lineCost = pricing.linePostCost > 0 ? pricing.linePostCost : pricing.postCost
    let termCost = pricing.terminalPostCost > 0 ? pricing.terminalPostCost : pricing.postCost
    let postMaterial = (quantities.linePostCount > 0 || quantities.terminalPostCount > 0)
        ? (Double(quantities.linePostCount) * lineCost + Double(quantities.terminalPostCount) * termCost)
        : (Double(quantities.posts) * pricing.postCost)
    let gateHardware = Double(quantities.walkGates + quantities.driveGates) * pricing.gateHardwarePerGate
    let woodSubtotal = Double(quantities.rails) * pricing.railCost + Double(quantities.pickets) * pricing.picketCost
    let woodWasteAmount = woodSubtotal * materialWasteFactorWood
    var materialCostRaw =
        postMaterial +
        Double(quantities.rails) * pricing.railCost +
        Double(quantities.pickets) * pricing.picketCost +
        woodWasteAmount +
        Double(quantities.panels) * pricing.panelCost +
        Double(quantities.concreteBags) * pricing.concreteCost +
        Double(quantities.hardwareKits) * pricing.hardwareKitCost +
        Double(quantities.walkGates) * pricing.walkGateCost +
        Double(quantities.driveGates) * pricing.driveGateCost +
        gateHardware

    if let r = regional {
        materialCostRaw *= r.materialIndex
    }

    let salesTaxAmount = materialCostRaw * smyrnaTNSalesTaxRate
    let materialWithTax = materialCostRaw + salesTaxAmount

    let terrainMult = terrainMultiplier[terrain] ?? 1.0
    let laborHours: Double
    var laborCost: Double
    var gateLabor: Double

    if pricing.hourlyRate > 0 {
        laborHours =
            (linearFeet * pricing.laborHoursPerLinearFoot) +
            (Double(gateCount.walk) * pricing.laborHoursPerWalkGate) +
            (Double(gateCount.drive) * pricing.laborHoursPerDriveGate)
        let laborHoursAdjusted = laborHours * terrainMult
        laborCost = laborHoursAdjusted * pricing.hourlyRate
        gateLabor = 0
    } else {
        laborHours = 0
        laborCost = linearFeet * pricing.laborRatePerFoot * terrainMult
        gateLabor = Double(gateCount.walk + gateCount.drive) * pricing.gateInstallRate
    }

    if let r = regional {
        laborCost *= r.laborIndex
        gateLabor *= r.laborIndex
    }

    // BaseCost = (Materials × 1.0975) + Labor; then FinalPrice = BaseCost / (1 - margin).
    let baseCost = materialWithTax + laborCost + gateLabor
    let finalPrice: Double
    if pricing.desiredMarginPercent > 0 && pricing.desiredMarginPercent < 100 {
        let margin = pricing.desiredMarginPercent / 100.0
        finalPrice = roundUpToNearest(baseCost / (1.0 - margin), 25)
    } else {
        finalPrice = roundUpToNearest(baseCost * (1.0 + pricing.markupPercent / 100.0), 25)
    }

    let overheadAmount: Double
    if pricing.overheadEnabled {
        overheadAmount = finalPrice * (pricing.overheadPercent / 100.0)
    } else {
        overheadAmount = 0
    }
    let total = finalPrice + overheadAmount
    let perLinearFoot = linearFeet > 0 ? total / linearFeet : 0.0

    return CostBreakdown(
        materialCostRaw: materialCostRaw,
        materialCostMarked: materialCostRaw,
        laborCost: laborCost,
        gateLabor: gateLabor,
        overheadAmount: overheadAmount,
        total: total,
        perLinearFoot: perLinearFoot,
        laborHours: laborHours * terrainMult,
        subtotalBeforeMarkup: baseCost,
        salesTaxAmount: salesTaxAmount
    )
}

func generateLineItems(
    quantities: MaterialQuantities,
    pricing: ContractorPricing
) -> [MaterialLineItem] {
    var items: [MaterialLineItem] = []
    
    if quantities.linePostCount > 0 {
        let cost = pricing.linePostCost > 0 ? pricing.linePostCost : pricing.postCost
        items.append(MaterialLineItem(
            label: "Line Post (4×4×8 PT)",
            qty: quantities.linePostCount,
            unit: "ea",
            unitCost: cost,
            subtotal: Double(quantities.linePostCount) * cost
        ))
    }
    if quantities.terminalPostCount > 0 {
        let cost = pricing.terminalPostCost > 0 ? pricing.terminalPostCost : pricing.postCost
        items.append(MaterialLineItem(
            label: "Terminal Post (6×6×8 PT)",
            qty: quantities.terminalPostCount,
            unit: "ea",
            unitCost: cost,
            subtotal: Double(quantities.terminalPostCount) * cost
        ))
    }
    if quantities.posts > 0 && quantities.linePostCount == 0 && quantities.terminalPostCount == 0 {
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
    let woodSubtotal = Double(quantities.rails) * pricing.railCost + Double(quantities.pickets) * pricing.picketCost
    if woodSubtotal > 0 {
        let wasteAmount = woodSubtotal * materialWasteFactorWood
        items.append(MaterialLineItem(
            label: "Material Waste (10%)",
            qty: 1,
            unit: "—",
            unitCost: wasteAmount,
            subtotal: wasteAmount
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
    let totalGates = quantities.walkGates + quantities.driveGates
    if totalGates > 0 && pricing.gateHardwarePerGate > 0 {
        items.append(MaterialLineItem(
            label: "Gate Hardware Kit",
            qty: totalGates,
            unit: "ea",
            unitCost: pricing.gateHardwarePerGate,
            subtotal: Double(totalGates) * pricing.gateHardwarePerGate
        ))
    }

    return items
}

private let defaultZipService = ZipCodeService(table: .defaultUS)

func runEstimate(
    linearFeet: Double,
    fenceType: FenceType,
    gateCount: GateCount,
    terrain: Terrain,
    pricing: ContractorPricing,
    zipCode: String? = nil,
    layout: LayoutDetails? = nil
) -> EstimateResult {
    let regional = zipCode.flatMap { defaultZipService.regionalMultipliers(zipCode: $0) }
    let quantities = calculateMaterials(
        linearFeet: linearFeet,
        fenceType: fenceType,
        gateCount: gateCount,
        pricing: pricing,
        layout: layout
    )
    
    let costs = calculateCosts(
        quantities: quantities,
        pricing: pricing,
        terrain: terrain,
        linearFeet: linearFeet,
        gateCount: gateCount,
        fenceType: fenceType,
        regional: regional
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

func fenceTypeLabel(_ t: FenceType) -> String {
    switch t {
    case .woodPrivacy: return "Wood Privacy"
    case .woodPicket: return "Wood Picket"
    case .chainLink: return "Chain Link"
    case .vinyl: return "Vinyl"
    case .aluminum: return "Aluminum"
    case .splitRail: return "Split Rail"
    }
}

func terrainLabel(_ t: Terrain) -> String {
    switch t {
    case .flat: return "Flat"
    case .slope: return "Sloped (1.25× labor)"
    case .difficult: return "Difficult/Rocky (1.5× labor)"
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
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    let dateStr = formatter.string(from: Date())
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
