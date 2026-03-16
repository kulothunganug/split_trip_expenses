import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database/drift_database.dart';
import 'providers/app_provider.dart';
import 'providers/categories_provider.dart';
import 'providers/trips_provider.dart';
import 'providers/trip_provider.dart';
import 'services/import_export_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => CategoriesProvider(db)),
        ChangeNotifierProvider(create: (_) => TripsProvider(db)),
        ChangeNotifierProvider(create: (_) => TripProvider(db)),
        Provider<ImportExportService>(create: (_) => ImportExportService(db)),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    return MaterialApp(
      title: 'Trip Expense Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      themeMode: appProvider.themeMode,
      home: const HomeScreen(),
    );
  }
}
