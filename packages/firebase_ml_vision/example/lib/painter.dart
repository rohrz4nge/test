import 'dart:async';
import 'dart:io';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';

import 'detector_painters.dart';

import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class PicturePainter extends StatefulWidget {
  final File imageFile;

  PicturePainter({Key key, @required this.imageFile}) : super(key: key);

  _PicturePainterState createState() => _PicturePainterState();
}

class _PicturePainterState extends State<PicturePainter> {
  double _scale = 1.0;
  double _previousScale = 1.0;

  Future<Size> _getImageSize() async {
    final Completer<Size> completer = Completer<Size>();

    final Image image = Image.file(widget.imageFile);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ));
      }),
    );

    final Size imageSize = await completer.future;
    return imageSize;
  }

  Future<dynamic> _scanImage() async {
    final FirebaseVisionImage visionImage =
        await FirebaseVisionImage.fromFile(widget.imageFile);
    final TextRecognizer textRecognizer =
        FirebaseVision.instance.textRecognizer();

    final VisionText visionText =
        await textRecognizer.processImage(visionImage);
    return visionText;
  }

  String formatName(String name) {
    return name
        .toLowerCase()
        .toLowerCase()
        .replaceAll("ä", "a")
        .replaceAll("ö", "o")
        .replaceAll("ü", "u");
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<String> get_local_filename(String filename) async {
    final path = await _localPath;
    return '$path/$filename';
  }

  Future<Map<String, dynamic>> loadJSON() async {
    String cached_db_path = await get_local_filename("sortedIngredients.json");
    String path = 'assets/sortedIngredients.json';
    if (FileSystemEntity.typeSync(cached_db_path) !=
        FileSystemEntityType.notFound) {
      path = cached_db_path;
    }
    final loaded_data = await rootBundle.loadString(path);
    final Map<String, dynamic> ingredients =
        (await json.decode(loaded_data)); //["ingredients"];
    Map<String, dynamic> ingredient_map = {};
    ingredients.forEach((k, v) {
      for (String synonym in v["synonyms"]) {
        ingredient_map[formatName(synonym)] = v["histamin"];
      }
      ingredient_map[formatName(v["title"])] = v["histamin"];
    });
    return ingredient_map;
  }

  CustomPaint _buildResults(
      Size imageSize, dynamic results, Map<String, dynamic> ingredients) {
    CustomPainter painter =
        TextDetectorPainter(imageSize, results, ingredients);

    return CustomPaint(
      painter: painter,
    );
  }

  Widget _buildImage() {
    return FutureBuilder(
      future: Future.wait([_getImageSize(), _scanImage(), loadJSON()]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return InteractiveViewer(
              boundaryMargin: EdgeInsets.all(0.0),
              minScale: 1,
              maxScale: 5,
              child: Container(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: snapshot.data[0].aspectRatio,
                    child: Container(
                      constraints: const BoxConstraints.expand(),
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: Image.file(widget.imageFile).image,
                          fit: BoxFit.fill,
                        ),
                      ),
                      child: _buildResults(
                          snapshot.data[0], snapshot.data[1], snapshot.data[2]),
                    ),
                  ),
                ),
              ));
        } else {
          return Container(
            constraints: const BoxConstraints.expand(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                    child: CircularProgressIndicator(), width: 50, height: 50),
              ],
            ),
          );
        }
      },
    );
    /*return Center(
      child: GestureDetector(
        onScaleStart: (ScaleStartDetails details) {
          print(details);
          _previousScale = _scale;
          setState(() {});
        },
        onScaleUpdate: (ScaleUpdateDetails details) {
          print(details);
          _scale = _previousScale * details.scale;
          setState(() {});
        },
        onScaleEnd: (ScaleEndDetails details) {
          print(details);

          _previousScale = 1.0;
          setState(() {});
        },
        child: RotatedBox(
          quarterTurns: 0,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Transform(
              alignment: FractionalOffset.center,
              transform: Matrix4.diagonal3(Vector3(_scale, _scale, _scale)),
              child: Container(
                constraints: const BoxConstraints.expand(),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: Image.file(widget.imageFile).image,
                    fit: BoxFit.fill,
                  ),
                ),
                child: FutureBuilder(
                  future: Future.wait([_getImageSize(), _scanImage(), loadJSON()]),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return _buildResults(
                          snapshot.data[0], snapshot.data[1], snapshot.data[2]);
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                              child: CircularProgressIndicator(), width: 50, height: 50),
                        ],
                      );
                    }
                  },
                ),
              )
            ),
          ),
        ),
      ),
    );*/
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomAppBar(
        shape: new CircularNotchedRectangle(),
        child: Container(
          height: 75,
          padding: const EdgeInsets.fromLTRB(10.0, 0, 10, 0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                  icon: Icon(Icons.chevron_left),
                  iconSize: 30,
                  onPressed: () {
                    Navigator.pop(context);
                  })
            ],
          ),
        ),
      ),
      body: _buildImage(),
      /*floatingActionButton: FloatingActionButton(
        onPressed: () => null,
        tooltip: 'Pick Image',
        child: const Icon(Icons.add_a_photo),
      ),*/
    );
  }
}
