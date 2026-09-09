import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trekos_m_hotel/core/theme/app_theme.dart';
import 'package:trekos_m_hotel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_bloc.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_event.dart';
import 'package:trekos_m_hotel/core/services/hotel_settings_service.dart';
import 'package:trekos_m_hotel/core/services/notification_service.dart';
import 'package:trekos_m_hotel/core/widgets/biometric_session_guard.dart';
import 'package:trekos_m_hotel/features/splash/presentation/pages/splash_page.dart';
import 'package:trekos_m_hotel/init_dependencies.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_PY', null);
  await initializeDateFormatting('es', null);
  await initDependencies();
  await NotificationService().init();
  await HotelSettingsService.init();
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => serviceLocator<AuthBloc>()..add(AuthIsUserLoggedIn())),
        BlocProvider(create: (_) => serviceLocator<HotelBloc>()..add(HotelFetchRooms())),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hotel 3Vagos',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) => BiometricSessionGuard(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SplashScreen(),
    );
  }
}
