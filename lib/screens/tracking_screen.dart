import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  String _locationText = '위치 정보 없음';
  String _elapsedTime = '00:00:00';
  StreamSubscription<Position>? _positionSubscription;
  Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  bool _isRunning = false;

  double _totalDistance = 0.0;
  Position? _previousPosition;
  int _age = 25; // 기본값, Firestore에서 가져온 사용자 정보로 갱신됨

  @override
  void initState() {
    super.initState();
    _fetchUserAge();
  }

  Future<void> _fetchUserAge() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && doc.data()?['age'] != null) {
      setState(() {
        _age = int.tryParse(doc['age'].toString()) ?? 25;
      });
    }
  }

  Future<void> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationText = '위치 서비스가 꺼져 있습니다.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _locationText = '위치 권한이 거부되었습니다.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationText = '위치 권한이 영구적으로 거부되었습니다.');
      return;
    }
  }

  void _startRun() async {
    await _checkPermission();

    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = _stopwatch.elapsed;
      setState(() {
        _elapsedTime = '${elapsed.inHours.toString().padLeft(2, '0')}:'
            '${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}:'
            '${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
      });
    });

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (_previousPosition != null) {
        _totalDistance += Geolocator.distanceBetween(
          _previousPosition!.latitude,
          _previousPosition!.longitude,
          position.latitude,
          position.longitude,
        );
      }
      _previousPosition = position;

      setState(() {
        _locationText =
            '위도: ${position.latitude}\n경도: ${position.longitude}\n속도: ${position.speed.toStringAsFixed(2)} m/s';
      });
    });

    setState(() {
      _isRunning = true;
    });
  }

  void _stopRun() async {
    _stopwatch.stop();
    final now = DateTime.now();

    final elapsedSeconds = _stopwatch.elapsed.inSeconds;
    final distanceKm = _totalDistance / 1000;
    final avgSpeed = _calculateAvgSpeedKmh();
    final calories = _calculateCalories();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('records').add({
        'userId': uid,
        'timestamp': now,
        'duration': elapsedSeconds,
        'distance': distanceKm,
        'averageSpeed': avgSpeed,
        'calories': calories,
      });
    }

    _timer?.cancel();
    _positionSubscription?.cancel();
    setState(() {
      _isRunning = false;
      _elapsedTime = '00:00:00';
      _locationText = '위치 정보 없음';
      _totalDistance = 0.0;
      _previousPosition = null;
    });
  }

  double _calculateAvgSpeedKmh() {
    final hours = _stopwatch.elapsed.inSeconds / 3600;
    if (hours == 0) return 0;
    return (_totalDistance / 1000) / hours;
  }

  double _calculateCalories() {
    double mets = 7.0;
    double weight = 70;
    double timeInHours = _stopwatch.elapsed.inSeconds / 3600;

    double ageFactor = (_age <= 25)
        ? 1.0
        : (_age <= 35)
            ? 0.98
            : (_age <= 45)
                ? 0.95
                : (_age <= 55)
                    ? 0.93
                    : 0.90;

    return mets * weight * timeInHours * ageFactor;
  }

  @override
  Widget build(BuildContext context) {
    final km = (_totalDistance / 1000).toStringAsFixed(2);
    final avgSpeed = _calculateAvgSpeedKmh().toStringAsFixed(2);
    final calories = _calculateCalories().toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(title: const Text('러닝 트래킹')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_locationText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            const Text('러닝 시간', style: TextStyle(fontSize: 20)),
            Text(_elapsedTime, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('이동 거리: $km km', style: const TextStyle(fontSize: 18)),
            Text('평균 속도: $avgSpeed km/h', style: const TextStyle(fontSize: 18)),
            Text('소모 칼로리: $calories kcal', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 30),
            _isRunning
                ? ElevatedButton.icon(
                    onPressed: _stopRun,
                    icon: const Icon(Icons.stop),
                    label: const Text('정지'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  )
                : ElevatedButton.icon(
                    onPressed: _startRun,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('시작'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
          ],
        ),
      ),
    );
  }
}
