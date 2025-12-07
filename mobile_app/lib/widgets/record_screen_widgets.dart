import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/cc1101/cc1101_values.dart';

/// Комбинированный селектор частоты с валидацией
class FrequencySelector extends StatefulWidget {
  final TextEditingController controller;
  final double? value;
  final ValueChanged<double?>? onChanged;
  final bool enabled;

  const FrequencySelector({
    super.key,
    required this.controller,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<FrequencySelector> createState() => _FrequencySelectorState();
}

class _FrequencySelectorState extends State<FrequencySelector> {
  String? _errorText;
  String? _selectedPreset;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) {
      widget.controller.text = widget.value!.toStringAsFixed(2);
      // Проверяем, есть ли эта частота в предопределенных
      final freqString = widget.value!.toStringAsFixed(2);
      if (CC1101Values.frequencies.contains(freqString)) {
        _selectedPreset = freqString;
      }
    }
    widget.controller.addListener(_validateFrequency);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validateFrequency);
    super.dispose();
  }

  void _validateFrequency() {
    final text = widget.controller.text;
    if (text.isEmpty) {
      setState(() => _errorText = 'Frequency is required');
      return;
    }

    final frequency = double.tryParse(text);
    if (frequency == null) {
      setState(() => _errorText = 'Invalid frequency format');
      return;
    }

    if (!CC1101Values.isValidFrequency(frequency)) {
      final closest = CC1101Values.getClosestValidFrequency(frequency);
      if (closest != null) {
        setState(() => _errorText = 'Invalid frequency. Closest valid: ${closest.toStringAsFixed(2)} MHz');
      } else {
        setState(() => _errorText = 'Frequency must be in range 300-348, 387-464, or 779-928 MHz');
      }
      return;
    }

    setState(() => _errorText = null);
    widget.onChanged?.call(frequency);
  }

  void _onPresetSelected(String? presetValue) {
    if (presetValue != null) {
      final floatValue = CC1101Values.getFrequencyFloat(presetValue);
      if (floatValue != null) {
        widget.controller.text = presetValue;
        widget.onChanged?.call(floatValue);
      }
    }
    setState(() => _selectedPreset = presetValue);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Поле ввода частоты
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: 'Frequency (MHz)',
            hintText: '300-348, 387-464, 779-928 MHz',
            errorText: _errorText,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.radio),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_drop_down),
              onPressed: widget.enabled ? () => _showFrequencyPicker() : null,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          onChanged: (value) => _validateFrequency(),
        ),
      ],
    );
  }

  void _showFrequencyPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Frequency'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: CC1101Values.frequencies.length,
            itemBuilder: (context, index) {
              final freq = CC1101Values.frequencies[index];
              final isSelected = _selectedPreset == freq;
              
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(
                  '$freq MHz',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                onTap: () {
                  _onPresetSelected(freq);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Поле ввода частоты с валидацией
class FrequencyInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final double? value;
  final ValueChanged<double?>? onChanged;
  final bool enabled;

  const FrequencyInputField({
    super.key,
    required this.controller,
    required this.label,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<FrequencyInputField> createState() => _FrequencyInputFieldState();
}

class _FrequencyInputFieldState extends State<FrequencyInputField> {
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) {
      widget.controller.text = widget.value!.toStringAsFixed(2);
    }
    widget.controller.addListener(_validateFrequency);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validateFrequency);
    super.dispose();
  }

  void _validateFrequency() {
    final text = widget.controller.text;
    if (text.isEmpty) {
      setState(() => _errorText = 'Frequency is required');
      return;
    }

    final frequency = double.tryParse(text);
    if (frequency == null) {
      setState(() => _errorText = 'Invalid frequency format');
      return;
    }

    if (!CC1101Values.isValidFrequency(frequency)) {
      final closest = CC1101Values.getClosestValidFrequency(frequency);
      if (closest != null) {
        setState(() => _errorText = 'Invalid frequency. Closest valid: ${closest.toStringAsFixed(2)} MHz');
      } else {
        setState(() => _errorText = 'Frequency must be in range 300-348, 387-464, or 779-928 MHz');
      }
      return;
    }

    setState(() => _errorText = null);
    widget.onChanged?.call(frequency);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '300-348, 387-464, 779-928 MHz',
        errorText: _errorText,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.radio),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onChanged: (value) => _validateFrequency(),
    );
  }
}

/// Поле ввода скорости передачи данных с валидацией
class DataRateInputField extends StatefulWidget {
  final TextEditingController controller;
  final double? value;
  final ValueChanged<double?>? onChanged;
  final bool enabled;

  const DataRateInputField({
    super.key,
    required this.controller,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<DataRateInputField> createState() => _DataRateInputFieldState();
}

class _DataRateInputFieldState extends State<DataRateInputField> {
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) {
      widget.controller.text = widget.value!.toStringAsFixed(2);
    }
    widget.controller.addListener(_validateDataRate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validateDataRate);
    super.dispose();
  }

