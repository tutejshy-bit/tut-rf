import 'package:flutter/material.dart';
import 'lib/widgets/module_status_widget.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Module Status Widget Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Тестовые данные
    final testModules = [
      {
        'id': 0,
        'settings': '00 0D 01 2E 02 0D 03 07 04 D3 05 91 06 00 07 04 08 32 09 00 0A 00 0B 06 0C 23 0D 10 0E B0 0F 71 10 07 11 93 12 32 13 02 14 F8 15 47 16 07 17 30 18 18 19 16 1A 1C 1B C7 1C 00 1D B2 1E 87 1F 6B 20 F8 21 56 22 11 23 E9 24 2A 25 00 26 1F 27 41 28 00 29 59 2A 7F 2B 3F 2C 81 2D 35 2E 78',
        'mode': 'Idle'
      },
      {
        'id': 1,
        'settings': '00 0D 01 2E 02 0D 03 07 04 D3 05 91 06 00 07 04 08 32 09 00 0A 00 0B 06 0C 23 0D 10 0E B0 0F 71 10 07 11 93 12 32 13 02 14 F8 15 47 16 07 17 30 18 18 19 16 1A 1C 1B C7 1C 00 1D B2 1E 87 1F 6B 20 F8 21 56 22 11 23 E9 24 2A 25 00 26 1F 27 41 28 00 29 59 2A 7F 2B 3F 2C 81 2D 35 2E 78',
        'mode': 'RecordSignal'
      },
    ];

    final testDeviceInfo = {'freeHeap': 21580};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Module Status Widget Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Заголовок
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CC1101 Module Status Widget Test',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This widget displays real-time information about CC1101 modules including frequency, modulation, data rate, bandwidth, and current mode.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Тестовый виджет
            ModuleStatusWidget(
              cc1101Modules: testModules,
              deviceInfo: testDeviceInfo,
            ),
            
            const SizedBox(height: 16),
            
            // Информация о тестовых данных
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Data',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Device Free Heap: ${testDeviceInfo['freeHeap']} bytes'),
                    Text('Number of Modules: ${testModules.length}'),
                    const SizedBox(height: 8),
                    ...testModules.map((module) => 
                      Text('Module ${module['id']}: ${module['mode']}')
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




















