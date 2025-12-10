import 'package:flutter/material.dart';

/// Measurement conversion utility for cooking
class MeasurementConverter {
  // Volume conversions to milliliters (base unit)
  static const Map<String, double> volumeToMl = {
    'ml': 1.0,
    'milliliter': 1.0,
    'milliliters': 1.0,
    'l': 1000.0,
    'liter': 1000.0,
    'liters': 1000.0,
    'tsp': 4.929,
    'teaspoon': 4.929,
    'teaspoons': 4.929,
    'tbsp': 14.787,
    'tablespoon': 14.787,
    'tablespoons': 14.787,
    'fl oz': 29.574,
    'fluid ounce': 29.574,
    'fluid ounces': 29.574,
    'cup': 236.588,
    'cups': 236.588,
    'c': 236.588,
    'pint': 473.176,
    'pints': 473.176,
    'pt': 473.176,
    'quart': 946.353,
    'quarts': 946.353,
    'qt': 946.353,
    'gallon': 3785.41,
    'gallons': 3785.41,
    'gal': 3785.41,
  };

  // Weight conversions to grams (base unit)
  static const Map<String, double> weightToGrams = {
    'g': 1.0,
    'gram': 1.0,
    'grams': 1.0,
    'kg': 1000.0,
    'kilogram': 1000.0,
    'kilograms': 1000.0,
    'oz': 28.3495,
    'ounce': 28.3495,
    'ounces': 28.3495,
    'lb': 453.592,
    'pound': 453.592,
    'pounds': 453.592,
    'lbs': 453.592,
  };

  // Temperature conversions
  static double celsiusToFahrenheit(double celsius) => celsius * 9 / 5 + 32;
  static double fahrenheitToCelsius(double fahrenheit) => (fahrenheit - 32) * 5 / 9;

  // Common cooking temperatures
  static const Map<String, Map<String, double>> cookingTemps = {
    'Low': {'f': 250, 'c': 121},
    'Medium-Low': {'f': 300, 'c': 149},
    'Medium': {'f': 350, 'c': 177},
    'Medium-High': {'f': 375, 'c': 190},
    'High': {'f': 400, 'c': 204},
    'Very High': {'f': 450, 'c': 232},
    'Broil': {'f': 500, 'c': 260},
  };

  /// Convert volume from one unit to another
  static double? convertVolume(double amount, String from, String to) {
    final fromFactor = volumeToMl[from.toLowerCase()];
    final toFactor = volumeToMl[to.toLowerCase()];

    if (fromFactor == null || toFactor == null) return null;

    final ml = amount * fromFactor;
    return ml / toFactor;
  }

  /// Convert weight from one unit to another
  static double? convertWeight(double amount, String from, String to) {
    final fromFactor = weightToGrams[from.toLowerCase()];
    final toFactor = weightToGrams[to.toLowerCase()];

    if (fromFactor == null || toFactor == null) return null;

    final grams = amount * fromFactor;
    return grams / toFactor;
  }

  /// Convert temperature
  static double? convertTemperature(double temp, String from, String to) {
    from = from.toLowerCase();
    to = to.toLowerCase();

    if (from == to) return temp;

    if (from == 'c' || from == 'celsius') {
      if (to == 'f' || to == 'fahrenheit') {
        return celsiusToFahrenheit(temp);
      }
    } else if (from == 'f' || from == 'fahrenheit') {
      if (to == 'c' || to == 'celsius') {
        return fahrenheitToCelsius(temp);
      }
    }

    return null;
  }

  /// Format a number nicely (remove trailing zeros, round to 2 decimal places)
  static String formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    // Round to 2 decimal places
    final rounded = (value * 100).round() / 100;
    return rounded.toString().replaceAll(RegExp(r'\.?0+$'), '');
  }

  /// Get common equivalent measurements
  static List<String> getEquivalents(double amount, String unit) {
    final equivalents = <String>[];
    final unitLower = unit.toLowerCase();

    // Volume equivalents
    if (volumeToMl.containsKey(unitLower)) {
      final targetUnits = ['tsp', 'tbsp', 'cup', 'ml', 'l'];
      for (final target in targetUnits) {
        if (target != unitLower) {
          final converted = convertVolume(amount, unit, target);
          if (converted != null && converted > 0.01 && converted < 10000) {
            equivalents.add('${formatNumber(converted)} $target');
          }
        }
      }
    }

    // Weight equivalents
    if (weightToGrams.containsKey(unitLower)) {
      final targetUnits = ['g', 'kg', 'oz', 'lb'];
      for (final target in targetUnits) {
        if (target != unitLower) {
          final converted = convertWeight(amount, unit, target);
          if (converted != null && converted > 0.01 && converted < 10000) {
            equivalents.add('${formatNumber(converted)} $target');
          }
        }
      }
    }

    return equivalents;
  }

  /// Check if a unit is recognized
  static bool isVolumeUnit(String unit) => volumeToMl.containsKey(unit.toLowerCase());
  static bool isWeightUnit(String unit) => weightToGrams.containsKey(unit.toLowerCase());
  static bool isTemperatureUnit(String unit) {
    final u = unit.toLowerCase();
    return u == 'c' || u == 'celsius' || u == 'f' || u == 'fahrenheit';
  }

  /// Get all supported volume units
  static List<String> get volumeUnits => [
    'tsp', 'tbsp', 'fl oz', 'cup', 'pint', 'quart', 'gallon', 'ml', 'l'
  ];

  /// Get all supported weight units
  static List<String> get weightUnits => ['g', 'kg', 'oz', 'lb'];

  /// Get all supported temperature units
  static List<String> get temperatureUnits => ['°F', '°C'];
}

