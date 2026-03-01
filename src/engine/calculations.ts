// ============================================================
// FenceQuote — Core Calculation Engine
// src/engine/calculations.ts
//
// RULES:
// - Pure functions only. No React. No state. No side effects.
// - All math is deterministic and rule-based.
// - Every function is independently unit-testable.
// - WASTE_FACTOR and POST_SPACING are the only magic numbers.
// ============================================================

export type FenceType =
  | 'chain_link'
  | 'wood_privacy'
  | 'wood_picket'
  | 'vinyl'
  | 'aluminum'
  | 'split_rail'
  | 'custom';

export type Terrain = 'flat' | 'slope' | 'hilly';

export interface GateCount {
  walk: number;
  drive: number;
}

export interface JobInputs {
  fenceType: FenceType;
  linearFeet: number;
  gateCount: GateCount;
  terrain: Terrain;
  pricing: ContractorPricing;
}

/** Geo-pricing: regional multipliers and optional location for tax. */
export interface RegionalContext {
  laborMultiplier: number;
  materialMultiplier: number;
  salesTaxRate: number;   // decimal, e.g. 0.0975 for 9.75%
  marginPercent: number;  // e.g. 30 for 30% margin
}

export interface ContractorPricing {
  // Material unit costs (what contractor pays supplier)
  postCost: number;
  railCost: number;
  picketCost: number;
  panelCost: number;
  concreteCost: number;
  hardwareKitCost: number;
  walkGateCost: number;
  driveGateCost: number;

  // Labor
  laborRatePerFoot: number;
  gateInstallRate: number;

  // Overhead
  markupPercent: number;   // applied to materials only
  wastePercent: number;    // applied to pickets/panels quantity
}

export interface MaterialQuantities {
  posts: number;
  rails: number;
  pickets: number;
  panels: number;
  postCaps: number;
  concreteBags: number;
  hardwareKits: number;
  walkGates: number;
  driveGates: number;
  linearFeet: number;
  fenceType: FenceType;
}

export interface MaterialLineItem {
  label: string;
  qty: number;
  unit: string;
  unitCost: number;
  subtotal: number;
}

export interface CostBreakdown {
  materialCostRaw: number;      // before markup
  materialCostMarked: number;   // after markup
  laborCost: number;
  gateLabor: number;
  subtotal: number;
  total: number;
  perLinearFoot: number;
  terrainMultiplier: number;
}

export interface EstimateResult {
  inputs: JobInputs;
  quantities: MaterialQuantities;
  costs: CostBreakdown;
  lineItems: MaterialLineItem[];
}

// ─────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────

export const POST_SPACING_FT: Record<FenceType, number> = {
  chain_link:   10,
  wood_privacy:  8,
  wood_picket:   8,
  vinyl:         8,
  aluminum:      8,
  split_rail:    8,
  custom:        8,
};

export const TERRAIN_MULTIPLIER: Record<Terrain, number> = {
  flat:  1.00,
  slope: 1.15,
  hilly: 1.30,
};

// Pickets per linear foot (before waste)
const PICKETS_PER_FOOT: Record<FenceType, number> = {
  wood_privacy: 2.0,    // 6" pickets, tight (no gap)
  wood_picket:  1.5,    // 6" pickets, small gap
  chain_link:   0,
  vinyl:        0,
  aluminum:     0,
  split_rail:   0,
  custom:       1.5,
};

// Rails per section (section = post_spacing)
const RAILS_PER_SECTION: Record<FenceType, number> = {
  wood_privacy:  3,
  wood_picket:   3,
  vinyl:         0,      // panels include rails
  aluminum:      0,
  chain_link:    1,      // top rail only
  split_rail:    2,
  custom:        3,
};

export const DEFAULT_PRICING: ContractorPricing = {
  postCost:         12.00,
  railCost:          8.00,
  picketCost:        2.50,
  panelCost:        45.00,
  concreteCost:      7.00,
  hardwareKitCost:  35.00,
  walkGateCost:     85.00,
  driveGateCost:   225.00,
  laborRatePerFoot:  8.00,
  gateInstallRate:  75.00,
  markupPercent:    20,
  wastePercent:     10,
};

// ─────────────────────────────────────────────
// GEO-PRICING: Regional multipliers & sales tax
// ─────────────────────────────────────────────

export type StateCode = string; // e.g. 'TN', 'NY'

