import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../services/import_export_service.dart';
import '../providers/trips_provider.dart';
import '../widgets/create_trip_dialog.dart';
import 'trip_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tripsProvider = context.watch<TripsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              } else if (value == 'import') {
                try {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['json'],
                  );
                  if (result != null && result.files.single.path != null) {
                    final str = await File(
                      result.files.single.path!,
                    ).readAsString();
                    if (context.mounted) {
                      await context
                          .read<ImportExportService>()
                          .importTripFromJson(str);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Trip Imported Successfully!'),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error importing trip: $e')),
                    );
                  }
                }
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'import',
                  child: Text('Import Trip'),
                ),
                const PopupMenuItem(value: 'settings', child: Text('Settings')),
              ];
            },
          ),
        ],
      ),
      body: tripsProvider.trips.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tripsProvider.trips.length,
              itemBuilder: (context, index) {
                final trip = tripsProvider.trips[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TripDetailScreen(tripId: trip.id),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withAlpha(50),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.flight_takeoff,
                              color: theme.colorScheme.onPrimaryContainer,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trip.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat(
                                        'MMM d, yyyy',
                                      ).format(trip.createdAt),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const CreateTripDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flight_outlined,
            size: 80,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 24),
          Text(
            'No trips yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first trip to start tracking expenses!',
            style: TextStyle(color: Theme.of(context).disabledColor),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const CreateTripDialog(),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Trip'),
          ),
        ],
      ),
    );
  }
}