  void _validateDataRate() {
    final text = widget.controller.text;
    if (text.isEmpty) {
      setState(() => _errorText = null);
      widget.onChanged?.call(null);
      return;
    }

    final dataRate = double.tryParse(text);
    if (dataRate == null) {
      setState(() => _errorText = 'Invalid data rate format');
      return;
    }

    if (!CC1101Values.isValidDataRate(dataRate)) {
      setState(() => _errorText = 'Data rate must be between ${CC1101Values.dataRateLimits['min']} and ${CC1101Values.dataRateLimits['max']} kBaud');
      return;
    }

    setState(() => _errorText = null);
    widget.onChanged?.call(dataRate);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: 'Data Rate (kBaud)',
        hintText: '${CC1101Values.dataRateLimits['min']}-${CC1101Values.dataRateLimits['max']}',
        errorText: _errorText,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.speed),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onChanged: (value) => _validateDataRate(),
    );
  }
}

/// Поле ввода девиации с валидацией
class DeviationInputField extends StatefulWidget {
  final TextEditingController controller;
  final double? value;
  final ValueChanged<double?>? onChanged;
  final bool enabled;

  const DeviationInputField({
    super.key,
    required this.controller,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<DeviationInputField> createState() => _DeviationInputFieldState();
}

class _DeviationInputFieldState extends State<DeviationInputField> {
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) {
      widget.controller.text = widget.value!.toStringAsFixed(2);
    }
    widget.controller.addListener(_validateDeviation);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validateDeviation);
    super.dispose();
  }

  void _validateDeviation() {
    final text = widget.controller.text;
    if (text.isEmpty) {
      setState(() => _errorText = null);
      widget.onChanged?.call(null);
      return;
    }

    final deviation = double.tryParse(text);
    if (deviation == null) {
      setState(() => _errorText = 'Invalid deviation format');
      return;
    }

    if (!CC1101Values.isValidDeviation(deviation)) {
      setState(() => _errorText = 'Deviation must be between ${CC1101Values.deviationLimits['min']} and ${CC1101Values.deviationLimits['max']} kHz');
      return;
    }

    setState(() => _errorText = null);
    widget.onChanged?.call(deviation);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: 'Deviation (kHz)',
        hintText: '${CC1101Values.deviationLimits['min']}-${CC1101Values.deviationLimits['max']}',
        errorText: _errorText,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.tune),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onChanged: (value) => _validateDeviation(),
    );
  }
}

/// Селектор пресетов
class PresetSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool enabled;

  const PresetSelector({
    super.key,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: enabled ? onChanged : null,
      decoration: const InputDecoration(
        labelText: 'Preset',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.settings),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isDense: true,
      items: CC1101Values.presets.map((preset) {
        return DropdownMenuItem<String>(
          value: preset['value'],
          child: Container(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
                preset['name'],
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              ),
          ),
        );
      }).toList(),
    );
  }
}

/// Селектор полосы пропускания
class BandwidthSelector extends StatelessWidget {
  final TextEditingController controller;
  final double? value;
  final ValueChanged<double?>? onChanged;
  final bool enabled;

  const BandwidthSelector({
    super.key,
    required this.controller,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Находим текущее значение в списке
    String? currentValue;
    if (value != null) {
      final bandwidth = CC1101Values.bandwidths.firstWhere(
        (bw) => double.parse(bw['float']!) == value!,
        orElse: () => {'value': value!.toStringAsFixed(2)},
      );
      currentValue = bandwidth['value'];
    }

    return DropdownButtonFormField<String>(
      value: currentValue,
      onChanged: enabled ? (newValue) {
        if (newValue != null) {
          final floatValue = CC1101Values.getBandwidthFloat(newValue);
          if (floatValue != null) {
            onChanged?.call(floatValue);
          }
        }
      } : null,
      decoration: const InputDecoration(
        labelText: 'Bandwidth (kHz)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.waves),
      ),
      items: CC1101Values.bandwidths.map((bandwidth) {
        return DropdownMenuItem<String>(
          value: bandwidth['value'],
          child: Text('${bandwidth['value']} kHz'),
        );
      }).toList(),
    );
  }
}

/// Селектор типа модуляции
class ModulationSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool enabled;

  const ModulationSelector({
    super.key,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: enabled ? onChanged : null,
      decoration: const InputDecoration(
        labelText: 'Modulation',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.radio),
      ),
      items: CC1101Values.getModulationNames().map((modulation) {
        return DropdownMenuItem<String>(
          value: modulation,
          child: Text(modulation),
        );
      }).toList(),
    );
  }
}

/// Виджет для отображения информации о пресете
class PresetInfoWidget extends StatelessWidget {
  final String presetValue;

  const PresetInfoWidget({
    super.key,
    required this.presetValue,
  });

  @override
  Widget build(BuildContext context) {
    final preset = CC1101Values.getPresetByValue(presetValue);
    
    if (preset == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preset: ${preset['name']}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Modulation: ${preset['modulation']}'),
            Text('Bandwidth: ${preset['bandwidth']}'),
            Text('Data Rate: ${preset['dataRate']}'),
            if (preset['deviation'] != null)
              Text('Deviation: ${preset['deviation']}'),
          ],
        ),
      ),
    );
  }
}

/// Виджет для отображения статуса валидации
class ValidationStatusWidget extends StatelessWidget {
  final List<String> errors;
  final List<String> warnings;

  const ValidationStatusWidget({
    super.key,
    this.errors = const [],
    this.warnings = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty && warnings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: errors.isNotEmpty 
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errors.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.error,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Errors',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...errors.map((error) => Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 4),
                child: Text(
                  '• $error',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              )),
            ],
            if (warnings.isNotEmpty) ...[
              if (errors.isNotEmpty) const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Warnings',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...warnings.map((warning) => Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 4),
                child: Text(
                  '• $warning',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