export const RegionalPricingMap: Record<string, { laborMultiplier: number; materialMultiplier: number }> = {
  // High-cost
  NY: { laborMultiplier: 1.35, materialMultiplier: 1.2 },
  CA: { laborMultiplier: 1.35, materialMultiplier: 1.2 },
  WA: { laborMultiplier: 1.35, materialMultiplier: 1.2 },
  MA: { laborMultiplier: 1.35, materialMultiplier: 1.2 },
  // Standard
  TN: { laborMultiplier: 1.0, materialMultiplier: 1.0 },
  TX: { laborMultiplier: 1.0, materialMultiplier: 1.0 },
  FL: { laborMultiplier: 1.0, materialMultiplier: 1.0 },
  GA: { laborMultiplier: 1.0, materialMultiplier: 1.0 },
  // Rural / low-cost
  MS: { laborMultiplier: 0.85, materialMultiplier: 0.95 },
  WV: { laborMultiplier: 0.85, materialMultiplier: 0.95 },
  AR: { laborMultiplier: 0.85, materialMultiplier: 0.95 },
};

const NATIONAL_AVERAGE = { laborMultiplier: 1.0, materialMultiplier: 1.0 };

export function getRegionalMultipliers(stateCode: StateCode | null): { laborMultiplier: number; materialMultiplier: number } {
  if (!stateCode) return NATIONAL_AVERAGE;
  const key = stateCode.toUpperCase().trim();
  return RegionalPricingMap[key] ?? NATIONAL_AVERAGE;
}

/**
 * Local sales tax rate by state (decimal). Top 10 states + default 7%.
 * Can be replaced with a live Tax API later.
 */
export function getLocalSalesTax(stateCode: StateCode | null, _zip?: string): number {
  if (!stateCode) return 0.07;
  const state = stateCode.toUpperCase().trim();
  switch (state) {
    case 'TN': return 0.0975;   // ~9.75% (varies by county; use common avg)
    case 'CA': return 0.0925;
    case 'NY': return 0.08;
    case 'TX': return 0.0625;
    case 'FL': return 0.06;
    case 'WA': return 0.065;
    case 'MA': return 0.0625;
    case 'GA': return 0.04;     // state + local can be higher
    case 'IL': return 0.0625;
    case 'OH': return 0.0575;
    case 'OR': return 0;        // no sales tax
    case 'MS': return 0.07;
    case 'WV': return 0.06;
    case 'AR': return 0.065;
    default: return 0.07;
  }
}

export function buildRegionalContext(stateCode: StateCode | null, zipCode?: string, marginPercent: number = 30): RegionalContext {
  const { laborMultiplier, materialMultiplier } = getRegionalMultipliers(stateCode);
  const salesTaxRate = getLocalSalesTax(stateCode, zipCode);
  return { laborMultiplier, materialMultiplier, salesTaxRate, marginPercent };
}

// ─────────────────────────────────────────────
// CALCULATION FUNCTIONS
// ─────────────────────────────────────────────

/**
 * Calculate number of line posts (does not include corner/end posts).
 * Adds 1 for the terminal end post.
 */
export function calculatePosts(linearFeet: number, fenceType: FenceType): number {
  if (linearFeet <= 0) return 0;
  const spacing = POST_SPACING_FT[fenceType];
  return Math.ceil(linearFeet / spacing) + 1;
}

/**
 * Calculate all material quantities for a job.
 */
