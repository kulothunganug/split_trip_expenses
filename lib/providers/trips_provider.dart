import 'dart:async';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../database/drift_database.dart';

class TripsProvider extends ChangeNotifier {
  final AppDatabase db;
  List<Trip> _trips = [];
  StreamSubscription? _sub;

  TripsProvider(this.db) {
    _sub = db.watchAllTrips().listen((trips) {
      _trips = trips;
      notifyListeners();
    });
  }

  List<Trip> get trips => _trips;

  Future<int> addTrip(String title, double? budget) async {
    return await db.insertTrip(
      TripsCompanion.insert(title: title, budget: drift.Value(budget)),
    );
  }

  Future<void> updateTrip(Trip trip) async {
    await db.updateTrip(trip);
  }

  Future<void> deleteTrip(Trip trip) async {
    await db.deleteTrip(trip);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
