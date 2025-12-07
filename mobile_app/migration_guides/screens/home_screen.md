# Home Screen - Перенос из VueJS

## Описание
Главный экран приложения, который отображает состояние устройства и отладочную информацию.

## VueJS версия (Home.vue)
```vue
<template>
    <PageLayout>
        <template #actions-top>
            <Button @click="device.requestState">Update state</Button>
        </template>
        <template #content>
            <Card>
                <template #title>Debug info</template>
                <template #content>
                    <p class="m-0">
                        <pre class="overflow-x-auto">
{{ store.state }}
                        </pre>
                    </p>
                </template>
            </Card>
        </template>
    </PageLayout>
</template>
```

## Текущая Android версия
- Отображает статус подключения
- Показывает информацию о модулях CC1101
- Отображает свободную память ESP32
- Быстрое подключение к устройству

## Что нужно перенести

### 1. Кнопка "Update state"
- Добавить кнопку для принудительного обновления состояния устройства
- Вызывать `bleProvider.sendCommand('getState')`

### 2. Отладочная информация
- Отображать полное состояние устройства в виде JSON
- Добавить возможность копирования состояния
- Показывать детальную информацию о модулях CC1101

### 3. Улучшения UX
- Добавить анимации при обновлении состояния
- Показать время последнего обновления
- Добавить индикатор загрузки

## Реализация

### Новый виджет для отладочной информации
```dart
class DebugInfoWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        return Card(
          child: Column(
            children: [
              ListTile(
                title: Text('Debug Info'),
                trailing: IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: () => bleProvider.sendCommand('getState'),
                ),
              ),
              if (bleProvider.deviceStatus != null)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      JsonEncoder.withIndent('  ').convert(bleProvider.deviceStatus!),
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
```

### Обновление HomeScreen
```dart
class HomeTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<BleProvider>(
      builder: (context, bleProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const QuickConnectWidget(),
              const SizedBox(height: 16),
              if (bleProvider.isConnected) ...[
                const DeviceStatusWidget(),
                const SizedBox(height: 16),
                const DebugInfoWidget(), // Новый виджет
              ],
            ],
          ),
        );
      },
    );
  }
}
```

## Задачи для реализации
- [ ] Создать DebugInfoWidget
- [ ] Добавить кнопку обновления состояния
- [ ] Реализовать отображение JSON состояния
- [ ] Добавить возможность копирования состояния
- [ ] Добавить анимации и индикаторы загрузки
- [ ] Протестировать функциональность