export function calculateMaterials(inputs: JobInputs): MaterialQuantities {
  const { fenceType, linearFeet, gateCount, pricing } = inputs;

  if (linearFeet <= 0) {
    return {
      posts: 0, rails: 0, pickets: 0, panels: 0,
      postCaps: 0, concreteBags: 0, hardwareKits: 0,
      walkGates: gateCount.walk, driveGates: gateCount.drive,
      linearFeet: 0, fenceType,
    };
  }

  const wasteFactor = 1 + (pricing.wastePercent / 100);
  const spacing = POST_SPACING_FT[fenceType];
  const sections = Math.ceil(linearFeet / spacing);

  const posts = calculatePosts(linearFeet, fenceType);

  // Concrete: 1.5 bags per post (standard 80lb bag, 3ft deep)
  const concreteBags = Math.ceil(posts * 1.5);

  // Rails
  const rails = Math.ceil(sections * RAILS_PER_SECTION[fenceType]);

  // Pickets (with waste)
  const pickets = fenceType === 'wood_privacy' || fenceType === 'wood_picket' || fenceType === 'custom'
    ? Math.ceil(linearFeet * PICKETS_PER_FOOT[fenceType] * wasteFactor)
    : 0;

  // Panels for vinyl/aluminum (sections = panels, already accounts for spacing)
  const panels = fenceType === 'vinyl' || fenceType === 'aluminum'
    ? Math.ceil(sections * wasteFactor)
    : 0;

  // Hardware kits: 1 per 50 linear feet (tension bands, brace bands, caps, etc.)
  const hardwareKits = Math.ceil(linearFeet / 50);

  return {
    posts,
    rails,
    pickets,
    panels,
    postCaps: posts,
    concreteBags,
    hardwareKits,
    walkGates: gateCount.walk,
    driveGates: gateCount.drive,
    linearFeet,
    fenceType,
  };
}

/**
 * Calculate all costs from quantities and pricing.
 * If regional is provided: LocalLabor = base * regionalLabor * terrain;
 * LocalMaterials = baseMaterials * regionalMaterial * (1 + salesTax);
 * FinalPrice = (LocalLabor + LocalMaterials) / (1 - margin).
 */
export function calculateCosts(
  quantities: MaterialQuantities,
  pricing: ContractorPricing,
  terrain: Terrain,
  linearFeet: number,
  gateCount: GateCount,
  regional?: RegionalContext | null
): CostBreakdown {
  const {
    posts, rails, pickets, panels,
    concreteBags, hardwareKits, walkGates, driveGates,
  } = quantities;

  // Raw material cost (what contractor pays, before regional/tax)
  const materialCostRaw =
    posts        * pricing.postCost +
    rails        * pricing.railCost +
    pickets      * pricing.picketCost +
    panels       * pricing.panelCost +
    concreteBags * pricing.concreteCost +
    hardwareKits * pricing.hardwareKitCost +
    walkGates    * pricing.walkGateCost +
    driveGates   * pricing.driveGateCost;

  // Material cost after markup (contractor's material price before regional/tax)
  const materialCostMarked = materialCostRaw * (1 + pricing.markupPercent / 100);

  const terrainMultiplier = TERRAIN_MULTIPLIER[terrain];
  const baseLaborCost = linearFeet * pricing.laborRatePerFoot * terrainMultiplier;
  const baseGateLabor = (gateCount.walk + gateCount.drive) * pricing.gateInstallRate;

  let laborCost: number;
  let gateLabor: number;
  let localMaterials: number;
  let total: number;

  if (regional && regional.marginPercent > 0 && regional.marginPercent < 100) {
    const { laborMultiplier, materialMultiplier, salesTaxRate, marginPercent } = regional;
    // LocalLabor = BaseLabor * RegionalMultiplier * TerrainMultiplier (terrain already in base)
    laborCost = baseLaborCost * laborMultiplier;
    gateLabor = baseGateLabor * laborMultiplier;
    // LocalMaterials = BaseMaterialRate * RegionalMultiplier * (1 + LocalSalesTax)
    localMaterials = materialCostMarked * materialMultiplier * (1 + salesTaxRate);
    const costBeforeMargin = laborCost + gateLabor + localMaterials;
    const margin = marginPercent / 100;
    total = costBeforeMargin / (1 - margin);
  } else {
    laborCost = baseLaborCost;
    gateLabor = baseGateLabor;
    localMaterials = materialCostMarked;
    total = localMaterials + laborCost + gateLabor;
  }

  return {
    materialCostRaw,
    materialCostMarked: localMaterials,
    laborCost,
    gateLabor,
    subtotal: laborCost + gateLabor + localMaterials,
    total,
    perLinearFoot: linearFeet > 0 ? total / linearFeet : 0,
    terrainMultiplier,
  };
}

/**
 * Generate supplier-ready line items array for display/export.
 */
