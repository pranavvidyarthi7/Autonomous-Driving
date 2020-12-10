import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as imageLib;
import 'package:flutter/material.dart';
import 'package:points_socket/convert.dart';

void main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  // Get a specific camera from the list of available cameras.
  final CameraDescription firstCamera = cameras.first;
  runApp(MaterialApp(
    home: Home(
      camera: firstCamera,
    ),
  ));
}

class Home extends StatefulWidget {
  final CameraDescription camera;
  Home({this.camera});
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  CameraController _controller;
  Future<void> _initializeCameraController;
  final List<Offset> points = [];
  Socket channel;
  Stream stream;
  connect() async {
    channel = await Socket.connect('192.168.1.6', 5000);
    stream = channel.asBroadcastStream();
  }

  @override
  void initState() {
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _initializeCameraController = _controller.initialize();
    connect();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    int i = 0;
    return Scaffold(
      body: FutureBuilder(
        future: _initializeCameraController,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            _controller.startImageStream((image) async {
              if (i < 1) {
                imageLib.Image img = ImageUtils.convertYUV420ToImage(image);
                print(img.getBytes());
                print(img.getBytes().length);
                channel.write(img.getBytes());
              } else if (i == 1) {
                print("DONE");
              }
              i++;
            });
            return Stack(
              children: [
                CameraPreview(_controller),
                StreamBuilder(
                    stream: stream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.active) {
                        points.clear();
                        dynamic obj = json.decode(
                          utf8.decode(snapshot.data),
                        );
                        List rows = obj['rows'];
                        List cols = obj['cols'];
                        for (int i = 0; i < rows.length; i++) {
                          points.add(
                              Offset(rows[i].toDouble(), cols[i].toDouble()));
                        }
                        channel.write('OK');
                        return CustomPaint(
                          painter: MyCustomPainter(points),
                          size: MediaQuery.of(context).size,
                        );
                      }
                      return Container(
                        color: Colors.blue,
                      );
                    }),
              ],
            );
          } else {
            // Otherwise, display a loading indicator.
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class MyCustomPainter extends CustomPainter {
  final List<Offset> points;
  MyCustomPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2;
    for (var i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i], points[i + 1], paint);
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawPoints(PointMode.points, [points[i]], paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
