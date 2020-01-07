import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';
import 'package:flutter_reticle/flutter_reticle.dart';

class CameraView extends StatefulWidget {
  CameraView({Key key, this.stateCallback}) : super(key: key);

  final Function(bool) stateCallback;

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CameraController _controller;
  Future<void> _initCameraFuture;
  bool _isDetecting = false;
  bool _objDetected;
  int _lastTime = 0;

  Future<void> initCamera() async {
    List<CameraDescription> cameras = await availableCameras();
    _controller = CameraController(cameras.first, ResolutionPreset.veryHigh);
    await _controller.initialize();
    await Tflite.loadModel(
        model: "assets/android_plushie.tflite",
        labels: "assets/labels.txt",
        numThreads: 1
    );

    _controller.startImageStream(processImage);
  }

  void processImage(CameraImage img) async {
    if (!_isDetecting) {
      // Rate-limit recognition to every 50 ms to reduce lag and battery drain
      int now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastTime < 50) {
        return;
      }

      _isDetecting = true;

      List<dynamic> recognitions = await Tflite.runModelOnFrame(
        bytesList: img.planes.map((plane) {
          return plane.bytes;
        }).toList(),
        imageHeight: img.height,
        imageWidth: img.width,
        numResults: 1,
      );

      var objDetected = recognitions[0]["label"] == "android";
      if (objDetected != _objDetected) {
        _objDetected = objDetected;
        widget.stateCallback(_objDetected);
      }

      // Query time again since detection itself takes longer than 50 ms
      _lastTime = DateTime.now().millisecondsSinceEpoch;
      _isDetecting = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _initCameraFuture = initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;

    return FutureBuilder<void>(
      future: _initCameraFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Transform.scale(
            scale: _controller.value.aspectRatio / deviceRatio,
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: CameraPreview(_controller),
            ),
          );
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}

class CameraPage extends StatefulWidget {
  CameraPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  bool _currentState = false;
  String _currentMessage = "Initializing detection...";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CameraView(stateCallback: (bool objDetected) {
                  setState(() {
                    _currentState = objDetected;

                    if (objDetected) {
                      _currentMessage = "Android plushie detected";
                    } else {
                      _currentMessage = "Unrecognized object";
                    }
                  });
                }),
              ],
            ),
          ),
          if (!_currentState) Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Reticle(ReticleState.SENSING),
              )
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.all(const Radius.circular(12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_currentMessage),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
