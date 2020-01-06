import 'package:flutter/material.dart';

import 'camera.dart';

void main() => runApp(PlushedApp());

class PlushedApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plushed',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        backgroundColor: Colors.black,
      ),
      home: CameraPage(title: 'Plushed'),
    );
  }
}
