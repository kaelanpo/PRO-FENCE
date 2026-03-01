//
//  ContentView.swift
//  fencing app test
//
//  Every control binds to FenceQuoteViewModel. Estimate recalculates on every keystroke.
//

import SwiftUI

// MARK: - Design tokens
private enum D {
    static let bg = Color(red: 7/255, green: 7/255, blue: 15/255)
    static let blue = Color(red: 10/255, green: 132/255, blue: 1)
    static let green = Color(red: 48/255, green: 209/255, blue: 88/255)
    static let red = Color(red: 1, green: 69/255, blue: 58/255)
    static let orange = Color.orange
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.5)
    static let textTertiary = Color.white.opacity(0.28)
    static let radius: CGFloat = 20
    static let radiusSmall: CGFloat = 14
    static let sectionSpacing: CGFloat = 24
    static let horizontalPadding: CGFloat = 16
}

// MARK: - Main view (single source of truth: viewModel)
struct ContentView: View {
    @State private var viewModel = FenceQuoteViewModel()
    @State private var showCloseJobConfirmation = false

    var body: some View {
        ZStack(alignment: .top) {
            D.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: D.sectionSpacing) {
                    paddingTop(8)
                    headerSection
                    sectionLabel("FENCE TYPE")
                    fenceTypeSelector
                    sectionLabel("MEASUREMENTS")
                    measurementsCard
                    sectionLabel("LAYOUT DETAILS")
                    layoutDetailsCard
                    sectionLabel("ESTIMATE")
                    estimateCard
                    if viewModel.computedEstimate != nil {
                        materialListAccordion
                    }
                    if viewModel.showPricingSheet {
                        pricingConfigCard
                    }
                    paddingBottom(120)
                }
                .padding(.horizontal, D.horizontalPadding)
            }

