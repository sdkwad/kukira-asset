// Suggested reminders and templates. Legal and tax dates are editable estimates,
// never facts: every estimated preset shows "confirm with ...".

import '../l10n/strings.dart';

class Preset {
  const Preset({
    required this.key,
    required this.rule,
    this.repeatMonths,
    this.repeatKm,
    this.repeatFrom = 'completion',
    this.estimated = false,
    this.category = 'other',
    this.leadDays = 7,
    this.leadKm = 1000,
    this.defaultDue,
    this.profileField,
  });

  final String key;
  final String rule;
  final int? repeatMonths;
  final int? repeatKm;
  final String repeatFrom;
  final bool estimated;
  final String category;
  final int leadDays;
  final int leadKm;
  final DateTime Function(DateTime today)? defaultDue;

  /// roadTax | insurance: also copy the date into the vehicle profile.
  final String? profileField;

  String title(Str s) => s.presetTitle(key);
  String hint(Str s) => s.presetHint(key);
  String? note(Str s) => estimated ? s.presetNote(key) : null;
  String? confirm(Str s) => estimated ? s.presetConfirm(key) : null;
}

DateTime nextOn(DateTime today, int month, int day) {
  var d = DateTime(today.year, month, day);
  if (!d.isAfter(today)) d = DateTime(today.year + 1, month, day);
  return d;
}

/// Cukai taksiran: two halves, in arrears after the end of February and the end of August.
DateTime nextTaksiran(DateTime today) {
  final y = today.year;
  final options = [DateTime(y, 3, 0), DateTime(y, 8, 31), DateTime(y + 1, 3, 0)];
  return options.firstWhere((d) => d.isAfter(today));
}

final cukaiTanah = Preset(key: 'cukaiTanah', rule: 'repeat', repeatMonths: 12, repeatFrom: 'due', estimated: true, category: 'cukai_tanah', leadDays: 14, defaultDue: (t) => nextOn(t, 5, 31));
final cukaiPetak = Preset(key: 'cukaiPetak', rule: 'repeat', repeatMonths: 12, repeatFrom: 'due', estimated: true, category: 'cukai_petak', leadDays: 14, defaultDue: (t) => nextOn(t, 5, 31));
final cukaiTaksiran = Preset(key: 'cukaiTaksiran', rule: 'repeat', repeatMonths: 6, repeatFrom: 'due', estimated: true, category: 'cukai_taksiran', leadDays: 14, defaultDue: nextTaksiran);
const houseInsurance = Preset(key: 'houseInsurance', rule: 'fixed', category: 'insurance_premium', leadDays: 30);
final maintenanceCharge = Preset(key: 'maintenanceCharge', rule: 'repeat', repeatMonths: 1, repeatFrom: 'due', category: 'maintenance_charge', leadDays: 3, defaultDue: (t) => DateTime(t.year, t.month + 1, 1));
const aircond = Preset(key: 'aircond', rule: 'repeat', repeatMonths: 6, category: 'aircond');
const pestControl = Preset(key: 'pestControl', rule: 'repeat', repeatMonths: 3, category: 'pest_control');
const waterTank = Preset(key: 'waterTank', rule: 'repeat', repeatMonths: 12, category: 'plumbing');
const roadTax = Preset(key: 'roadTax', rule: 'fixed', category: 'road_tax', leadDays: 14, profileField: 'roadTax');
const vehicleInsurance = Preset(key: 'vehicleInsurance', rule: 'fixed', category: 'insurance_premium', leadDays: 30, profileField: 'insurance');
const carService = Preset(key: 'carService', rule: 'either', repeatMonths: 6, repeatKm: 10000, category: 'oil', leadDays: 14);
const motoOil = Preset(key: 'motoOil', rule: 'either', repeatMonths: 3, repeatKm: 3000, category: 'oil', leadKm: 300);
const tyres = Preset(key: 'tyres', rule: 'mileage', repeatKm: 40000, category: 'tyre', leadKm: 2000);
const battery = Preset(key: 'battery', rule: 'repeat', repeatMonths: 12, category: 'battery');
const chain = Preset(key: 'chain', rule: 'mileage', repeatKm: 3000, category: 'chain_sprocket', leadKm: 300);
const nextServiceCar = Preset(key: 'nextService', rule: 'repeat', repeatMonths: 6, category: 'oil');
const nextServiceMoto = Preset(key: 'nextOilChange', rule: 'repeat', repeatMonths: 3, category: 'oil');

/// Two or three chips offered right after adding an asset. Each needs only a date.
List<Preset> suggestionsFor(String category, String? propertyType) {
  switch (category) {
    case 'house':
      switch (propertyType) {
        case 'strata':
          return [maintenanceCharge, cukaiTaksiran, cukaiPetak];
        case 'strata_landed':
          return [maintenanceCharge, houseInsurance, cukaiTaksiran];
        default:
          return [cukaiTanah, cukaiTaksiran, houseInsurance];
      }
    case 'car':
      return [roadTax, vehicleInsurance, nextServiceCar];
    default:
      return [roadTax, vehicleInsurance, nextServiceMoto];
  }
}

/// Templates in the "New reminder" form.
List<Preset> templatesFor(String category, String? propertyType) {
  switch (category) {
    case 'house':
      final strata = propertyType == 'strata' || propertyType == 'strata_landed';
      return [
        aircond,
        pestControl,
        waterTank,
        if (propertyType == 'strata') cukaiPetak else cukaiTanah,
        cukaiTaksiran,
        if (strata) maintenanceCharge,
        if (propertyType != 'strata') houseInsurance,
      ];
    case 'car':
      return [carService, roadTax, vehicleInsurance, tyres, battery];
    default:
      return [motoOil, chain, roadTax, vehicleInsurance];
  }
}

// ---------------------------------------------------------------- record categories

const houseKinds = ['maintenance', 'renovation', 'incident', 'defect', 'payment'];
const vehicleKinds = ['maintenance', 'incident', 'payment'];

List<String> kindsFor(String assetCategory) => assetCategory == 'house' ? houseKinds : vehicleKinds;

List<String> categoriesFor(String assetCategory, String kind) {
  if (assetCategory == 'house') {
    switch (kind) {
      case 'renovation':
        return const ['minor', 'major'];
      case 'incident':
        return const ['leak', 'fire', 'flood', 'break_in', 'structural', 'other'];
      case 'defect':
        return const ['wall_crack', 'floor_tiles', 'door_window', 'plumbing', 'electrical', 'roof', 'other'];
      case 'payment':
        return const ['cukai_tanah', 'cukai_petak', 'cukai_taksiran', 'maintenance_charge', 'sinking_fund', 'insurance_premium'];
      default:
        return const ['plumbing', 'bathroom', 'roof', 'leakage', 'electrical', 'aircond', 'painting', 'pest_control', 'appliance', 'other'];
    }
  }
  switch (kind) {
    case 'incident':
      return const ['accident', 'flood', 'theft', 'other'];
    case 'payment':
      return const ['road_tax', 'insurance_premium'];
    default:
      return [
        'oil', 'filter', 'brake', 'tyre', 'battery', 'belt',
        if (assetCategory == 'motorcycle') 'chain_sprocket',
        if (assetCategory == 'car') 'aircond',
        'other',
      ];
  }
}