export function generateLineItems(
  quantities: MaterialQuantities,
  pricing: ContractorPricing
): MaterialLineItem[] {
  const items: MaterialLineItem[] = [];

  const add = (label: string, qty: number, unit: string, unitCost: number) => {
    if (qty > 0) {
      items.push({ label, qty, unit, unitCost, subtotal: qty * unitCost });
    }
  };

  add('Posts (4×4×8)', quantities.posts, 'ea', pricing.postCost);
  add('Rails (2×4×8)', quantities.rails, 'ea', pricing.railCost);

  if (quantities.pickets > 0) {
    add('Pickets (1×6×6)', quantities.pickets, 'ea', pricing.picketCost);
  }
  if (quantities.panels > 0) {
    add('Fence Panels', quantities.panels, 'ea', pricing.panelCost);
  }

  add('Concrete (80lb bag)', quantities.concreteBags, 'bags', pricing.concreteCost);
  add('Hardware Kit', quantities.hardwareKits, 'kits', pricing.hardwareKitCost);

  if (quantities.walkGates > 0) {
    add('Walk Gate', quantities.walkGates, 'ea', pricing.walkGateCost);
  }
  if (quantities.driveGates > 0) {
    add('Drive Gate', quantities.driveGates, 'ea', pricing.driveGateCost);
  }

  return items;
}

/**
 * Master function — runs entire estimate pipeline.
 * Pass regional for geo-pricing (location-based multipliers, sales tax, margin).
 */
export function runEstimate(inputs: JobInputs, regional?: RegionalContext | null): EstimateResult {
  const quantities = calculateMaterials(inputs);
  const costs = calculateCosts(
    quantities,
    inputs.pricing,
    inputs.terrain,
    inputs.linearFeet,
    inputs.gateCount,
    regional
  );
  const lineItems = generateLineItems(quantities, inputs.pricing);

  return { inputs, quantities, costs, lineItems };
}

// ─────────────────────────────────────────────
// QUOTE TEXT GENERATORS
// ─────────────────────────────────────────────

export function formatCurrency(value: number): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(value);
}

export function generateQuoteText(estimate: EstimateResult, contractorName: string): string {
  const { inputs, costs } = estimate;
  const date = new Date().toLocaleDateString('en-US', {
    month: 'long', day: 'numeric', year: 'numeric',
  });

  const fenceLabels: Record<FenceType, string> = {
    chain_link:   'Chain Link',
    wood_privacy: 'Wood Privacy',
    wood_picket:  'Wood Picket',
    vinyl:        'Vinyl',
    aluminum:     'Aluminum',
    split_rail:   'Split Rail',
    custom:       'Custom',
  };

  const totalGates = inputs.gateCount.walk + inputs.gateCount.drive;
  const gateStr = totalGates > 0
    ? `${inputs.gateCount.walk} walk, ${inputs.gateCount.drive} drive`
    : 'None';

  return [
    '═══════════════════════════════',
    '         FENCE ESTIMATE        ',
    contractorName ? contractorName.toUpperCase() : 'YOUR FENCE CO.',
    `Date: ${date}`,
    '═══════════════════════════════',
    `Fence Type: ${fenceLabels[inputs.fenceType]}`,
    `Linear Feet: ${inputs.linearFeet} LF`,
    `Gates: ${gateStr}`,
    `Terrain: ${inputs.terrain.charAt(0).toUpperCase() + inputs.terrain.slice(1)}`,
    '───────────────────────────────',
    `Materials:          ${formatCurrency(costs.materialCostMarked)}`,
    `Labor:              ${formatCurrency(costs.laborCost + costs.gateLabor)}`,
    '───────────────────────────────',
    `TOTAL INSTALLED:    ${formatCurrency(costs.total)}`,
    `Per Linear Foot:    ${formatCurrency(costs.perLinearFoot)}/ft`,
    '═══════════════════════════════',
    'Valid for 30 days',
  ].join('\n');
}

export function generateSupplierList(estimate: EstimateResult, contractorName: string): string {
  const { lineItems, costs } = estimate;
  const date = new Date().toLocaleDateString('en-US');

  const rows = lineItems.map((item) =>
    `${item.label.padEnd(24)} ${String(item.qty).padStart(4)} ${item.unit.padEnd(6)} @ ${formatCurrency(item.unitCost).padStart(8)}  = ${formatCurrency(item.subtotal).padStart(8)}`
  );

  return [
    `MATERIAL ORDER — ${date}`,
    contractorName ? `For: ${contractorName}` : '',
    '─'.repeat(60),
    ...rows,
    '─'.repeat(60),
    `TOTAL MATERIALS:    ${formatCurrency(costs.materialCostRaw)}`,
  ].filter(Boolean).join('\n');
}
