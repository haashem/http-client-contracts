import 'package:flutter/material.dart';

import '../../../app/composition/transport_mode.dart';
import '../../../app/demo_runtime.dart';

class RuntimeSettingsScreen extends StatelessWidget {
  const RuntimeSettingsScreen({super.key, required this.runtime});

  final DemoRuntime runtime;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: runtime,
      builder: (BuildContext context, Widget? child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text('Settings', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Runtime controls for transport selection and demo network modes.',
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                const Text('Transport:'),
                const SizedBox(width: 12),
                DropdownButton<TransportMode>(
                  value: runtime.transportMode,
                  items: TransportMode.values.map((TransportMode mode) {
                    return DropdownMenuItem<TransportMode>(
                      value: mode,
                      child: Text(mode.label),
                    );
                  }).toList(),
                  onChanged: runtime.switchingTransport
                      ? null
                      : (TransportMode? mode) {
                          if (mode == null) {
                            return;
                          }
                          runtime.switchTransport(mode);
                        },
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Airplane mode'),
              subtitle: const Text('All requests fail with network exception.'),
              value: runtime.offlineMode,
              onChanged: runtime.setOfflineMode,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Flaky feed mode'),
              subtitle: const Text(
                'First 2 feed attempts fail, then retry recovers.',
              ),
              value: runtime.flakyFeedMode,
              onChanged: runtime.setFlakyFeedMode,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Slow feed mode'),
              subtitle: const Text(
                'Feed endpoint delays response to trigger timeout.',
              ),
              value: runtime.slowFeedMode,
              onChanged: runtime.setSlowFeedMode,
            ),
          ],
        );
      },
    );
  }
}
