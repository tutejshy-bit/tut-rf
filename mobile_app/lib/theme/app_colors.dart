import 'package:flutter/material.dart';

/// Централизованная система цветов для dark/hacker-style UI
class AppColors {
  // Приватный конструктор для предотвращения инстанцирования
  AppColors._();

  // ========== Фон ==========
  static const Color primaryBackground = Color(0xFF0B0F14); // Почти черный
  static const Color secondaryBackground = Color(0xFF121821); // Панели, карточки
  static const Color surfaceElevated = Color(0xFF1A1F2E); // Элементы поверх карточек

  // ========== Текст ==========
  static const Color primaryText = Color(0xFFE6EDF3); // Основной текст
  static const Color secondaryText = Color(0xFF9BA3AF); // Вторичный текст
  static const Color disabledText = Color(0xFF6B7280); // Неактивные элементы

  // ========== Акцент (холодный синий) ==========
  static const Color primaryAccent = Color(0xFF38BDF8); // Основной акцент
  static const Color accentHover = Color(0xFF4FC3F7); // При наведении
  static const Color accentPressed = Color(0xFF29B6F6); // При нажатии

  // ========== Статусы ==========
  static const Color success = Color(0xFF22C55E); // Готов, успех
  static const Color warning = Color(0xFFFACC15); // Предупреждение, в процессе
  static const Color error = Color(0xFFEF4444); // Ошибка, критично
  static const Color info = Color(0xFF38BDF8); // Информация

  // ========== Специфичные для RF модулей ==========
  static const Color recording = Color(0xFFEF4444); // Запись сигнала
  static const Color transmitting = Color(0xFF38BDF8); // Передача
  static const Color jamming = Color(0xFFFACC15); // Джамминг
  static const Color idle = Color(0xFF22C55E); // Готов
  static const Color searching = Color(0xFF38BDF8); // Поиск частоты

  // ========== Границы ==========
  static const Color borderDefault = Color(0xFF2A3441);
  static const Color borderFocus = Color(0xFF38BDF8);
  static const Color divider = Color(0xFF1E293B);

  // ========== Логи / Консоль ==========
  static const Color logBackground = Color(0xFF020617);
  static const Color logText = Color(0xFF22C55E); // Зеленый для логов
  static const Color logError = Color(0xFFEF4444);
  static const Color logSystem = Color(0xFF38BDF8);
  static const Color logUserInput = Color(0xFFE6EDF3);

  // ========== Цвета для Material ColorScheme ==========
  
  /// Получить ColorScheme для dark темы
  static ColorScheme get darkColorScheme {
    return const ColorScheme.dark(
      primary: primaryAccent,
      onPrimary: primaryBackground,
      secondary: primaryAccent,
      onSecondary: primaryBackground,
      error: error,
      onError: primaryText,
      surface: secondaryBackground,
      onSurface: primaryText,
      surfaceContainerHighest: surfaceElevated,
      outline: borderDefault,
      outlineVariant: divider,
    );
  }

  /// Получить цвет для статуса модуля
  static Color getModuleStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'idle':
        return idle;
      case 'recordsignal':
      case 'recording':
        return recording;
      case 'sendsignal':
      case 'transmitting':
        return transmitting;
      case 'jamming':
        return jamming;
      case 'detectsignal':
      case 'searching':
        return searching;
      default:
        return secondaryText;
    }
  }
}

