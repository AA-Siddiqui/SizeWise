import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/yolo_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final controller = UltralyticsYoloCameraController();
  final String filePath = "assets/ThePrestige.jpg";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: FutureBuilder<bool>(
          future: _checkPermissions(),
          builder: (context, snapshot) {
            final allPermissionsGranted = snapshot.data ?? false;
            final Image image = Image.asset(filePath);

            return !allPermissionsGranted
                ? const Center(
                    child: Text("Permission Granted"),
                  )
                : FutureBuilder<Rec>(
                    future: _getDetectionResult(),
                    builder: (context, snapshot) {
                      return snapshot.data == null
                          ? const Center(
                              child: Text("Loading"),
                            )
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  snapshot.data?.column ??
                                      const Center(
                                        child: Text(
                                          "Loaded but failed",
                                        ),
                                      ),
                                  Stack(
                                    children: [
                                      Center(
                                        child: image,
                                      ),
                                      ...snapshot.data?.detectedObject.map((e) {
                                            if (e == null) {
                                              return const Placeholder();
                                            }
                                            return Positioned.fill(
                                              child: CustomPaint(
                                                painter:
                                                    RectPainter(e.boundingBox),
                                                child: Container(),
                                              ),
                                            );
                                          }).toList() ??
                                          [],
                                    ],
                                  ),
                                ],
                              ),
                            );
                    },
                  );
          },
        ),
      ),
    );
  }

  Future<ObjectDetector> _initObjectDetectorWithLocalModel() async {
    // final modelPath = await _copy('assets/yolov8n.mlmodel');
    // final model = LocalYoloModel(
    //   id: '',
    //   task: Task.detect,
    //   format: Format.coreml,
    //   modelPath: modelPath,
    // );
    final modelPath = await _copy('assets/yolov8n_int8.tflite');
    final metadataPath = await _copy('assets/metadata.yaml');
    final model = LocalYoloModel(
      id: '',
      task: Task.detect,
      format: Format.tflite,
      modelPath: modelPath,
      metadataPath: metadataPath,
    );

    return ObjectDetector(model: model);
  }

  Future<Rec> _getDetectionResult() async {
    ObjectDetector predictor = await _initObjectDetectorWithLocalModel();
    String x = await predictor.loadModel(useGpu: true) ?? "Failed GPU?";
    List<DetectedObject?> objects =
        await predictor.detect(imagePath: await _copy(filePath)) ?? [];

    return Rec(
        detectedObject: objects,
        column: Column(
          children: [
            Text(x),
            if (objects.isNotEmpty)
              DataTable(
                columns: const [
                  DataColumn(label: Text("Label")),
                  DataColumn(label: Text("Confidence")),
                  DataColumn(label: Text("Rect")),
                ],
                rows: objects.map(
                  (object) {
                    return DataRow(
                      cells: [
                        DataCell(Text(object?.label ?? "What")),
                        DataCell(
                          Text(
                            object?.confidence.toStringAsFixed(2) ?? "What",
                          ),
                        ),
                        DataCell(
                          Text(
                            object?.boundingBox.toString().substring(13) ?? "0",
                          ),
                        ),
                      ],
                    );
                  },
                ).toList(),
              )
          ],
        ));
  }

  /*
  Future<ImageClassifier> _initImageClassifierWithLocalModel() async {
    final modelPath = await _copy('assets/yolov8n-cls.mlmodel');
    final model = LocalYoloModel(
      id: '',
      task: Task.classify,
      format: Format.coreml,
      modelPath: modelPath,
    );

    // final modelPath = await _copy('assets/yolov8n-cls.bin');
    // final paramPath = await _copy('assets/yolov8n-cls.param');
    // final metadataPath = await _copy('assets/metadata-cls.yaml');
    // final model = LocalYoloModel(
    //   id: '',
    //   task: Task.classify,
    //   modelPath: modelPath,
    //   paramPath: paramPath,
    //   metadataPath: metadataPath,
    // );

    return ImageClassifier(model: model);
  }
  */

  Future<String> _copy(String assetPath) async {
    final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';
    await io.Directory(dirname(path)).create(recursive: true);
    final file = io.File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
  }

  Future<bool> _checkPermissions() async {
    List<Permission> permissions = [];

    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) permissions.add(Permission.camera);

    // var storageStatus = await Permission.storage.status;
    // if (!storageStatus.isGranted) permissions.add(Permission.storage);

    if (permissions.isEmpty) {
      return true;
    } else {
      try {
        Map<Permission, PermissionStatus> statuses =
            await permissions.request();
        return statuses[Permission.camera] == PermissionStatus.granted;
        // return statuses[Permission.camera] == PermissionStatus.granted &&
        //     statuses[Permission.storage] == PermissionStatus.granted;
      } on Exception catch (_) {
        return false;
      }
    }
  }
}

class RectPainter extends CustomPainter {
  Rect rect;

  RectPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(RectPainter oldDelegate) => false;
}

class Rec {
  final List<DetectedObject?> detectedObject;
  final Widget column;

  const Rec({required this.detectedObject, required this.column});
}