/// Common cooking conversions quick reference
class CookingConversions {
  static const Map<String, String> quickReference = {
    '3 tsp': '1 tbsp',
    '2 tbsp': '1 fl oz',
    '4 tbsp': '¼ cup',
    '5⅓ tbsp': '⅓ cup',
    '8 tbsp': '½ cup',
    '16 tbsp': '1 cup',
    '1 cup': '8 fl oz',
    '2 cups': '1 pint',
    '4 cups': '1 quart',
    '4 quarts': '1 gallon',
    '1 stick butter': '½ cup / 8 tbsp',
    '1 lb butter': '4 sticks / 2 cups',
  };

  static const Map<String, String> ingredientWeights = {
    '1 cup flour': '~120g',
    '1 cup sugar': '~200g',
    '1 cup brown sugar': '~220g',
    '1 cup powdered sugar': '~120g',
    '1 cup butter': '~227g',
    '1 cup rice': '~185g',
    '1 cup oats': '~90g',
    '1 cup milk': '~245g',
    '1 cup water': '~236g',
    '1 cup honey': '~340g',
    '1 large egg': '~50g',
    '1 egg white': '~30g',
    '1 egg yolk': '~17g',
  };
}

/// UI Widget for measurement conversion
class MeasurementConverterWidget extends StatefulWidget {
  const MeasurementConverterWidget({super.key});

  @override
  State<MeasurementConverterWidget> createState() => _MeasurementConverterWidgetState();
}

class _MeasurementConverterWidgetState extends State<MeasurementConverterWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountController = TextEditingController();
  String _fromUnit = 'cup';
  String _toUnit = 'ml';
  String _result = '';
  int _selectedTab = 0; // 0: volume, 1: weight, 2: temperature

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index;
        _resetForTab();
      });
    });
  }

  void _resetForTab() {
    _amountController.clear();
    _result = '';
    switch (_selectedTab) {
      case 0: // Volume
        _fromUnit = 'cup';
        _toUnit = 'ml';
        break;
      case 1: // Weight
        _fromUnit = 'oz';
        _toUnit = 'g';
        break;
      case 2: // Temperature
        _fromUnit = '°F';
        _toUnit = '°C';
        break;
    }
  }

  void _convert() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null) {
      setState(() => _result = '');
      return;
    }

    double? converted;
    switch (_selectedTab) {
      case 0:
        converted = MeasurementConverter.convertVolume(amount, _fromUnit, _toUnit);
        break;
      case 1:
        converted = MeasurementConverter.convertWeight(amount, _fromUnit, _toUnit);
        break;
      case 2:
        final from = _fromUnit == '°F' ? 'f' : 'c';
        final to = _toUnit == '°F' ? 'f' : 'c';
        converted = MeasurementConverter.convertTemperature(amount, from, to);
        break;
    }

    if (converted != null) {
      setState(() {
        _result = MeasurementConverter.formatNumber(converted!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unit Converter'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.water_drop), text: 'Volume'),
            Tab(icon: Icon(Icons.scale), text: 'Weight'),
            Tab(icon: Icon(Icons.thermostat), text: 'Temp'),
            Tab(icon: Icon(Icons.menu_book), text: 'Reference'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConverterTab(MeasurementConverter.volumeUnits),
          _buildConverterTab(MeasurementConverter.weightUnits),
          _buildConverterTab(MeasurementConverter.temperatureUnits),
          _buildReferenceTab(),
        ],
      ),
    );
  }

  Widget _buildConverterTab(List<String> units) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Amount input
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _convert(),
          ),
          const SizedBox(height: 16),
          // From unit
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _fromUnit,
                  decoration: const InputDecoration(
                    labelText: 'From',
                    border: OutlineInputBorder(),
                  ),
                  items: units.map((u) => DropdownMenuItem(
                    value: u,
                    child: Text(u),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _fromUnit = v);
                      _convert();
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () {
                    setState(() {
                      final temp = _fromUnit;
                      _fromUnit = _toUnit;
                      _toUnit = temp;
                    });
                    _convert();
                  },
                ),
              ),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _toUnit,
                  decoration: const InputDecoration(
                    labelText: 'To',
                    border: OutlineInputBorder(),
                  ),
                  items: units.map((u) => DropdownMenuItem(
                    value: u,
                    child: Text(u),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _toUnit = v);
                      _convert();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Result
          if (_result.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    _result,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _toUnit,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),
          // Quick equivalents
          if (_selectedTab == 2) ...[
            Text(
              'Common Cooking Temperatures',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...MeasurementConverter.cookingTemps.entries.map((e) {
              return ListTile(
                title: Text(e.key),
                trailing: Text(
                  '${e.value['f']?.toInt()}°F / ${e.value['c']?.toInt()}°C',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildReferenceTab() {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Quick Conversions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...CookingConversions.quickReference.entries.map((e) {
          return ListTile(
            dense: true,
            title: Text(e.key),
            trailing: Text(
              '= ${e.value}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        }),
        const Divider(height: 32),
        Text(
          'Common Ingredient Weights',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...CookingConversions.ingredientWeights.entries.map((e) {
          return ListTile(
            dense: true,
            title: Text(e.key),
            trailing: Text(
              e.value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        }),
      ],
    );
  }
}
