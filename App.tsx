// ============================================================
// FenceQuote — App.tsx
// iOS 26 Refined: glassmorphism, continuous corners, premium typography
// ============================================================

import React, { useReducer, useMemo, useCallback, useEffect, useRef, useState } from 'react';
import {
  View, Text, ScrollView, TextInput, TouchableOpacity,
  StyleSheet, StatusBar, Platform, Animated,
  Alert, LayoutAnimation, UIManager, Share, Switch,
} from 'react-native';
import * as Clipboard from 'expo-clipboard';
import { SafeAreaProvider, SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { BlurView } from 'expo-blur';
import * as Haptics from 'expo-haptics';
import AsyncStorage from '@react-native-async-storage/async-storage';

import * as Location from 'expo-location';
import {
  FenceType, Terrain, GateCount, ContractorPricing, EstimateResult,
  DEFAULT_PRICING, runEstimate, generateQuoteText, generateSupplierList,
  formatCurrency, buildRegionalContext, RegionalContext,
} from './src/engine/calculations';

// ─── Enable LayoutAnimation on Android ───────────────────
if (Platform.OS === 'android' && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

// ─── Design Tokens (iOS 26 Refined) ───────────────────────
const D = {
  glass: 'rgba(255,255,255,0.08)',
  glassBorder: 'rgba(255,255,255,0.10)',
  glassStrong: 'rgba(255,255,255,0.14)',
  bg: '#07070F',
  bgMid: '#0E0E1C',
  contractorBlue: '#0A5FA8',
  forestGreen: '#1B6B4B',
  green: '#30D158',
  blue: '#0A84FF',
  orange: '#FF9F0A',
  red: '#FF453A',
  textPrimary: '#FFFFFF',
  textSecondary: 'rgba(255,255,255,0.55)',
  textTertiary: 'rgba(255,255,255,0.35)',
  radius: 22,
  radiusSmall: 14,
  radiusPill: 50,
  cardShadow: { shadowColor: '#000', shadowOffset: { width: 0, height: 10 }, shadowOpacity: 0.08, shadowRadius: 30, elevation: 8 },
};

// ─── Location (geo-pricing) ───────────────────────────────
export interface LocationInfo {
  city: string;
  state: string;
  zip: string;
  isManual: boolean;
  isLoading: boolean;
}

const defaultLocation: LocationInfo = {
  city: '',
  state: '',
  zip: '',
  isManual: false,
  isLoading: true,
};

// ─── App State ────────────────────────────────────────────
interface AppState {
  fenceType: FenceType;
  linearFeetStr: string;
  gateCount: GateCount;
  terrain: Terrain;
  sectionLength: 6 | 8;
  pricing: ContractorPricing;
  contractorName: string;
  location: LocationInfo;
  showPricingSheet: boolean;
  showMaterialList: boolean;
  showContractorEdit: boolean;
  showLocationOverride: boolean;
  roundQuoteTo25: boolean;
}

type Action =
  | { type: 'SET_FENCE_TYPE'; payload: FenceType }
  | { type: 'SET_LINEAR_FEET'; payload: string }
  | { type: 'SET_GATE_WALK'; payload: number }
  | { type: 'SET_GATE_DRIVE'; payload: number }
  | { type: 'SET_TERRAIN'; payload: Terrain }
  | { type: 'SET_SECTION_LENGTH'; payload: 6 | 8 }
  | { type: 'SET_PRICING'; payload: Partial<ContractorPricing> }
  | { type: 'SET_CONTRACTOR_NAME'; payload: string }
  | { type: 'TOGGLE_PRICING_SHEET' }
  | { type: 'TOGGLE_MATERIAL_LIST' }
  | { type: 'TOGGLE_CONTRACTOR_EDIT' }
  | { type: 'TOGGLE_LOCATION_OVERRIDE' }
  | { type: 'SET_LOCATION'; payload: Partial<LocationInfo> }
  | { type: 'SET_ROUND_QUOTE_TO_25'; payload: boolean }
  | { type: 'LOAD_PRICING'; payload: ContractorPricing }
  | { type: 'RESET_FORM' };

const initialState: AppState = {
  fenceType: 'wood_privacy',
  linearFeetStr: '',
  gateCount: { walk: 0, drive: 0 },
  terrain: 'flat',
  sectionLength: 8,
  pricing: DEFAULT_PRICING,
  contractorName: '',
  location: defaultLocation,
  showPricingSheet: false,
  showMaterialList: false,
  showContractorEdit: false,
  showLocationOverride: false,
  roundQuoteTo25: true,
};

function reducer(state: AppState, action: Action): AppState {
  switch (action.type) {
    case 'SET_FENCE_TYPE':       return { ...state, fenceType: action.payload };
    case 'SET_LINEAR_FEET':      return { ...state, linearFeetStr: action.payload };
    case 'SET_GATE_WALK':        return { ...state, gateCount: { ...state.gateCount, walk: Math.max(0, action.payload) } };
    case 'SET_GATE_DRIVE':       return { ...state, gateCount: { ...state.gateCount, drive: Math.max(0, action.payload) } };
    case 'SET_TERRAIN':          return { ...state, terrain: action.payload };
    case 'SET_SECTION_LENGTH':   return { ...state, sectionLength: action.payload };
    case 'SET_PRICING':          return { ...state, pricing: { ...state.pricing, ...action.payload } };
    case 'SET_CONTRACTOR_NAME':  return { ...state, contractorName: action.payload };
    case 'TOGGLE_PRICING_SHEET': return { ...state, showPricingSheet: !state.showPricingSheet };
    case 'TOGGLE_MATERIAL_LIST': return { ...state, showMaterialList: !state.showMaterialList };
    case 'TOGGLE_CONTRACTOR_EDIT': return { ...state, showContractorEdit: !state.showContractorEdit };
    case 'TOGGLE_LOCATION_OVERRIDE': return { ...state, showLocationOverride: !state.showLocationOverride };
    case 'SET_LOCATION': return { ...state, location: { ...state.location, ...action.payload } };
    case 'SET_ROUND_QUOTE_TO_25':  return { ...state, roundQuoteTo25: action.payload };
    case 'LOAD_PRICING':         return { ...state, pricing: action.payload };
    case 'RESET_FORM':           return { ...initialState, pricing: state.pricing, contractorName: state.contractorName, location: state.location };
    default: return state;
  }
}

// ─── Fence Type Config ────────────────────────────────────
const FENCE_TYPES: { id: FenceType; label: string; icon: string }[] = [
  { id: 'wood_privacy',  label: 'Wood Privacy',  icon: '🌲' },
  { id: 'wood_picket',   label: 'Wood Picket',   icon: '🏡' },
  { id: 'chain_link',    label: 'Chain Link',    icon: '⛓️' },
  { id: 'vinyl',         label: 'Vinyl',         icon: '🔷' },
  { id: 'aluminum',      label: 'Aluminum',      icon: '🔩' },
  { id: 'split_rail',    label: 'Split Rail',    icon: '🪵' },
];

// ─── AnimatedNumber (micro-interaction: fade + spring roll) ─
function AnimatedNumber({ value, style, prefix = '' }: { value: number; style?: object; prefix?: string }) {
  const animValue = useRef(new Animated.Value(value)).current;
  const opacity = useRef(new Animated.Value(1)).current;
  const [display, setDisplay] = useState(value);

  useEffect(() => {
    Animated.sequence([
      Animated.timing(opacity, { toValue: 0.4, duration: 80, useNativeDriver: true }),
      Animated.spring(animValue, {
        toValue: value,
        damping: 18,
        stiffness: 200,
        useNativeDriver: false,
      }),
      Animated.timing(opacity, { toValue: 1, duration: 180, useNativeDriver: true }),
    ]).start();
    const id = animValue.addListener(({ value: v }) => setDisplay(Math.round(v)));
    return () => animValue.removeListener(id);
  }, [value]);

  return (
    <Animated.Text style={[style, { opacity }]}>
      {prefix}{formatCurrency(display)}
    </Animated.Text>
  );
}

// ─── GlassCard (iOS 26: ultraThinMaterial, 22px continuous, soft shadow) ─
function GlassCard({ children, style }: { children: React.ReactNode; style?: object }) {
  return (
    <View style={[styles.glassCardWrap, style]}>
      <BlurView intensity={40} tint="dark" style={styles.glassCardBlur}>
        <View style={styles.glassCardBorder}>{children}</View>
      </BlurView>
    </View>
  );
}

// ─── Stepper (wide pill, integrated, haptic) ──────────────
function Stepper({ value, label, onChange }: { value: number; label: string; onChange: (n: number) => void }) {
  const handleChange = (delta: number) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onChange(value + delta);
  };

  return (
    <View style={styles.stepperRow}>
      <Text style={styles.stepperLabel}>{label}</Text>
      <View style={styles.stepperPill}>
        <TouchableOpacity style={styles.stepperPillBtn} onPress={() => handleChange(-1)}>
          <Text style={styles.stepperPillBtnText}>−</Text>
        </TouchableOpacity>
        <Text style={styles.stepperPillValue}>{value}</Text>
        <TouchableOpacity style={[styles.stepperPillBtn, styles.stepperPillBtnPlus]} onPress={() => handleChange(1)}>
          <Text style={[styles.stepperPillBtnText, { color: D.contractorBlue }]}>+</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

// ─── Sticky Live Header (total + smart location tag) ───────
function StickyLiveHeader({
  totalPrice,
  hasEstimate,
  location,
  onManualOverride,
}: {
  totalPrice: number;
  hasEstimate: boolean;
  location: LocationInfo;
  onManualOverride: () => void;
}) {
  const locationLabel = location.city && location.state
    ? (location.isManual ? `📍 ${location.city}, ${location.state}` : `📍 Detected: ${location.city}, ${location.state}`)
    : location.isLoading
      ? '📍 Detecting location…'
      : '📍 National average';

  return (
    <View style={styles.stickyHeader}>
      <BlurView intensity={50} tint="dark" style={StyleSheet.absoluteFill} />
      <View style={[styles.stickyHeaderContent, { borderBottomWidth: 1, borderBottomColor: D.glassBorder }]}>
        <View style={styles.stickyHeaderRow}>
          <Text style={styles.stickyHeaderLabel}>Total Estimate</Text>
          <TouchableOpacity style={styles.locationOverrideBtn} onPress={onManualOverride}>
            <Text style={styles.locationOverrideBtnText}>Manual Override</Text>
          </TouchableOpacity>
        </View>
        {hasEstimate ? (
          <AnimatedNumber value={totalPrice} style={styles.stickyHeaderTotal} />
        ) : (
          <Text style={styles.stickyHeaderPlaceholder}>Enter dimensions below</Text>
        )}
        <Text style={styles.stickyHeaderCaption}>{locationLabel}</Text>
      </View>
    </View>
  );
}

// ─── Segment Control (sliding glass background, 6ft / 8ft style) ─
function SegmentControl<T extends string | number>({
  options,
  value,
  onChange,
  label,
}: { options: { id: T; label: string }[]; value: T; onChange: (id: T) => void; label?: string }) {
  const idx = Math.max(0, options.findIndex((o) => o.id === value));
  const segmentWidth = 100 / options.length;

  return (
    <View style={styles.segmentWrap}>
      {label ? <Text style={styles.segmentLabel}>{label}</Text> : null}
      <View style={styles.segmentTrack}>
        <View
          style={[
            styles.segmentGlass,
            {
              width: `${segmentWidth}%`,
              left: `${idx * segmentWidth}%`,
            },
          ]}
        />
        {options.map((opt) => {
          const active = value === opt.id;
          return (
            <TouchableOpacity
              key={opt.id}
              style={styles.segmentOption}
              onPress={() => {
                Haptics.selectionAsync();
                onChange(opt.id);
              }}
            >
              <Text style={[styles.segmentOptionText, active && styles.segmentOptionTextActive]}>
                {opt.label}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>
    </View>
  );
}

// ─── Pricing Row ──────────────────────────────────────────
function PricingRow({
  label, value, onChange
}: { label: string; value: number; onChange: (v: number) => void }) {
  return (
    <View style={styles.pricingRow}>
      <Text style={styles.pricingRowLabel}>{label}</Text>
      <View style={styles.pricingInput}>
        <Text style={styles.pricingPrefix}>$</Text>
        <TextInput
          style={styles.pricingInputText}
          value={value === 0 ? '' : String(value)}
          keyboardType="decimal-pad"
          onChangeText={(t) => onChange(parseFloat(t) || 0)}
          placeholderTextColor={D.textTertiary}
          placeholder="0.00"
          selectTextOnFocus
        />
      </View>
    </View>
  );
}

// ─── Main App ─────────────────────────────────────────────
export default function App() {
  const insets = useSafeAreaInsets();
  const [state, dispatch] = useReducer(reducer, initialState);
  const scrollRef = useRef<ScrollView>(null);

  // Load persisted pricing, contractor name, and location override
  useEffect(() => {
    (async () => {
      try {
        const stored = await AsyncStorage.getItem('contractor_pricing');
        if (stored) dispatch({ type: 'LOAD_PRICING', payload: JSON.parse(stored) });
        const name = await AsyncStorage.getItem('contractor_name');
        if (name) dispatch({ type: 'SET_CONTRACTOR_NAME', payload: name });
        const loc = await AsyncStorage.getItem('location_override');
        if (loc) {
          const parsed = JSON.parse(loc);
          dispatch({ type: 'SET_LOCATION', payload: { ...parsed, isLoading: false } });
          return;
        }
      } catch {}
      // No override: detect location
      try {
        const { status } = await Location.requestForegroundPermissionsAsync();
        if (status !== 'granted') {
          dispatch({ type: 'SET_LOCATION', payload: { isLoading: false } });
          return;
        }
        const position = await Location.getCurrentPositionAsync({});
        const [rev] = await Location.reverseGeocodeAsync({
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
        });
        if (rev) {
          const city = rev.city ?? rev.subregion ?? '';
          const state = rev.region ?? '';
          const zip = rev.postalCode ?? '';
          dispatch({ type: 'SET_LOCATION', payload: { city, state, zip, isManual: false, isLoading: false } });
        } else {
          dispatch({ type: 'SET_LOCATION', payload: { isLoading: false } });
        }
      } catch {
        dispatch({ type: 'SET_LOCATION', payload: { isLoading: false } });
      }
    })();
  }, []);

  // Persist pricing when it changes
  const savePricing = useCallback(async (pricing: ContractorPricing) => {
    try {
      await AsyncStorage.setItem('contractor_pricing', JSON.stringify(pricing));
    } catch {}
  }, []);

  const saveName = useCallback(async (name: string) => {
    try {
      await AsyncStorage.setItem('contractor_name', name);
    } catch {}
  }, []);

  // Regional context for geo-pricing (state + zip + 30% margin; unknown = national average)
  const regional: RegionalContext = useMemo(
    () => buildRegionalContext(state.location.state?.trim() || null, state.location.zip || undefined, 30),
    [state.location.state, state.location.zip]
  );

  // Derived estimate (with regional multipliers, sales tax, margin formula)
  const estimate: EstimateResult | null = useMemo(() => {
    const lf = parseFloat(state.linearFeetStr);
    if (!lf || lf <= 0) return null;
    return runEstimate(
      {
        fenceType: state.fenceType,
        linearFeet: lf,
        gateCount: state.gateCount,
        terrain: state.terrain,
        pricing: state.pricing,
      },
      regional
    );
  }, [state.fenceType, state.linearFeetStr, state.gateCount, state.terrain, state.pricing, regional]);

  const hasEstimate = estimate !== null;
  const totalPrice = estimate?.costs.total ?? 0;

  const handleCopyQuote = async () => {
    if (!estimate) return;
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    const text = generateQuoteText(estimate, state.contractorName);
    await Clipboard.setStringAsync(text);
    Alert.alert('Copied!', 'Quote copied to clipboard.');
  };

  const handleShareQuote = async () => {
    if (!estimate) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    const text = generateQuoteText(estimate, state.contractorName);
    await Share.share({ message: text, title: 'Fence Estimate' });
  };

  const handleCloseJob = () => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
    Alert.alert(
      'Close Job',
      'Clear this estimate and start a new one?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Clear', style: 'destructive', onPress: () => {
          dispatch({ type: 'RESET_FORM' });
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
        }},
      ]
    );
  };

  const handleCopySupplierList = async () => {
    if (!estimate) return;
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    const text = generateSupplierList(estimate, state.contractorName);
    await Clipboard.setStringAsync(text);
    Alert.alert('Supplier List Copied!', 'Ready to send to your supplier.');
  };

  const toggleMaterialList = () => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    dispatch({ type: 'TOGGLE_MATERIAL_LIST' });
  };

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <View style={styles.root}>
          <StatusBar barStyle="light-content" />

      {/* Gradient background layers */}
      <View style={StyleSheet.absoluteFill}>
        <View style={styles.bgGradient1} />
        <View style={styles.bgGradient2} />
        <View style={styles.bgGradient3} />
      </View>

      <SafeAreaView style={{ flex: 1 }} edges={['top']}>
        {/* ── STICKY LIVE HEADER (Total Estimate + location tag) ── */}
        <StickyLiveHeader
          totalPrice={totalPrice}
          hasEstimate={hasEstimate}
          location={state.location}
          onManualOverride={() => dispatch({ type: 'TOGGLE_LOCATION_OVERRIDE' })}
        />

        <ScrollView
          ref={scrollRef}
          style={{ flex: 1 }}
          contentContainerStyle={[styles.scroll, { paddingBottom: insets.bottom + 100 }]}
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
        >
          {/* ── HEADER (company + gear) ── */}
          <GlassCard style={styles.header}>
            <View style={styles.headerLeft}>
              <Text style={styles.appTitle}>FenceQuote</Text>
              <TouchableOpacity onPress={() => dispatch({ type: 'TOGGLE_CONTRACTOR_EDIT' })}>
                {state.showContractorEdit ? (
                  <TextInput
                    style={styles.contractorInput}
                    value={state.contractorName}
                    onChangeText={(v) => {
                      dispatch({ type: 'SET_CONTRACTOR_NAME', payload: v });
                      saveName(v);
                    }}
                    placeholder="Your Company Name"
                    placeholderTextColor={D.textTertiary}
                    autoFocus
                    onSubmitEditing={() => dispatch({ type: 'TOGGLE_CONTRACTOR_EDIT' })}
                  />
                ) : (
                  <Text style={styles.contractorName}>
                    {state.contractorName || 'Tap to add company name ›'}
                  </Text>
                )}
              </TouchableOpacity>
            </View>
            <TouchableOpacity
              style={styles.gearBtn}
              onPress={() => dispatch({ type: 'TOGGLE_PRICING_SHEET' })}
            >
              <Text style={styles.gearIcon}>⚙️</Text>
            </TouchableOpacity>
          </GlassCard>

          {/* ── PROJECT DIMENSIONS ── */}
          <View style={styles.sectionGap} />
          <Text style={styles.cardSectionTitle}>PROJECT DIMENSIONS</Text>
          <GlassCard>
            <Text style={styles.inputLabel}>Fence Type</Text>
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.pillScroll}
              style={{ marginHorizontal: -4, marginBottom: 16 }}
            >
              {FENCE_TYPES.map((ft) => {
                const active = state.fenceType === ft.id;
                return (
                  <TouchableOpacity
                    key={ft.id}
                    style={[styles.pill, active && styles.pillActive]}
                    onPress={() => {
                      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                      dispatch({ type: 'SET_FENCE_TYPE', payload: ft.id });
                    }}
                  >
                    <Text style={styles.pillIcon}>{ft.icon}</Text>
                    <Text style={[styles.pillText, active && styles.pillTextActive]}>
                      {ft.label}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </ScrollView>

            <View style={styles.divider} />

            <View style={styles.lfRow}>
              <Text style={styles.inputLabel}>Linear Footage</Text>
              <View style={styles.lfInputRow}>
                <TextInput
                  style={styles.lfInput}
                  value={state.linearFeetStr}
                  keyboardType="numeric"
                  onChangeText={(v) => dispatch({ type: 'SET_LINEAR_FEET', payload: v })}
                  placeholder="0"
                  placeholderTextColor={D.textTertiary}
                  maxLength={6}
                />
                <Text style={styles.lfUnit}>ft</Text>
              </View>
            </View>

            <View style={styles.divider} />

            <SegmentControl
              label="Section Length"
              options={[{ id: 6 as 6 | 8, label: '6 ft' }, { id: 8 as 6 | 8, label: '8 ft' }]}
              value={state.sectionLength}
              onChange={(v) => dispatch({ type: 'SET_SECTION_LENGTH', payload: v })}
            />

            <View style={styles.divider} />

            <Stepper
              label="Walk Gates"
              value={state.gateCount.walk}
              onChange={(v) => dispatch({ type: 'SET_GATE_WALK', payload: v })}
            />
            <View style={styles.dividerLight} />
            <Stepper
              label="Drive Gates"
              value={state.gateCount.drive}
              onChange={(v) => dispatch({ type: 'SET_GATE_DRIVE', payload: v })}
            />
          </GlassCard>

          {/* ── SITE COMPLEXITY ── */}
          <View style={styles.sectionGap} />
          <Text style={styles.cardSectionTitle}>SITE COMPLEXITY</Text>
          <GlassCard>
            <SegmentControl
              label="Terrain"
              options={[
                { id: 'flat' as Terrain, label: 'Flat' },
                { id: 'slope' as Terrain, label: 'Slope +15%' },
                { id: 'hilly' as Terrain, label: 'Hilly +30%' },
              ]}
              value={state.terrain}
              onChange={(v) => dispatch({ type: 'SET_TERRAIN', payload: v })}
            />
          </GlassCard>

          {/* ── ESTIMATE BREAKDOWN ── */}
          <View style={styles.sectionGap} />
          <Text style={styles.cardSectionTitle}>ESTIMATE</Text>
          <GlassCard style={!hasEstimate ? styles.dimCard : undefined}>
            {!hasEstimate ? (
              <Text style={styles.emptyEstimate}>Enter linear footage above to see breakdown ↑</Text>
            ) : (
              <>
                <View style={styles.calcRow}>
                  <Text style={styles.calcLabel}>Materials</Text>
                  <AnimatedNumber value={estimate.costs.materialCostMarked} style={styles.calcValue} />
                </View>
                <View style={styles.dividerLight} />
                <View style={styles.calcRow}>
                  <Text style={styles.calcLabel}>Labor</Text>
                  <AnimatedNumber value={estimate.costs.laborCost + estimate.costs.gateLabor} style={styles.calcValue} />
                </View>
                <View style={styles.divider} />
                <View style={styles.calcRow}>
                  <Text style={[styles.calcLabel, styles.calcLabelSecondary]}>Per Linear Foot</Text>
                  <AnimatedNumber value={estimate.costs.perLinearFoot} style={[styles.calcValue, styles.calcValueSecondary]} />
                </View>
              </>
            )}
          </GlassCard>

          {/* ── MATERIAL LIST ACCORDION ── */}
          {hasEstimate && (
            <>
              <View style={styles.sectionGap} />
              <TouchableOpacity style={styles.accordionHeader} onPress={toggleMaterialList}>
                <Text style={styles.accordionTitle}>
                  📋 Material List ({estimate.lineItems.length} items)
                </Text>
                <Text style={styles.accordionChevron}>
                  {state.showMaterialList ? '▲' : '▼'}
                </Text>
              </TouchableOpacity>

              {state.showMaterialList && (
                <GlassCard style={{ paddingTop: 0 }}>
                  {/* Header row */}
                  <View style={[styles.materialRow, styles.materialHeader]}>
                    <Text style={[styles.materialCell, styles.materialHeaderText, { flex: 2 }]}>Item</Text>
                    <Text style={[styles.materialCell, styles.materialHeaderText, { textAlign: 'center' }]}>Qty</Text>
                    <Text style={[styles.materialCell, styles.materialHeaderText, { textAlign: 'right' }]}>Cost</Text>
                    <Text style={[styles.materialCell, styles.materialHeaderText, { textAlign: 'right' }]}>Total</Text>
                  </View>
                  {estimate.lineItems.map((item, i) => (
                    <View key={i} style={[styles.materialRow, i % 2 === 1 && styles.materialRowAlt]}>
                      <Text style={[styles.materialCell, { flex: 2 }]}>{item.label}</Text>
                      <Text style={[styles.materialCell, { textAlign: 'center' }]}>{item.qty}</Text>
                      <Text style={[styles.materialCell, { textAlign: 'right', color: D.textSecondary }]}>
                        {formatCurrency(item.unitCost)}
                      </Text>
                      <Text style={[styles.materialCell, { textAlign: 'right' }]}>
                        {formatCurrency(item.subtotal)}
                      </Text>
                    </View>
                  ))}
                  <View style={[styles.divider, { marginVertical: 12 }]} />
                  <TouchableOpacity style={styles.supplierBtn} onPress={handleCopySupplierList}>
                    <Text style={styles.supplierBtnText}>📤 Copy Supplier Order</Text>
                  </TouchableOpacity>
                </GlassCard>
              )}
            </>
          )}

          {/* ── LOCATION OVERRIDE SHEET ── */}
          {state.showLocationOverride && (
            <>
              <View style={styles.sectionGap} />
              <GlassCard>
                <Text style={styles.sheetTitle}>📍 Set job location</Text>
                <Text style={[styles.stickyHeaderCaption, { marginBottom: 12 }]}>
                  Pricing uses regional labor & materials and local sales tax.
                </Text>
                <View style={styles.locationFormRow}>
                  <Text style={styles.pricingRowLabel}>City</Text>
                  <TextInput
                    style={styles.locationInput}
                    value={state.location.city}
                    onChangeText={(v) => dispatch({ type: 'SET_LOCATION', payload: { city: v } })}
                    placeholder="e.g. Smyrna"
                    placeholderTextColor={D.textTertiary}
                  />
                </View>
                <View style={styles.locationFormRow}>
                  <Text style={styles.pricingRowLabel}>State</Text>
                  <TextInput
                    style={[styles.locationInput, { maxLength: 2, textTransform: 'uppercase' }]}
                    value={state.location.state}
                    onChangeText={(v) => dispatch({ type: 'SET_LOCATION', payload: { state: v.toUpperCase().slice(0, 2) } })}
                    placeholder="e.g. TN"
                    placeholderTextColor={D.textTertiary}
                  />
                </View>
                <View style={styles.locationFormRow}>
                  <Text style={styles.pricingRowLabel}>Zip</Text>
                  <TextInput
                    style={[styles.locationInput, { maxLength: 10 }]}
                    value={state.location.zip}
                    onChangeText={(v) => dispatch({ type: 'SET_LOCATION', payload: { zip: v } })}
                    placeholder="e.g. 37167"
                    placeholderTextColor={D.textTertiary}
                    keyboardType="number-pad"
                  />
                </View>
                <View style={{ flexDirection: 'row', gap: 10, marginTop: 16 }}>
                  <TouchableOpacity
                    style={[styles.supplierBtn, { flex: 1 }]}
                    onPress={async () => {
                      dispatch({ type: 'SET_LOCATION', payload: { isManual: true, isLoading: false } });
                      try {
                        await AsyncStorage.setItem('location_override', JSON.stringify({
                          city: state.location.city,
                          state: state.location.state,
                          zip: state.location.zip,
                          isManual: true,
                        }));
                      } catch {}
                      dispatch({ type: 'TOGGLE_LOCATION_OVERRIDE' });
                      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
                    }}
                  >
                    <Text style={styles.supplierBtnText}>Save location</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[styles.actionBtn, { flex: 1 }]}
                    onPress={() => dispatch({ type: 'TOGGLE_LOCATION_OVERRIDE' })}
                  >
                    <Text style={styles.actionBtnText}>Cancel</Text>
                  </TouchableOpacity>
                </View>
              </GlassCard>
            </>
          )}

          {/* ── PRICING CONFIG SHEET ── */}
          {state.showPricingSheet && (
            <>
              <View style={styles.sectionGap} />
              <GlassCard>
                <Text style={styles.sheetTitle}>⚙️  Your Pricing Config</Text>
                <Text style={[styles.sectionLabel, { marginTop: 16, marginBottom: 4 }]}>MATERIAL COSTS</Text>
                {[
                  { label: 'Post (4×4×8)',     key: 'postCost' as keyof ContractorPricing },
                  { label: 'Rail (2×4×8)',     key: 'railCost' as keyof ContractorPricing },
                  { label: 'Picket (1×6×6)',   key: 'picketCost' as keyof ContractorPricing },
                  { label: 'Panel',            key: 'panelCost' as keyof ContractorPricing },
                  { label: 'Concrete (80lb)',  key: 'concreteCost' as keyof ContractorPricing },
                  { label: 'Hardware Kit',     key: 'hardwareKitCost' as keyof ContractorPricing },
                  { label: 'Walk Gate',        key: 'walkGateCost' as keyof ContractorPricing },
                  { label: 'Drive Gate',       key: 'driveGateCost' as keyof ContractorPricing },
                ].map(({ label, key }) => (
                  <PricingRow
                    key={key}
                    label={label}
                    value={state.pricing[key] as number}
                    onChange={(v) => {
                      const updated = { ...state.pricing, [key]: v };
                      dispatch({ type: 'SET_PRICING', payload: { [key]: v } });
                      savePricing(updated);
                    }}
                  />
                ))}

                <Text style={[styles.sectionLabel, { marginTop: 20, marginBottom: 4 }]}>LABOR</Text>
                {[
                  { label: 'Rate per Foot', key: 'laborRatePerFoot' as keyof ContractorPricing },
                  { label: 'Gate Install',  key: 'gateInstallRate' as keyof ContractorPricing },
                ].map(({ label, key }) => (
                  <PricingRow
                    key={key}
                    label={label}
                    value={state.pricing[key] as number}
                    onChange={(v) => {
                      dispatch({ type: 'SET_PRICING', payload: { [key]: v } });
                      savePricing({ ...state.pricing, [key]: v });
                    }}
                  />
                ))}

                <Text style={[styles.sectionLabel, { marginTop: 20, marginBottom: 4 }]}>OVERHEAD</Text>
                <View style={styles.pricingRow}>
                  <Text style={styles.pricingRowLabel}>Material Markup %</Text>
                  <View style={styles.pricingInput}>
                    <TextInput
                      style={styles.pricingInputText}
                      value={state.pricing.markupPercent === 0 ? '' : String(state.pricing.markupPercent)}
                      keyboardType="numeric"
                      onChangeText={(v) => {
                        const val = parseFloat(v) || 0;
                        dispatch({ type: 'SET_PRICING', payload: { markupPercent: val } });
                        savePricing({ ...state.pricing, markupPercent: val });
                      }}
                      placeholder="20"
                      placeholderTextColor={D.textTertiary}
                      selectTextOnFocus
                    />
                    <Text style={styles.pricingPrefix}>%</Text>
                  </View>
                </View>
                <View style={styles.pricingRow}>
                  <Text style={styles.pricingRowLabel}>Waste Buffer %</Text>
                  <View style={styles.pricingInput}>
                    <TextInput
                      style={styles.pricingInputText}
                      value={state.pricing.wastePercent === 0 ? '' : String(state.pricing.wastePercent)}
                      keyboardType="numeric"
                      onChangeText={(v) => {
                        const val = parseFloat(v) || 0;
                        dispatch({ type: 'SET_PRICING', payload: { wastePercent: val } });
                        savePricing({ ...state.pricing, wastePercent: val });
                      }}
                      placeholder="10"
                      placeholderTextColor={D.textTertiary}
                      selectTextOnFocus
                    />
                    <Text style={styles.pricingPrefix}>%</Text>
                  </View>
                </View>

                <View style={styles.pricingRow}>
                  <Text style={styles.pricingRowLabel}>Round quote to $25</Text>
                  <Switch
                    value={state.roundQuoteTo25}
                    onValueChange={(v) => dispatch({ type: 'SET_ROUND_QUOTE_TO_25', payload: v })}
                    trackColor={{ false: D.textTertiary, true: D.forestGreen + '99' }}
                    thumbColor={state.roundQuoteTo25 ? D.forestGreen : '#f4f3f4'}
                  />
                </View>

                <View style={{ height: 16 }} />
                <TouchableOpacity
                  style={styles.resetBtn}
                  onPress={() => {
                    dispatch({ type: 'LOAD_PRICING', payload: DEFAULT_PRICING });
                    savePricing(DEFAULT_PRICING);
                  }}
                >
                  <Text style={styles.resetBtnText}>Reset to Defaults</Text>
                </TouchableOpacity>
              </GlassCard>
            </>
          )}
        </ScrollView>

        {/* ── ACTION BAR (fixed bottom) ── */}
        <BlurView intensity={60} tint="dark" style={[styles.actionBar, { paddingBottom: insets.bottom + 8 }]}>
          <TouchableOpacity
            style={[styles.actionBtn, !hasEstimate && styles.actionBtnDisabled]}
            onPress={handleCopyQuote}
            disabled={!hasEstimate}
          >
            <Text style={styles.actionBtnIcon}>📋</Text>
            <Text style={styles.actionBtnText}>Copy</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.actionBtnPrimary, !hasEstimate && styles.actionBtnDisabled]}
            onPress={handleShareQuote}
            disabled={!hasEstimate}
          >
            <Text style={styles.actionBtnIcon}>📤</Text>
            <Text style={[styles.actionBtnText, { color: '#000', fontWeight: '700' }]}>Share Quote</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.actionBtn, { borderColor: D.red + '44' }]}
            onPress={handleCloseJob}
          >
            <Text style={styles.actionBtnIcon}>✅</Text>
            <Text style={styles.actionBtnText}>Close Job</Text>
          </TouchableOpacity>
        </BlurView>
      </SafeAreaView>
        </View>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

// ─── StyleSheet ───────────────────────────────────────────
const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: D.bg,
  },
  bgGradient1: {
    position: 'absolute',
    width: 400, height: 400,
    borderRadius: 200,
    backgroundColor: '#0D1B4B',
    opacity: 0.6,
    top: -80, left: -80,
  },
  bgGradient2: {
    position: 'absolute',
    width: 350, height: 350,
    borderRadius: 175,
    backgroundColor: '#0A2A1A',
    opacity: 0.4,
    top: 300, right: -100,
  },
  bgGradient3: {
    position: 'absolute',
    width: 500, height: 500,
    borderRadius: 250,
    backgroundColor: '#050520',
    opacity: 0.8,
    bottom: -100, left: -50,
  },
  scroll: {
    paddingHorizontal: 16,
    paddingTop: 12,
  },
  glassCardWrap: {
    borderRadius: D.radius,
    overflow: 'hidden',
    ...D.cardShadow,
  },
  glassCardBlur: {
    borderRadius: D.radius,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: D.glassBorder,
  },
  glassCardBorder: {
    padding: 20,
  },
  dimCard: {
    opacity: 0.55,
  },
  stickyHeader: {
    overflow: 'hidden',
  },
  stickyHeaderContent: {
    paddingVertical: 14,
    paddingHorizontal: 20,
    paddingTop: 10,
  },
  stickyHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 2,
  },
  stickyHeaderLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: D.textSecondary,
    letterSpacing: 0.8,
  },
  locationOverrideBtn: {
    paddingVertical: 4,
    paddingHorizontal: 10,
  },
  locationOverrideBtnText: {
    fontSize: 12,
    color: D.contractorBlue,
    fontWeight: '600',
  },
  stickyHeaderTotal: {
    fontSize: 34,
    fontWeight: '700',
    color: D.textPrimary,
    letterSpacing: -1,
    fontFamily: Platform.OS === 'ios' ? 'SF Pro Display' : undefined,
  },
  stickyHeaderPlaceholder: {
    fontSize: 22,
    fontWeight: '500',
    color: D.textTertiary,
  },
  stickyHeaderCaption: {
    fontSize: 12,
    color: D.textTertiary,
    marginTop: 4,
  },
  cardSectionTitle: {
    fontSize: 11,
    fontWeight: '700',
    color: D.textTertiary,
    letterSpacing: 1.2,
    marginBottom: 8,
    marginLeft: 4,
  },
  segmentWrap: {
    marginBottom: 4,
  },
  segmentLabel: {
    fontSize: 16,
    color: D.textSecondary,
    fontWeight: '500',
    marginBottom: 10,
  },
  segmentTrack: {
    flexDirection: 'row',
    height: 36,
    borderRadius: 10,
    backgroundColor: 'rgba(255,255,255,0.08)',
    position: 'relative',
  },
  segmentGlass: {
    position: 'absolute',
    top: 4,
    bottom: 4,
    borderRadius: 8,
    backgroundColor: 'rgba(255,255,255,0.18)',
  },
  segmentOption: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  segmentOptionText: {
    fontSize: 15,
    color: D.textSecondary,
    fontWeight: '500',
  },
  segmentOptionTextActive: {
    color: D.textPrimary,
    fontWeight: '600',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  headerLeft: { flex: 1 },
  appTitle: {
    fontSize: 28,
    fontWeight: '700',
    color: D.textPrimary,
    fontFamily: Platform.OS === 'ios' ? 'SF Pro Rounded' : undefined,
    letterSpacing: -0.5,
  },
  contractorName: {
    fontSize: 14,
    color: D.textSecondary,
    marginTop: 2,
  },
  contractorInput: {
    fontSize: 14,
    color: D.textPrimary,
    borderBottomWidth: 1,
    borderBottomColor: D.contractorBlue,
    paddingVertical: 2,
    marginTop: 2,
    width: 200,
  },
  gearBtn: {
    width: 40, height: 40,
    alignItems: 'center', justifyContent: 'center',
    borderRadius: 12,
    backgroundColor: D.glass,
  },
  gearIcon: { fontSize: 20 },
  sectionGap: { height: 20 },
  sectionLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: D.textTertiary,
    letterSpacing: 1.2,
    marginBottom: 8,
    marginLeft: 4,
  },
  // Pill selector
  pillScroll: {
    paddingLeft: 4,
    paddingRight: 16,
    gap: 8,
    flexDirection: 'row',
  },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: D.radiusPill,
    borderWidth: 1,
    borderColor: D.glassBorder,
    backgroundColor: D.glass,
    gap: 6,
  },
  pillActive: {
    backgroundColor: D.contractorBlue + 'CC',
    borderColor: D.contractorBlue,
  },
  pillIcon: { fontSize: 14 },
  pillText: {
    fontSize: 14,
    color: D.textSecondary,
    fontWeight: '500',
  },
  pillTextActive: { color: '#FFFFFF' },
  // Measurement inputs
  lfRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  inputLabel: {
    fontSize: 16,
    color: D.textSecondary,
    fontWeight: '500',
  },
  lfInputRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: 4,
  },
  lfInput: {
    fontSize: 36,
    fontWeight: '700',
    color: D.textPrimary,
    textAlign: 'right',
    minWidth: 100,
    fontFamily: Platform.OS === 'ios' ? 'SF Pro Display' : undefined,
  },
  lfUnit: {
    fontSize: 20,
    color: D.textSecondary,
    fontWeight: '500',
  },
  divider: {
    height: 1,
    backgroundColor: D.glassBorder,
    marginVertical: 12,
  },
  dividerLight: {
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.07)',
    marginVertical: 8,
  },
  // Stepper
  stepperRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 4,
  },
  stepperLabel: {
    fontSize: 16,
    color: D.textSecondary,
    fontWeight: '500',
  },
  stepperControls: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  stepperBtn: {
    width: 36, height: 36,
    borderRadius: 18,
    backgroundColor: 'rgba(255,255,255,0.12)',
    alignItems: 'center', justifyContent: 'center',
  },
  stepperBtnText: {
    fontSize: 22,
    color: D.textPrimary,
    lineHeight: 28,
  },
  stepperPillValue: {
    fontSize: 20,
    fontWeight: '700',
    color: D.textPrimary,
    minWidth: 48,
    textAlign: 'center',
  },
  stepperValue: {
    fontSize: 22,
    fontWeight: '700',
    color: D.textPrimary,
    minWidth: 28,
    textAlign: 'center',
  },
  stepperPill: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderRadius: D.radiusPill,
    paddingVertical: 4,
    paddingHorizontal: 4,
    gap: 0,
  },
  stepperPillBtn: {
    width: 44,
    height: 36,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 18,
  },
  stepperPillBtnPlus: {
    backgroundColor: D.contractorBlue + '28',
  },
  stepperPillBtnText: {
    fontSize: 22,
    color: D.textPrimary,
    lineHeight: 28,
    fontWeight: '400',
  },
  // Terrain (legacy; SegmentControl used now)
  terrainRow: {
    flexDirection: 'row',
    gap: 8,
  },
  terrainBtn: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 10,
    borderRadius: D.radiusSmall,
    borderWidth: 1,
    borderColor: D.glassBorder,
    backgroundColor: D.glass,
    gap: 4,
  },
  terrainBtnActive: {
    backgroundColor: D.orange + '33',
    borderColor: D.orange,
  },
  terrainIcon: { fontSize: 18 },
  terrainLabel: {
    fontSize: 11,
    color: D.textSecondary,
    textAlign: 'center',
    fontWeight: '500',
  },
  terrainLabelActive: { color: D.orange },
  // Estimate panel
  calcRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 4,
  },
  calcLabel: {
    fontSize: 17,
    color: D.textSecondary,
    fontWeight: '400',
  },
  calcValue: {
    fontSize: 17,
    color: D.textPrimary,
    fontWeight: '600',
  },
  calcLabelSecondary: {
    color: D.textSecondary,
    fontSize: 13,
  },
  calcValueSecondary: {
    fontSize: 15,
    color: D.textSecondary,
  },
  totalRow: {
    alignItems: 'center',
    gap: 6,
  },
  totalLabel: {
    fontSize: 13,
    fontWeight: '700',
    color: D.textTertiary,
    letterSpacing: 1.5,
  },
  totalPrice: {
    fontSize: 52,
    fontWeight: '800',
    color: D.green,
    letterSpacing: -2,
    fontFamily: Platform.OS === 'ios' ? 'SF Pro Rounded' : undefined,
  },
  emptyEstimate: {
    fontSize: 15,
    color: D.textTertiary,
    textAlign: 'center',
    paddingVertical: 12,
  },
  // Material list accordion
  accordionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 4,
    marginBottom: 8,
  },
  accordionTitle: {
    fontSize: 16,
    color: D.textSecondary,
    fontWeight: '600',
  },
  accordionChevron: {
    fontSize: 12,
    color: D.textTertiary,
  },
  materialRow: {
    flexDirection: 'row',
    paddingVertical: 8,
    paddingHorizontal: 4,
    gap: 4,
  },
  materialRowAlt: {
    backgroundColor: 'rgba(255,255,255,0.04)',
    borderRadius: 8,
  },
  materialHeader: {
    borderBottomWidth: 1,
    borderBottomColor: D.glassBorder,
    marginBottom: 4,
    paddingBottom: 8,
  },
  materialHeaderText: {
    fontSize: 12,
    color: D.textTertiary,
    fontWeight: '700',
    letterSpacing: 0.5,
  },
  materialCell: {
    flex: 1,
    fontSize: 13,
    color: D.textPrimary,
  },
  supplierBtn: {
    backgroundColor: D.blue + '22',
    borderWidth: 1,
    borderColor: D.blue + '55',
    borderRadius: D.radiusSmall,
    paddingVertical: 12,
    alignItems: 'center',
  },
  supplierBtnText: {
    fontSize: 15,
    color: D.blue,
    fontWeight: '600',
  },
  locationFormRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.06)',
  },
  locationInput: {
    fontSize: 16,
    color: D.textPrimary,
    borderWidth: 1,
    borderColor: D.glassBorder,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 8,
    minWidth: 120,
    textAlign: 'right',
  },
  // Pricing sheet
  sheetTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: D.textPrimary,
    marginBottom: 4,
  },
  pricingRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.06)',
  },
  pricingRowLabel: {
    fontSize: 15,
    color: D.textSecondary,
    flex: 1,
  },
  pricingInput: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderRadius: 10,
    paddingHorizontal: 10,
    gap: 2,
  },
  pricingPrefix: {
    fontSize: 15,
    color: D.textSecondary,
  },
  pricingInputText: {
    fontSize: 15,
    color: D.textPrimary,
    textAlign: 'right',
    width: 70,
    paddingVertical: 6,
    fontWeight: '600',
  },
  resetBtn: {
    alignItems: 'center',
    paddingVertical: 8,
  },
  resetBtnText: {
    fontSize: 14,
    color: D.red,
    fontWeight: '500',
  },
  // Action bar
  actionBar: {
    position: 'absolute',
    bottom: 0, left: 0, right: 0,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: 12,
    gap: 10,
    borderTopWidth: 1,
    borderTopColor: D.glassBorder,
  },
  actionBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 14,
    borderRadius: D.radiusPill,
    borderWidth: 1,
    borderColor: D.glassBorder,
    backgroundColor: D.glass,
    gap: 6,
  },
  actionBtnPrimary: {
    flex: 2,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 14,
    borderRadius: D.radiusPill,
    backgroundColor: D.green,
    gap: 6,
  },
  actionBtnDisabled: {
    opacity: 0.35,
  },
  actionBtnIcon: { fontSize: 16 },
  actionBtnText: {
    fontSize: 14,
    fontWeight: '600',
    color: D.textPrimary,
  },
});
