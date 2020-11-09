import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
//import 'package:image_picker/image_picker.dart';
import 'painter.dart';
import 'package:image/image.dart' as test;

//import 'package:exif/exif.dart';
//import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

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
  String imagePath;
  ValueNotifier<CameraFlashes> _switchFlash;
  ValueNotifier<double> zoomNotifier;
  ValueNotifier<Sensors> sensor;
  ValueNotifier<Size> _photoSize;
  PictureController controller;
  bool _inactive = false;
  double _previousScale = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    update_db();

    _switchFlash = ValueNotifier(CameraFlashes.AUTO);
    zoomNotifier = ValueNotifier(0);

    sensor = ValueNotifier(Sensors.BACK);
    _photoSize = ValueNotifier(null);
    controller = PictureController();
    _previousScale = 1;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
      _switchFlash.dispose();
      _photoSize.dispose();
      sensor.dispose();
      zoomNotifier.dispose();
      print("disposing");
      super.dispose();
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
    if (controller == null) {
      return;
      _switchFlash.dispose();
      _photoSize.dispose();
      sensor.dispose();
      zoomNotifier.dispose();
    }
    if (state == AppLifecycleState.inactive) {
      setState(() {
        _inactive = true;
      });
    } else if (state == AppLifecycleState.resumed) {
      setState(() {
        //_inactive = false;
      });
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
    String last_change_filename = "last_change";
    String last_change_url = "$_url/$last_change_filename";
    String last_change;
    try {
      File last_change_file = await get_local_file(last_change_filename);
      last_change = await last_change_file.readAsString();
    } on FileSystemException catch (_) {
      return true;
    }
    String last_remote_change;
    try {
      last_remote_change = await http.read(last_change_url);
    } on SocketException catch (_) {
      print("Network error, no change found.");
      return false;
    }
    return last_change != last_remote_change;
  }

  Future<void> update_db() async {
    String last_change_filename = "last_change";
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
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget cameraGetter() {
    if (_inactive) {
      setState(() {
        _inactive = false;
      });
    }
    return _cameraPreviewWidget();
  }

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
                  child: cameraGetter(),
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
          padding: const EdgeInsets.fromLTRB(10.0, 0, 10, 0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: IconButton(
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
                ),
              ),
              Expanded(
                child: Container(),
                flex: 2,
              ),
              Expanded(
                child: IconButton(
                  icon: Icon(_getFlashIcon()),
                  onPressed: () async {
                    switch (_switchFlash.value) {
                      case CameraFlashes.AUTO:
                        _switchFlash.value = CameraFlashes.ON;
                        break;
                      case CameraFlashes.ON:
                        _switchFlash.value = CameraFlashes.NONE;
                        break;
                      /*case CameraFlashes.AUTO:
                        _switchFlash.value = CameraFlashes.ALWAYS;
                        break;
                      case CameraFlashes.ALWAYS:
                        _switchFlash.value = CameraFlashes.NONE;
                        break;*/
                    }
                    setState(() {});
                  },
                ),
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
              onPressed: controller != null
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

  IconData _getFlashIcon() {
    switch (_switchFlash.value) {
      case CameraFlashes.NONE:
        return Icons.flash_off;
      case CameraFlashes.ON:
        return Icons.flash_on;
      case CameraFlashes.AUTO:
        return Icons.flash_auto;
      case CameraFlashes.ALWAYS:
        return Icons.highlight;
      default:
        return Icons.flash_off;
    }
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    return GestureDetector(
      onScaleStart: (ScaleStartDetails details) {
      //print(details);
      // Does this need to go into setState, too?
      // We are only saving the scale from before the zooming started
      // for later - this does not affect the rendering...
      _previousScale = zoomNotifier.value + 1;
    },
    onScaleUpdate: (ScaleUpdateDetails details) {
    //print(details.scale);
      double result = _previousScale * (details.scale) - 1;
    if (result < 1 && result > 0) {
      zoomNotifier.value = result;
    }
    setState(() {});
    },
      child: CameraAwesome(
        testMode: false,
        onPermissionsResult: (bool result) {},
        selectDefaultSize: (availableSizes) {
          if (availableSizes.length == 1) return availableSizes[0];
          return availableSizes[1];
        },
        onCameraStarted: () {print("started");},
        zoom: zoomNotifier,
        sensor: sensor,
        photoSize: _photoSize,
        switchFlashMode: _switchFlash,
        fitted: false,
      ),
    );
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
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
    //await CamerawesomePlugin.focus();
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
    if (controller == null) {
      showInSnackBar('Error: no camera found.');
      return null;
    }
    // todo check for image already being taken

    String tmpPath = await getImagePath();
    try {
      //await controller.takePicture(tmpPath);
      await controller.takePicture(tmpPath);
      tmpPath = await fixExifRotation(tmpPath);
    } on Exception catch (e) {
      _showCameraException(e);
      return null;
    }
    test.Image image = test.decodeImage(File(tmpPath).readAsBytesSync());
    test.Image orientedImage = test.bakeOrientation(image);
    // Save the thumbnail as a PNG.

    await File(tmpPath + '.jpg')
      ..writeAsBytesSync(test.encodeJpg(orientedImage));
    return tmpPath + '.jpg';
  }

  void _showCameraException(Exception e) {
    //logError(e.code, e.description);
    //showInSnackBar('Error: ${e.code}\n${e.description}');
    print("Error when taking image");
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


Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CameraApp());
}
