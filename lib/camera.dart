import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';

class CameraPage extends StatefulWidget {
  CameraPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController _controller;
  Future<void> _initCameraFuture;
  bool _isDetecting = false;
  String _currentMessage = "";

  Future<void> initCamera() async {
    List<CameraDescription> cameras = await availableCameras();
    _controller = CameraController(cameras.first, ResolutionPreset.veryHigh);
    await _controller.initialize();
    await Tflite.loadModel(
        model: "assets/android_plushie.tflite",
        labels: "assets/labels.txt",
        numThreads: 1
    );
    await Future.delayed(const Duration(seconds: 1), () {});

    _controller.startImageStream((CameraImage img) {
      if (!_isDetecting) {
        _isDetecting = true;

        Tflite.runModelOnFrame(
          bytesList: img.planes.map((plane) {
            return plane.bytes;
          }).toList(),
          imageHeight: img.height,
          imageWidth: img.width,
          numResults: 1,
        ).then((recognitions) {
          setState(() {
            if (recognitions[0]["label"] == "android") {
              _currentMessage = "Android plushie detected";
            } else {
              _currentMessage = "Unrecognized object";
            }
          });

          _isDetecting = false;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initCameraFuture = initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
    Tflite.close();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // TODO: split camera view into a stateful widget
                FutureBuilder<void>(
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
                ),
              ],
            ),
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