            actionBar
        }
        .preferredColorScheme(.dark)
        .confirmationDialog("Close Job", isPresented: $showCloseJobConfirmation) {
            Button("Clear", role: .destructive) {
                viewModel.clearMeasurementInputsOnly()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Clear measurement inputs and start a new estimate? Pricing and company name are kept.")
        }
    }

    private func paddingTop(_ height: CGFloat) -> some View { Color.clear.frame(height: height) }
    private func paddingBottom(_ height: CGFloat) -> some View { Color.clear.frame(height: height) }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(D.textTertiary)
            .padding(.leading, 4)
    }

    // MARK: - 1. Header
    private var headerSection: some View {
        Group {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FenceQuote")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(D.textPrimary)
                    if viewModel.editingContractorName {
                        TextField("Your Company Name", text: $viewModel.contractorName)
                            .textFieldStyle(.plain)
                            .foregroundStyle(D.textPrimary)
                            .onSubmit {
                                viewModel.editingContractorName = false
                                viewModel.saveContractorName()
                            }
                    } else {
                        Button {
                            viewModel.editingContractorName = true
                        } label: {
                            Text(viewModel.contractorName.isEmpty ? "Tap to add company name ›" : viewModel.contractorName)
                                .font(.system(size: 14))
                                .foregroundStyle(D.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()
                Button {
                    viewModel.showPricingSheet.toggle()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(D.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: D.radius))
        .overlay(RoundedRectangle(cornerRadius: D.radius).stroke(Color.white.opacity(0.2), lineWidth: 1))
    }

    // MARK: - 2. Fence type selector
    private var fenceTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([(FenceType.woodPrivacy, "Wood Privacy"),
                         (FenceType.woodPicket, "Wood Picket"),
                         (FenceType.chainLink, "Chain Link"),
                         (FenceType.vinyl, "Vinyl"),
                         (FenceType.aluminum, "Aluminum"),
                         (FenceType.splitRail, "Split Rail")], id: \.0.self) { type, label in
                    let isSelected = viewModel.selectedFenceType == type
                    Button {
                        viewModel.selectedFenceType = type
                    } label: {
                        HStack(spacing: 6) {
                            Text(iconForFenceType(type))
                            Text(label)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(isSelected ? .white : D.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(isSelected ? Color.accentColor : Color.white.opacity(0.1), in: Capsule())
                        .overlay(Capsule().stroke(isSelected ? Color.accentColor : Color.white.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 4)
        }
    }

    private func iconForFenceType(_ t: FenceType) -> String {
        switch t {
        case .woodPrivacy: return "🌲"
        case .woodPicket: return "🏡"
        case .chainLink: return "⛓️"
        case .vinyl: return "🔷"
        case .aluminum: return "🔩"
        case .splitRail: return "🪵"
        }
    }

    // MARK: - 3. Measurements card
    private var measurementsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Zip (regional pricing)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(D.textSecondary)
                Spacer()
                TextField("e.g. 37167", text: $viewModel.zipCode)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(D.textPrimary)
                    .frame(width: 100)
            }
            .padding(.vertical, 4)
            Divider().background(D.textTertiary).padding(.vertical, 12)
            measurementsLinearFeetRow
            Divider().background(D.textTertiary).padding(.vertical, 12)
            stepperRow("Walk Gates", value: $viewModel.walkGates)
            Divider().background(Color.white.opacity(0.07)).padding(.vertical, 8)
            stepperRow("Drive Gates", value: $viewModel.driveGates)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: D.radius))
        .overlay(RoundedRectangle(cornerRadius: D.radius).stroke(Color.white.opacity(0.2), lineWidth: 1))
    }

    private var measurementsLinearFeetRow: some View {
        HStack {
            Text("Linear Footage")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(D.textSecondary)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("0", text: $viewModel.linearFeetString)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(D.textPrimary)
                    .frame(minWidth: 80)
                Text("ft")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(D.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var terrainSelector: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Terrain")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(D.textSecondary)
                .padding(.bottom, 10)
            HStack(spacing: 8) {
                ForEach([Terrain.flat, .slope, .difficult], id: \.self) { t in
                    terrainButton(t)
                }
            }
        }
    }

    // MARK: - Layout Details (takeoff)
    private var layoutDetailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepperRow("90° Corners", value: $viewModel.corners90)
            Divider().background(Color.white.opacity(0.07)).padding(.vertical, 8)
            HStack {
                Text("Ends at House/Structure")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(D.textSecondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.endsAtHouse },
                    set: { new in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        viewModel.endsAtHouse = new
                    }
                ))
                .labelsHidden()
            }
            .padding(.vertical, 4)
            Divider().background(Color.white.opacity(0.07)).padding(.vertical, 8)
            VStack(alignment: .leading, spacing: 6) {
                Text("Section Length")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(D.textSecondary)
                Picker("", selection: $viewModel.sectionLength) {
                    Text("8 ft (Standard)").tag(SectionLength.standard8ft)
                    Text("6 ft (Heavy Duty)").tag(SectionLength.heavyDuty6ft)
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 4)
            Divider().background(Color.white.opacity(0.07)).padding(.vertical, 8)
            VStack(alignment: .leading, spacing: 6) {
                Text("Terrain (labor multiplier)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(D.textSecondary)
                HStack(spacing: 8) {
                    ForEach([Terrain.flat, .slope, .difficult], id: \.self) { t in
                        terrainButton(t)
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: D.radius))
        .overlay(RoundedRectangle(cornerRadius: D.radius).stroke(Color.white.opacity(0.2), lineWidth: 1))
    }

    private func terrainButton(_ t: Terrain) -> some View {
        let isSelected = viewModel.terrainType == t
        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            viewModel.terrainType = t
        } label: {
            VStack(spacing: 4) {
                Text(terrainIcon(t))
                Text(terrainShortLabel(t))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? D.orange : D.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? D.orange.opacity(0.2) : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: D.radiusSmall))
            .overlay(RoundedRectangle(cornerRadius: D.radiusSmall).stroke(isSelected ? D.orange : Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func stepperRow(_ label: String, value: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(D.textSecondary)
            Spacer()
            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    value.wrappedValue = max(0, value.wrappedValue - 1)
                } label: {
                    Text("−")
                        .font(.system(size: 22))
                        .foregroundStyle(D.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                Text("\(value.wrappedValue)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(D.textPrimary)
                    .frame(minWidth: 28)
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    value.wrappedValue += 1
                } label: {
                    Text("+")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor.opacity(0.2), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func terrainIcon(_ t: Terrain) -> String {
        switch t {
        case .flat: return "➖"
        case .slope: return "📐"
        case .difficult: return "⛰️"
        }
    }

    private func terrainShortLabel(_ t: Terrain) -> String {
        switch t {
        case .flat: return "Flat"
        case .slope: return "Sloped (1.25×)"
        case .difficult: return "Difficult (1.5×)"
        }
    }

    // MARK: - 4. Live estimate card (breakdown + margin-first result)
    private var estimateCard: some View {
        let est = viewModel.computedEstimate
        let full = viewModel.fullEstimateResult
        return Group {
            VStack(alignment: .leading, spacing: 0) {
                if let full = full {
                    resultRow("Total Posts", "\(full.quantities.linePostCount) Line / \(full.quantities.terminalPostCount) Terminal")
                    Divider().background(Color.white.opacity(0.07)).padding(.vertical, 6)
                    resultRow("Total Concrete", "\(full.quantities.concreteBags) bags")
                    Divider().background(Color.white.opacity(0.07)).padding(.vertical, 6)
                }
                costRow("Material Cost", est?.materialCost ?? 0)
                if let est = est, est.salesTaxAmount > 0 {
                    Divider().background(Color.white.opacity(0.07)).padding(.vertical, 6)
                    costRow("Sales Tax (9.75%)", est.salesTaxAmount)
                }
                Divider().background(Color.white.opacity(0.07)).padding(.vertical, 8)
                costRow("Labor Cost", est?.laborCost ?? 0)
                Divider().background(Color.white.opacity(0.07)).padding(.vertical, 8)
                OdometerTotalView(value: est?.totalCost ?? 0)
                if let full = full, full.costs.estimatedProfit != 0 {
                    Divider().background(D.textTertiary).padding(.vertical, 6)
                    costRow("Estimated Profit", full.costs.estimatedProfit)
                }
                Divider().background(D.textTertiary).padding(.vertical, 12)
                EffectivePricePerLFView(pricePerLF: est?.effectivePricePerLF ?? 0)
                if full != nil {
                    safetyComplianceCard
                }
            }
            .padding(20)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: D.radius))
        .overlay(RoundedRectangle(cornerRadius: D.radius).stroke(Color.white.opacity(0.2), lineWidth: 1))
        .opacity(est == nil ? 0.55 : 1)
    }

    private var safetyComplianceCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.orange.opacity(0.7))
            Text("TN State Law (TCA 65-31-101): You are required to notify Tennessee 811 at least 3 business days before digging, even for hand-tool projects. Call 811 or visit tenn811.com.")
                .font(.system(size: 12))
                .foregroundStyle(D.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: D.radiusSmall))
        .overlay(RoundedRectangle(cornerRadius: D.radiusSmall).stroke(Color.orange.opacity(0.4), lineWidth: 1))
        .padding(.top, 16)
    }

    /// Odometer-style rolling number: when value changes, old total slides up and new slides up into place.
    private struct OdometerTotalView: View {
        let value: Double
        @State private var displayedValue: Double = 0
        @State private var rollProgress: CGFloat = 1 // 0 = show old, 1 = show new (animation 0→1)
        private let rollHeight: CGFloat = 44
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text("FINAL INSTALLED PRICE")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(D.textTertiary)
                ZStack(alignment: .top) {
                    Text(formatCurrency(displayedValue))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .offset(y: -rollProgress * rollHeight)
                    Text(formatCurrency(value))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .offset(y: (1 - rollProgress) * rollHeight)
                }
                .frame(height: rollHeight)
                .clipped()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: value) { _, new in
                if abs(new - displayedValue) < 0.01 { return }
                rollProgress = 0
                withAnimation(.easeInOut(duration: 0.3)) {
                    rollProgress = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    displayedValue = new
                }
            }
            .onAppear { displayedValue = value; rollProgress = 1 }
        }
    }

    /// Effective price per LF with subtle fade when value updates.
    private struct EffectivePricePerLFView: View {
        let pricePerLF: Double
        @State private var displayedValue: Double = 0
        var body: some View {
            HStack {
                Text("Effective Price per LF")
                    .font(.system(size: 13))
                    .foregroundStyle(D.textSecondary)
                Spacer()
                Text(formatCurrency(pricePerLF))
                    .font(.system(size: 15, weight: .semibold))
                    .contentTransition(.numericText())
                    .foregroundStyle(D.textPrimary)
            }
            .padding(.vertical, 4)
            .opacity(displayedValue == pricePerLF ? 1 : 0.7)
            .animation(.easeInOut(duration: 0.25), value: pricePerLF)
            .onChange(of: pricePerLF) { _, new in
                displayedValue = new
            }
            .onAppear { displayedValue = pricePerLF }
        }
    }

    private func resultRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(D.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(D.textPrimary)
        }
        .padding(.vertical, 4)
    }

    private func costRow(_ label: String, _ value: Double, small: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: small ? 13 : 17))
                .foregroundStyle(D.textSecondary)
            Spacer()
            Text(formatCurrency(value))
                .font(.system(size: small ? 15 : 17, weight: .semibold))
                .contentTransition(.numericText())
                .foregroundStyle(D.textPrimary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - DEBUG panel (raw engine values — confirms formulas)
    private var debugPanel: some View {
        Group {
            if let result = viewModel.fullEstimateResult {
                VStack(alignment: .leading, spacing: 0) {
                    Text("DEBUG — Raw values")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(D.textTertiary)
                        .padding(.leading, 4)
                        .padding(.bottom, 8)
                    VStack(alignment: .leading, spacing: 6) {
                        debugRow("Posts", "\(result.quantities.posts)")
                        debugRow("Rails", "\(result.quantities.rails)")
                        debugRow("Pickets", "\(result.quantities.pickets)")
                        debugRow("Concrete Bags", "\(result.quantities.concreteBags)")
                        debugRow("Labor Hours", String(format: "%.2f", result.costs.laborHours))
                        debugRow("Subtotal before markup", formatCurrency(result.costs.subtotalBeforeMarkup))
                        debugRow("Final Price", formatCurrency(result.costs.finalPrice))
                    }
                    .padding(16)
                }
                .padding(20)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: D.radius))
                .overlay(RoundedRectangle(cornerRadius: D.radius).stroke(Color.orange.opacity(0.35), lineWidth: 1))
            } else {
                EmptyView()
            }
        }
    }

    private func debugRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(D.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(D.textPrimary)
        }
    }

    // MARK: - 5. Material list accordion
    private var materialListAccordion: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) { viewModel.showMaterialList.toggle() }
            } label: {
                HStack {
                    Text("📋 Material List (\(viewModel.computedEstimate?.materialList.count ?? 0) items)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(D.textSecondary)
                    Spacer()
                    Image(systemName: viewModel.showMaterialList ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(D.textTertiary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            if viewModel.showMaterialList, let list = viewModel.computedEstimate?.materialList {
                materialListTable(list)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: viewModel.showMaterialList)
    }

    private func materialListTable(_ materialList: [MaterialLineItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(alignment: .center, spacing: 4) {
                Text("Item").frame(maxWidth: .infinity, alignment: .leading)
                Text("Qty").frame(width: 44, alignment: .center)
                Text("Cost").frame(width: 70, alignment: .trailing)
                Text("Total").frame(width: 70, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(D.textTertiary)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            Divider().background(Color.white.opacity(0.2))

            ForEach(Array(materialList.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .center, spacing: 4) {
                    Text(item.label).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(item.qty)").frame(width: 44, alignment: .center)
                    Text(formatCurrency(item.unitCost)).frame(width: 70, alignment: .trailing).foregroundStyle(D.textSecondary)
                    Text(formatCurrency(item.subtotal)).frame(width: 70, alignment: .trailing)
                }
                .font(.system(size: 13))
                .foregroundStyle(D.textPrimary)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }

            HStack(spacing: 8) {
                Button {
                    copySupplierList()
                } label: {
                    Text("Copy")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: D.radiusSmall))
                        .overlay(RoundedRectangle(cornerRadius: D.radiusSmall).stroke(Color.accentColor.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button {
                    shareSupplierList()
                } label: {
                    Text("Share")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: D.radiusSmall))
                        .overlay(RoundedRectangle(cornerRadius: D.radiusSmall).stroke(Color.accentColor.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: D.radius))
        .overlay(RoundedRectangle(cornerRadius: D.radius).stroke(Color.white.opacity(0.2), lineWidth: 1))
    }

    // MARK: - 6. Pricing config card
    private var pricingConfigCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pricing")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(D.textPrimary)
                .padding(.bottom, 4)

            sectionLabel("MATERIAL COSTS")
            pricingRows(materialKeys)
            sectionLabel("LABOR ($ per foot / gate)")
            pricingRows(laborKeys)
            sectionLabel("LABOR (hours × hourly rate)")
            pricingRows([("Hourly rate ($)", \.hourlyRate)])
            pricingNumberRow("Hours per LF", bindPricing(\.laborHoursPerLinearFoot))
            pricingNumberRow("Hours per walk gate", bindPricing(\.laborHoursPerWalkGate))
            pricingNumberRow("Hours per drive gate", bindPricing(\.laborHoursPerDriveGate))
            sectionLabel("PROFIT (MARGIN-FIRST)")
            pricingPercentRow("Desired Margin %", bindPricing(\.desiredMarginPercent))
            Text("Price = Cost ÷ (1 − margin). 20% margin protects net profit.")
                .font(.caption)
                .foregroundStyle(D.textTertiary)
            sectionLabel("MARKUP & WASTE")
            pricingPercentRow("Material Markup % (fallback)", bindPricing(\.markupPercent))
            pricingPercentRow("Waste Buffer %", bindPricing(\.wastePercent))
            sectionLabel("OVERHEAD")
            HStack {
                Text("Overhead")
                    .font(.system(size: 15))
                    .foregroundStyle(D.textSecondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.pricing.overheadEnabled },
                    set: { newValue in
                        var p = viewModel.pricing
                        p.overheadEnabled = newValue
                        viewModel.pricing = p
                    }
                ))
                .labelsHidden()
            }
            .padding(.vertical, 8)
            if viewModel.pricing.overheadEnabled {
                pricingPercentRow("Overhead %", bindPricing(\.overheadPercent))
            }

            Button {
                viewModel.pricing = .default
            } label: {
                Text("Reset to Defaults")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(D.red)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: D.radius))
        .overlay(RoundedRectangle(cornerRadius: D.radius).stroke(Color.white.opacity(0.2), lineWidth: 1))
    }

    private let materialKeys: [(String, WritableKeyPath<ContractorPricing, Double>)] = [
        ("Post (4×4×8) fallback", \.postCost),
        ("Line Post (4×4×8 PT)", \.linePostCost),
        ("Terminal Post (6×6×8 PT)", \.terminalPostCost),
        ("Rail (2×4×8)", \.railCost),
        ("Picket (1×6×6)", \.picketCost),
        ("Panel", \.panelCost),
        ("Concrete (80lb)", \.concreteCost),
        ("Hardware Kit", \.hardwareKitCost),
        ("Gate Hardware per gate", \.gateHardwarePerGate),
        ("Walk Gate", \.walkGateCost),
        ("Drive Gate", \.driveGateCost),
    ]
    private let laborKeys: [(String, WritableKeyPath<ContractorPricing, Double>)] = [
        ("Rate per Foot", \.laborRatePerFoot),
        ("Gate Install", \.gateInstallRate),
    ]

    private func bindPricing(_ keyPath: WritableKeyPath<ContractorPricing, Double>) -> Binding<Double> {
        Binding(
            get: { viewModel.pricing[keyPath: keyPath] },
            set: { viewModel.pricing[keyPath: keyPath] = $0 }
        )
    }

    private func pricingRows(_ keys: [(String, WritableKeyPath<ContractorPricing, Double>)]) -> some View {
        ForEach(keys, id: \.0) { label, keyPath in
            HStack {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(D.textSecondary)
                Spacer()
                HStack(spacing: 2) {
                    Text("$")
                        .foregroundStyle(D.textSecondary)
                    TextField("0", value: bindPricing(keyPath), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(D.textPrimary)
                    .frame(width: 70)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.vertical, 8)
        }
    }

    private func pricingPercentRow(_ label: String, _ binding: Binding<Double>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(D.textSecondary)
            Spacer()
            TextField("20", value: binding, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(D.textPrimary)
                .frame(width: 70)
            Text("%").foregroundStyle(D.textSecondary)
        }
        .padding(.vertical, 8)
    }

    private func pricingNumberRow(_ label: String, _ binding: Binding<Double>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(D.textSecondary)
            Spacer()
            TextField("0", value: binding, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(D.textPrimary)
                .frame(width: 70)
        }
        .padding(.vertical, 8)
    }

    // MARK: - 7. Action bar
    private var actionBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Button {
                    copyQuote()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(D.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.computedEstimate == nil)

                Button {
                    shareQuote()
                } label: {
                    Label("Share Quote", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(D.green, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.computedEstimate == nil)

                Button {
                    showCloseJobConfirmation = true
                } label: {
                    Label("Close Job", systemImage: "checkmark.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(D.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(D.red.opacity(0.27), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .background(.ultraThinMaterial.opacity(0.95))
        }
        .allowsHitTesting(true)
    }

    // MARK: - Actions
    private func copyQuote() {
        guard let est = viewModel.fullEstimateResult else { return }
        let text = generateQuoteText(estimate: est, linearFeet: viewModel.linearFeet, fenceType: viewModel.selectedFenceType, gateCount: viewModel.gateCount, terrain: viewModel.terrainType, contractorName: viewModel.contractorName)
        UIPasteboard.general.string = text
    }

    private func shareQuote() {
        guard let est = viewModel.fullEstimateResult else { return }
        let text = generateQuoteText(estimate: est, linearFeet: viewModel.linearFeet, fenceType: viewModel.selectedFenceType, gateCount: viewModel.gateCount, terrain: viewModel.terrainType, contractorName: viewModel.contractorName)
        presentShareSheet(items: [text])
    }

    private func copySupplierList() {
        guard let est = viewModel.fullEstimateResult else { return }
        let text = generateSupplierList(estimate: est, contractorName: viewModel.contractorName)
        UIPasteboard.general.string = text
    }

    private func shareSupplierList() {
        guard let est = viewModel.fullEstimateResult else { return }
        let text = generateSupplierList(estimate: est, contractorName: viewModel.contractorName)
        presentShareSheet(items: [text])
    }

    private func presentShareSheet(items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        root.present(vc, animated: true)
    }

}

#Preview {
    ContentView()
}
