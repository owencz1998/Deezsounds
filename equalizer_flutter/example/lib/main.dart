import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:equalizer_flutter/equalizer_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool enableCustomEQ = false;

  @override
  void initState() {
    super.initState();
    EqualizerFlutter.init(0);
  }

  @override
  void dispose() {
    EqualizerFlutter.release();
    super.dispose();
  }

  final ButtonStyle flatButtonStyle = TextButton.styleFrom(
    foregroundColor: Colors.white,
    backgroundColor: Colors.blue,
    minimumSize: const Size(88, 36),
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(2.0)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Equalizer example'),
        ),
        body: ListView(
          children: [
            const SizedBox(height: 10.0),
            Center(
              child: Builder(
                builder: (context) {
                  return TextButton.icon(
                    style: flatButtonStyle,
                    icon: const Icon(Icons.equalizer),
                    label: const Text('Open device equalizer'),
                    onPressed: () async {
                      try {
                        await EqualizerFlutter.open(0);
                      } on PlatformException catch (e) {
                        final snackBar = SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('${e.message}\n${e.details}'),
                        );
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(snackBar);
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10.0),
            Container(
              color: Colors.grey.withOpacity(0.1),
              child: SwitchListTile(
                title: const Text('Custom Equalizer'),
                value: enableCustomEQ,
                onChanged: (value) {
                  EqualizerFlutter.setEnabled(value);
                  setState(() {
                    enableCustomEQ = value;
                  });
                },
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            FutureBuilder<List<int>>(
              future: EqualizerFlutter.getBandLevelRange(),
              builder: (context, snapshot) {
                return snapshot.connectionState == ConnectionState.done
                    ? CustomEQ(enableCustomEQ, snapshot.data!)
                    : const CircularProgressIndicator();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class CustomEQ extends StatefulWidget {
  const CustomEQ(this.enabled, this.bandLevelRange, {super.key});

  final bool enabled;
  final List<int> bandLevelRange;

  @override
  _CustomEQState createState() => _CustomEQState();
}

class _CustomEQState extends State<CustomEQ> {
  late double min, max;
  String? _selectedValue;
  late Future<List<String>> fetchPresets;

  @override
  void initState() {
    super.initState();
    min = widget.bandLevelRange[0].toDouble();
    max = widget.bandLevelRange[1].toDouble();
    fetchPresets = EqualizerFlutter.getPresetNames();
  }

  @override
  Widget build(BuildContext context) {
    int bandId = 0;

    return FutureBuilder<List<int>>(
      future: EqualizerFlutter.getCenterBandFreqs(),
      builder: (context, snapshot) {
        return snapshot.connectionState == ConnectionState.done
            ? Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: snapshot.data!.map((freq) => _buildSliderBand(freq, bandId)).toList(),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: _buildPresets(),
                  ),
                ],
              )
            : const CircularProgressIndicator();
      },
    );
  }

  Widget _buildSliderBand(int freq, int bandId) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 250,
            child: FutureBuilder<int>(
              future: EqualizerFlutter.getBandLevel(bandId),
              builder: (context, snapshot) {
                var data = snapshot.data?.toDouble() ?? 0.0;
                return RotatedBox(
                  quarterTurns: 1,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 1, trackShape: SliderCustomTrackShape()),
                    child: Center(
                      child: Slider(
                        min: min,
                        max: max,
                        value: data,
                        onChanged: (lowerValue) {
                          EqualizerFlutter.setBandLevel(bandId, lowerValue.toInt());
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Text('${freq ~/ 1000} Hz'),
        ],
      ),
    );
  }

  Widget _buildPresets() {
    return FutureBuilder<List<String>>(
      future: fetchPresets,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final presets = snapshot.data;
          if (presets!.isEmpty) return const Text('No presets available!');
          return DropdownButtonFormField(
            decoration: const InputDecoration(
              labelText: 'Available Presets',
              border: OutlineInputBorder(),
            ),
            value: _selectedValue,
            onChanged: widget.enabled
                ? (String? value) {
                    EqualizerFlutter.setPreset(value!);
                    setState(() {
                      _selectedValue = value;
                    });
                  }
                : null,
            items: presets.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          );
        } else if (snapshot.hasError) {
          return Text(snapshot.error.toString());
        } else {
          return const CircularProgressIndicator();
        }
      },
    );
  }
}

class SliderCustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double? trackHeight = sliderTheme.trackHeight;
    final double trackLeft = offset.dx;
    final double trackTop = (parentBox.size.height) / 2;
    const double trackWidth = 230;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight!);
  }
}
