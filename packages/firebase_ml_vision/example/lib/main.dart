import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'painter.dart';
import 'package:image/image.dart' as test;
//import 'package:exif/exif.dart';
//import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import "package:convert/convert.dart";

class CameraExampleHome extends StatefulWidget {
  @override
  _CameraExampleHomeState createState() {
    return _CameraExampleHomeState();
  }
}

void logError(String code, String message) =>
    print('Error: $code\nError Message: $message');

class _CameraExampleHomeState extends State<CameraExampleHome>
    with WidgetsBindingObserver {
  CameraController controller;
  CameraDescription description;
  String imagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    onNewCameraSelected();
    update_db();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (controller != null) {
        onNewCameraSelected();
      }
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get_local_file(String filename) async {
    final path = await _localPath;
    return File('$path/$filename');
  }

  String get _url {
    final url = "https://food-intolerances.netlify.app";
    return url;
  }


  Future<bool> check_for_db_change() async {
    String last_change_filename =  "last_change";
    String last_change_url = "$_url/$last_change_filename";
    String last_change;
    try {
      File last_change_file = await get_local_file(last_change_filename);
      last_change = await last_change_file.readAsString();
    } on FileSystemException catch (_) {
      return true;
    }
    String last_remote_change;
    try{
      last_remote_change = await http.read(last_change_url);
    } on SocketException catch (_) {
      print("Network error, no change found.");
      return false;
    }
    return last_change != last_remote_change;
  }

  Future<void> update_db() async {
    String last_change_filename =  "last_change";
    String last_change_url = "$_url/$last_change_filename";
    String db_filename = "sortedIngredients.json";
    String db_url = "$_url/$db_filename";
    if (!await check_for_db_change()) {
      return;
    }
    print("updating db");
    String last_remote_change;
    http.Response db_response;
    try {
       last_remote_change = await http.read(last_change_url);
       db_response = await http.get(db_url);
    } on SocketException catch (_) {
      print("Network error, not updating.");
      return;
    }

    if (db_response.statusCode == 200) {
      String db = db_response.body;
      File db_file = await get_local_file(db_filename);
      db_file.writeAsString(db);
      File last_change_file = await get_local_file(last_change_filename);
      last_change_file.writeAsString(last_remote_change);
    }


  }

  Future<String> getImagePath() async {
    Directory tmpDir = await getTemporaryDirectory();
    final String dirPath = '${tmpDir.path}/img';

    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.png';
    return filePath;
  }

  Future<String> fixExifRotation(String imagePath) async {
    return imagePath;
    /*final originalFile = File(imagePath);
    List<int> imageBytes = await originalFile.readAsBytes();
    await FlutterImageCompress.compressWithFile(
      originalFile.absolute.path,
      quality: 90,
      minWidth: 1024,
      minHeight: 1024,
      rotate: 90,
    );
    print("ßßßßßßßß");

    // We'll use the exif package to read exif data
    // This is map of several exif properties
    // Let's check 'Image Orientation'
    final exifData = await readExifFromBytes(imageBytes);

    File fixedImage;

    if (exifData['Image Orientation'].printable.contains('Horizontal')) {
      fixedImage = await FlutterImageCompress.compressAndGetFile(
          imagePath, await getImagePath(),
          quality: 100, rotate: 90);
    } else if (exifData['Image Orientation'].printable.contains('180')) {
      fixedImage = await FlutterImageCompress.compressAndGetFile(
          imagePath, await getImagePath(),
          quality: 100, rotate: -90);
    } else {
      fixedImage = await FlutterImageCompress.compressAndGetFile(
          imagePath, await getImagePath(),
          quality: 100, rotate: 0);
    }
    return fixedImage.path;*/
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      key: _scaffoldKey,
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.all(1.0),
                child: Center(
                  child: _cameraPreviewWidget(),
                ),
              ),
            ),
          ),
          // _captureControlRowWidget(),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        child: Container(
          height: 75,
          padding: const EdgeInsets.fromLTRB(10.0,0,10,0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.photo_library),
                onPressed: () async {
                  /*final String imagePath =
                      (await _picker.getImage(source: ImageSource.gallery)).path;*/
                  final String imagePath = (await FilePicker.platform
                              .pickFiles(type: FileType.image))
                          .files
                          .single
                          .path;
                  print(imagePath);
                  await getAnalyzeView(context, imagePath);
                },
              )
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        height: 65.0,
        width: 65.0,
        child: FittedBox(
          child: FloatingActionButton(
              onPressed: controller != null && controller.value.isInitialized
                  ? onTakePictureButtonPressed
                  : null,
              child: Icon(Icons.camera),
              backgroundColor: Colors.blue
            // ...FloatingActionButton properties...
          ),
        ),
      ),

      // Here's the new attribute:

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        'No camera found',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          // fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      );
    }
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  void onNewCameraSelected() async {
    if (controller != null) {
      await controller.dispose();
    }
    List<CameraDescription> cameras = await availableCameras();
    if (cameras.length == 0) {
      return;
    }
    controller = CameraController(
      (await availableCameras()).first,
      ResolutionPreset.ultraHigh,
      enableAudio: false,
    );

    // If the controller is updated then update the UI.
    controller.addListener(() {
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        showInSnackBar('Camera error ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
      /*controller.startImageStream((image) async {
        //print(image.runtimeType);

        final FirebaseVisionImageMetadata metadata = FirebaseVisionImageMetadata(
            rawFormat: image.format.raw,
            size: Size(image.width.toDouble(),image.height.toDouble()),
            planeData: image.planes.map((currentPlane) => FirebaseVisionImagePlaneMetadata(
                bytesPerRow: currentPlane.bytesPerRow,
                height: currentPlane.height,
                width: currentPlane.width
            )).toList(),
            rotation: ImageRotation.rotation90
        );
        FirebaseVisionImage tmp = FirebaseVisionImage.fromBytes(image.planes[0].bytes, metadata);
        VisionText x = await _recognizer.processImage(tmp);
        print(x.text);

      });*/
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future getAnalyzeView(BuildContext context, String filePath) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return PicturePainter(
            imageFile: File(filePath),
          ); //PictureScanner(imageFile: File(path));
        },
      ),
    );
  }

  void onTakePictureButtonPressed() async {
    String filePath = await takePicture();
    if (mounted) {
      setState(() {
        imagePath = filePath;
      });
      if (filePath != null) {
        await getAnalyzeView(context, filePath);
        Directory tmpDir = await getTemporaryDirectory();
        //print((await tmpDir.list().toList()));
        final Directory img = Directory('${tmpDir.path}/img');
        await img.delete(recursive: true);
        //print("");
        //print((await tmpDir.list().toList()).length);
      }
    }
  }

  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      showInSnackBar('Error: no camera found.');
      return null;
    }

    if (controller.value.isTakingPicture) {
      return null;
    }

    String tmpPath = await getImagePath();
    try {
      await controller.takePicture(tmpPath);
      tmpPath = await fixExifRotation(tmpPath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    test.Image image = test.decodeImage(File(tmpPath).readAsBytesSync());
    test.Image orientedImage = test.bakeOrientation(image);
    // Save the thumbnail as a PNG.

    await File(tmpPath + '.png')
      ..writeAsBytesSync(test.encodePng(orientedImage));
    return tmpPath + '.png';
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}

class CameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraExampleHome(),
    );
  }
}

List<CameraDescription> cameras = [];

Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logError(e.code, e.description);
  }
  runApp(CameraApp());
}
