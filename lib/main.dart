import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/alarm_scheduler.dart';
import 'services/theme_service.dart';
import 'services/ai_chat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 한국어 로케일 날짜/시간 포맷 초기화
  await initializeDateFormatting('ko', null);

  // 푸시 알림 및 알람 스케줄러, 테마 서비스, AI 채팅 서비스 초기화
  await NotificationService.instance.init();
  await AlarmScheduler.instance.init();
  await ThemeService.instance.init();
  await AiChatService.instance.init();

  runApp(const TenAlarmApp());
}

typedef DearAlarmApp = TenAlarmApp;

class TenAlarmApp extends StatelessWidget {
  const TenAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: ThemeService.instance.themeColorNotifier,
      builder: (context, primaryColor, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.instance.themeModeNotifier,
          builder: (context, themeMode, _) {
            return MaterialApp(
              title: '10Alarm',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: primaryColor,
                  brightness: Brightness.light,
                ),
                scaffoldBackgroundColor: const Color(0xFFF9F9FB),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: primaryColor,
                  brightness: Brightness.dark,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                ),
              ),
              themeMode: themeMode,
              home: const HomeScreen(),
            );
          },
        );
      },
    );
  }
}
