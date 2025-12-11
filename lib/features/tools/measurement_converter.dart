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

  static double celsiusToFahrenheit(double celsius) => celsius * 9 / 5 + 32;
  static double fahrenheitToCelsius(double fahrenheit) => (fahrenheit - 32) * 5 / 9;

  static const Map<String, Map<String, double>> cookingTemps = {
    'Low': {'f': 250, 'c': 121},
    'Medium-Low': {'f': 300, 'c': 149},
    'Medium': {'f': 350, 'c': 177},
    'Medium-High': {'f': 375, 'c': 190},
    'High': {'f': 400, 'c': 204},
    'Very High': {'f': 450, 'c': 232},
    'Broil': {'f': 500, 'c': 260},
  };

  static double? convertVolume(double amount, String from, String to) {
    final fromFactor = volumeToMl[from.toLowerCase()];
    final toFactor = volumeToMl[to.toLowerCase()];
    if (fromFactor == null || toFactor == null) return null;
    final ml = amount * fromFactor;
    return ml / toFactor;
  }

  static double? convertWeight(double amount, String from, String to) {
    final fromFactor = weightToGrams[from.toLowerCase()];
    final toFactor = weightToGrams[to.toLowerCase()];
    if (fromFactor == null || toFactor == null) return null;
    final grams = amount * fromFactor;
    return grams / toFactor;
  }

  static double? convertTemperature(double temp, String from, String to) {
    from = from.toLowerCase();
    to = to.toLowerCase();
    if (from == to) return temp;
    if (from == 'c' || from == 'celsius') {
      if (to == 'f' || to == 'fahrenheit') return celsiusToFahrenheit(temp);
    } else if (from == 'f' || from == 'fahrenheit') {
      if (to == 'c' || to == 'celsius') return fahrenheitToCelsius(temp);
    }
    return null;
  }

  static String formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    final rounded = (value * 100).round() / 100;
    return rounded.toString().replaceAll(RegExp(r'\.?0+$'), '');
  }

  static List<String> get volumeUnits => [
    'tsp', 'tbsp', 'fl oz', 'cup', 'pint', 'quart', 'gallon', 'ml', 'l'
  ];

  static List<String> get weightUnits => ['g', 'kg', 'oz', 'lb'];

  static List<String> get temperatureUnits => ['°F', '°C'];
}

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
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTab = _tabController.index;
          _resetForTab();
        });
      }
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
      case 3: // Reference (no conversion units needed)
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Measurement Converter'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Conversion Type Selector
              Text(
                'Conversion Type',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                Expanded(
                  child: _ConversionTypeButton(
                    label: 'Volume',
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() {
                      _selectedTab = 0;
                      _resetForTab();
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ConversionTypeButton(
                    label: 'Weight',
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() {
                      _selectedTab = 1;
                      _resetForTab();
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ConversionTypeButton(
                    label: 'Temperature',
                    isSelected: _selectedTab == 2,
                    onTap: () => setState(() {
                      _selectedTab = 2;
                      _resetForTab();
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // From input
            Text(
              'From',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => _convert(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _fromUnit,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _getUnitsForTab().map((u) => DropdownMenuItem(
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
              ],
            ),
            const SizedBox(height: 24),
            
            // To output
            Text(
              'To',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _result.isEmpty ? 'Result' : _result,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: _result.isEmpty 
                            ? theme.colorScheme.outline
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _toUnit,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _getUnitsForTab().map((u) => DropdownMenuItem(
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
            const SizedBox(height: 24),
            
            // Clear button
            OutlinedButton(
              onPressed: () {
                _amountController.clear();
                setState(() => _result = '');
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Clear',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  List<String> _getUnitsForTab() {
    switch (_selectedTab) {
      case 0:
        return MeasurementConverter.volumeUnits;
      case 1:
        return MeasurementConverter.weightUnits;
      case 2:
        return MeasurementConverter.temperatureUnits;
      default:
        return [];
    }
  }
}

class _ConversionTypeButton extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConversionTypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ConversionTypeButton> createState() => _ConversionTypeButtonState();
}

class _ConversionTypeButtonState extends State<_ConversionTypeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showHighlight = widget.isSelected || _hovered;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected 
                ? theme.colorScheme.secondary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: showHighlight
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: showHighlight ? 1.5 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: widget.isSelected 
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: widget.isSelected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
