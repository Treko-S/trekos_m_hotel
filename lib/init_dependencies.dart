import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:trekos_m_hotel/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:trekos_m_hotel/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:trekos_m_hotel/features/auth/domain/repository/auth_repository.dart';
import 'package:trekos_m_hotel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:trekos_m_hotel/features/hotel_search/data/datasources/hotel_remote_data_source.dart';
import 'package:trekos_m_hotel/features/hotel_search/data/repositories/hotel_repository_impl.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/repository/hotel_repository.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_bloc.dart';

final serviceLocator = GetIt.instance;

Future<void> initDependencies() async {
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // Continúa con variables por defecto si .env no está presente
  }
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']?.trim().isNotEmpty == true
        ? dotenv.env['SUPABASE_URL']!.trim()
        : 'https://nfbiqdhiowroosvfazid.supabase.co',
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']?.trim().isNotEmpty == true
        ? dotenv.env['SUPABASE_ANON_KEY']!.trim()
        : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mYmlxZGhpb3dyb29zdmZhemlkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgwODExMTAsImV4cCI6MjEwMzY1NzExMH0.cq1gk6qvvbtY3j_kZVAGR4vSLXRhprxYalzWPAp7HzI',
  );

  _initCore();
  _initAuth();
  _initHotelSearch();
}

void _initCore() {
  serviceLocator.registerLazySingleton(() => Supabase.instance.client);
  
  serviceLocator.registerLazySingleton(() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  ));

  serviceLocator.registerLazySingleton(() => const FlutterSecureStorage());
}

void _initAuth() {
  serviceLocator.registerFactory<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(serviceLocator()),
  );

  serviceLocator.registerFactory<AuthRepository>(
    () => AuthRepositoryImpl(serviceLocator()),
  );

  serviceLocator.registerLazySingleton(
    () => AuthBloc(authRepository: serviceLocator()),
  );
}

void _initHotelSearch() {
  serviceLocator.registerFactory<HotelRemoteDataSource>(
    () => HotelRemoteDataSourceImpl(serviceLocator()),
  );

  serviceLocator.registerFactory<HotelRepository>(
    () => HotelRepositoryImpl(serviceLocator()),
  );

  serviceLocator.registerLazySingleton(
    () => HotelBloc(hotelRepository: serviceLocator()),
  );
}
