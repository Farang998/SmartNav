import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Dead Reckoning',
      home: DRPage(),
    );
  }
}

class DRPage extends StatefulWidget {
  const DRPage({super.key});

  @override
  State<DRPage> createState() => _DRPageState();
}
class _DRPageState extends State<DRPage> {
  Timer? _timer;
  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;

  static const double _dt = 0.05; 
  static const double _smoothing = 0.1; 

  double _rawAx = 0.0, _rawAy = 0.0, _rawGz = 0.0;

  double _ax = 0.0, _ay = 0.0, _gz = 0.0;

  double _yaw = 0.0; 
  double _vx = 0.0, _vy = 0.0; 
  double _px = 0.0, _py = 0.0; 

  double _worldAx = 0.0, _worldAy = 0.0; 

  final List<Offset> _path = [Offset.zero];

  @override
  void initState() {
    super.initState();

    _accelSub = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      _rawAx = event.x;
      _rawAy = event.y;
    });

    _gyroSub = gyroscopeEvents.listen((GyroscopeEvent event) {
      _rawGz = event.z;
    });

    _timer = Timer.periodic(Duration(milliseconds: (_dt * 1000).toInt()), _onTick);
  }

  void _onTick(Timer timer) {
    _ax = _ax + _smoothing * (_rawAx - _ax);
    _ay = _ay + _smoothing * (_rawAy - _ay);
    _gz = _gz + _smoothing * (_rawGz - _gz);

    const double accelThreshold = 0.1;
    const double gyroThreshold = 0.1;

    bool isStill = (_ax.abs() < accelThreshold &&
        _ay.abs() < accelThreshold && _gz.abs() < gyroThreshold);

    if (isStill) {
      _vx = 0.0;
      _vy = 0.0;
      _gz = 0.0;
      _worldAx = 0.0; 
      _worldAy = 0.0; 
    }

    _yaw += _gz * _dt;

    if (!isStill) {
      _worldAx = _ax * cos(_yaw) - _ay * sin(_yaw);
      _worldAy = _ax * sin(_yaw) + _ay * cos(_yaw);
    }
    
    _vx += _worldAx * _dt;
    _vy += _worldAy * _dt;

    _px += _vx * _dt;
    _py += _vy * _dt;

    setState(() {
      _path.add(Offset(_px, -_py));
    });
  }

  void _resetState() {
    setState(() {
      _rawAx = 0.0; _rawAy = 0.0; _rawGz = 0.0;
      _ax = 0.0; _ay = 0.0; _gz = 0.0;
      _yaw = 0.0;
      _vx = 0.0; _vy = 0.0;
      _px = 0.0; _py = 0.0;
      _worldAx = 0.0; _worldAy = 0.0; 
      _path.clear();
      _path.add(Offset.zero);
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dead Reckoning Path')),
      floatingActionButton: FloatingActionButton(
        onPressed: _resetState,
        child: const Icon(Icons.refresh),
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: CustomPaint(
              painter: PathPainter(path: _path),
            ),
          ),

          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LIVE DEBUG DATA',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Smoothed Accel: X: ${_ax.toStringAsFixed(2)}, Y: ${_ay.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    'World Accel: X: ${_worldAx.toStringAsFixed(2)}, Y: ${_worldAy.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.lightGreen),
                  ),
                  Text(
                    'Smoothed Gyro Z: ${_gz.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Divider(color: Colors.white54),
                  Text(
                    'Velocity: X: ${_vx.toStringAsFixed(2)}, Y: ${_vy.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Divider(color: Colors.white54),
                  Text(
                    'Position: X: ${_px.toStringAsFixed(2)} m, Y: ${_py.toStringAsFixed(2)} m',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    'Yaw: ${(_yaw * 180 / pi).toStringAsFixed(1)}°',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PathPainter extends CustomPainter {
  final List<Offset> path;
  final Paint pathPaint;
  final Paint currentPosPaint;

  PathPainter({required this.path})
      : pathPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
        currentPosPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    
    canvas.translate(size.width / 2, size.height / 2);

    final Path p = Path();
    if (path.isEmpty) return;

   
    double maxExtent = 1.0; 
    for (final point in path) {
      if (point.dx.abs() > maxExtent) maxExtent = point.dx.abs();
      if (point.dy.abs() > maxExtent) maxExtent = point.dy.abs();
    }

    final double scale = (min(size.width, size.height) / 2) / maxExtent;

    p.moveTo(path.first.dx * scale, path.first.dy * scale);

    for (final point in path.skip(1)) {
      p.lineTo(point.dx * scale, point.dy * scale);
    }

    canvas.drawPath(p, pathPaint);

    
    final Offset lastPoint = Offset(path.last.dx * scale, path.last.dy * scale);
    canvas.drawCircle(lastPoint, 5.0, currentPosPaint);
  }

  @override
  bool shouldRepaint(covariant PathPainter oldDelegate) {
    return true;
  }
}