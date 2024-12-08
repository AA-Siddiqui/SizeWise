import 'dart:io' as io;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

const List<Color> colorList = [...Colors.primaries];
const List<String> colorNameList = [
  "Red",
  "Pink",
  "Purple",
  "DeepPurple",
  "Indigo",
  "Blue",
  "LightBlue",
  "Cyan",
  "Teal",
  "Green",
  "LightGreen",
  "Lime",
  "Yellow",
  "Amber",
  "Orange",
  "DeepOrange",
  "Brown",
  "BlueGrey",
];

class _MyAppState extends State<MyApp> {
  final controller = UltralyticsYoloCameraController();
  // final String filePath = "assets/dog.webp";
  String? filePath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              onPressed: () async {
                // TODO: Catch the error on PlatformException
                try {
                  final image =
                      await ImagePicker().pickImage(source: ImageSource.camera);
                  if (image == null) return;
                  // final imageTemp = File(image.path);
                  setState(() => filePath = image.path);
                } finally {}
              },
              child: const Icon(Icons.camera),
            ),
            const SizedBox(
              height: 10,
            ),
            FloatingActionButton(
              onPressed: () async {
                // TODO: Catch the error on PlatformException
                try {
                  final image = await ImagePicker()
                      .pickImage(source: ImageSource.gallery);
                  if (image == null) return;
                  // final imageTemp = File(image.path);
                  setState(() => filePath = image.path);
                } catch (e) {
                  print(e);
                } finally {}
              },
              child: const Icon(Icons.add_a_photo),
            ),
          ],
        ),
        body: FutureBuilder<bool>(
          future: _checkPermissions(),
          builder: (context, snapshot) {
            final allPermissionsGranted = snapshot.data ?? false;
            // final Image image = Image.asset(filePath);
            final Image image;
            if (filePath != null) {
              image = Image.file(io.File(filePath!));
            } else {
              image = Image.asset("assets/dog.webp");
            }

            return !allPermissionsGranted
                ? const Center(
                    child: Text("Permission Not Granted"),
                  )
                : filePath == null
                    ? const Center(
                        child: Text("Image Not Selected"),
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
                                    verticalDirection: VerticalDirection.up,
                                    children: [
                                      Stack(
                                        children: [
                                          Center(
                                            child: image,
                                          ),
                                          ...snapshot.data?.detectedObject
                                                  .where((obj) => obj != null)
                                                  .map((e) {
                                                return Positioned.fill(
                                                  child: CustomPaint(
                                                    painter: RectPainter(
                                                        e!.boundingBox,
                                                        colorList[snapshot.data
                                                                ?.detectedObject
                                                                .indexOf(e) ??
                                                            0]),
                                                    child: Container(),
                                                  ),
                                                );
                                              }).toList() ??
                                              [],
                                        ],
                                      ),
                                      SingleChildScrollView(
                                        child: snapshot.data?.column ??
                                            const Center(
                                              child: Text(
                                                "Loaded but failed",
                                              ),
                                            ),
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
    // final modelPath = await _copy('assets/yolo11x-cls_int8.tflite');
    // final metadataPath = await _copy('assets/metadata-11-cls.yaml');
    // final model = LocalYoloModel(
    //   id: '',
    //   task: Task.detect,
    //   format: Format.tflite,
    //   modelPath: modelPath,
    //   metadataPath: metadataPath,
    // );

    final modelPath = await _copy('assets/yolov8n_int81.tflite');
    final metadataPath = await _copy('assets/metadatad.yaml');
    final model = LocalYoloModel(
      id: '',
      task: Task.detect,
      format: Format.tflite,
      modelPath: modelPath,
      metadataPath: metadataPath,
    );

    return ObjectDetector(model: model);
  }

  Future<ObjectDetector> _initReferenceObjectDetectorWithLocalModel() async {
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
    String y = filePath == null ? await _copy("assets/dog.webp") : filePath!;
    List<DetectedObject?> objects = await predictor.detect(imagePath: y) ?? [];

    ObjectDetector referencePredictor =
        await _initReferenceObjectDetectorWithLocalModel();
    String xx =
        await referencePredictor.loadModel(useGpu: true) ?? "Failed GPU?";
    String yy = filePath == null ? await _copy("assets/dog.webp") : filePath!;
    List<DetectedObject?> referenceObjects =
        await referencePredictor.detect(imagePath: yy) ?? [];

    DetectedObject maxReference = DetectedObject(
        confidence: -1, boundingBox: Rect.zero, index: -1, label: "");
    for (DetectedObject? o in referenceObjects) {
      if (o != null && o.confidence > maxReference.confidence) {
        maxReference = o;
      }
    }
    print("Reference, Confidence: ${maxReference.confidence}");
    print("Reference, Width in px: ${maxReference.boundingBox.width}");
    print("Reference, Height in px: ${maxReference.boundingBox.height}");

    final double scalingFactorX = 1.85 / maxReference.boundingBox.width;
    final double scalingFactorY = 1.85 / maxReference.boundingBox.height;

    print("Reference, Scaling Factor for Width: $scalingFactorX");
    print("Reference, Scaling Factor for Height: $scalingFactorY");

    return Rec(
        detectedObject: objects,
        column: Column(
          children: [
            Text("$x, $xx"),
            if (objects.isNotEmpty)
              // TODO: Make the table such that it includes item label, color of bounding box and size (autofilled if known)
              DataTable(
                columns: const [
                  DataColumn(label: Text("Label")),
                  // DataColumn(label: Text("Confidence")),
                  // DataColumn(label: Text("Rect")),
                  DataColumn(label: Text("X x Y (cm)")),
                  DataColumn(label: Text("X x Y (px)")),
                ],
                rows: objects.where((e) => e != null).map(
                  // rows: objects.where((e) => e != null).map(
                  (object) {
                    return DataRow(
                      cells: [
                        // DataCell(Text(object?.label ?? "What")),
                        DataCell(Text(colorNameList[objects.indexOf(object)])),
                        // DataCell(
                        //   Text(
                        //     object?.confidence.toStringAsFixed(2) ?? "What",
                        //   ),
                        // ),
                        // DataCell(
                        //   Text(
                        //     object?.boundingBox.toString().substring(object
                        //             .boundingBox
                        //             .toString()
                        //             .indexOf("(")) ??
                        //         "0",
                        //   ),
                        // ),
                        // const DataCell(TextField()),
                        // const DataCell(TextField())
                        DataCell(Text(
                            "${((object?.boundingBox.width ?? 0) * scalingFactorX).toStringAsFixed(2)} x ${((object?.boundingBox.height ?? 0) * scalingFactorY).toStringAsFixed(2)} cm")),
                        DataCell(Text(
                            "${(object?.boundingBox.width ?? 0).toStringAsFixed(2)} x ${(object?.boundingBox.height ?? 0).toStringAsFixed(2)} px")),
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
  Color color;

  RectPainter(this.rect, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(RectPainter oldDelegate) => false;
}

class Rec {
  final List<DetectedObject?> detectedObject;
  final Widget column;

  const Rec({required this.detectedObject, required this.column});
}
