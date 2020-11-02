// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';

enum Detector { text }

// Paints rectangles around all the text in the image.
class TextDetectorPainter extends CustomPainter {
  TextDetectorPainter(
      this.absoluteImageSize, this.visionText, this.ingredients);

  final Size absoluteImageSize;
  final VisionText visionText;
  final Map<String, dynamic> ingredients;
  List<TextElement> alreadyPainted = [];

  final List<String> blackList = ["ein", "eis", "einer", "eines", "einen"];
  final List<String> schlechteZubereitung = ["Gulasch", "geschmort"];

  String formatName(String name) {
    if (name.length < 1) return "";
    if (name.substring(0, 1) == " " && name.length > 1) {
      name = name.substring(1, name.length - 1);
    }
    return name
        .toLowerCase()
        .replaceAll(RegExp(r"[äâàáãåā]"), "a")
        .replaceAll(RegExp(r"[èéêēëė]"), "e")
        .replaceAll(RegExp(r"[îíìïī]"), "i")
        .replaceAll(RegExp(r"[öōøõóòô]"), "o")
        .replaceAll(RegExp(r"[üûūùú]"), "u")
        .replaceAll(RegExp(r"[ç]"), "c")
        .replaceAll(RegExp(r"[ñń]"), "n")
        .replaceAll(RegExp(r"[šś]"), "s")
        .replaceAll(RegExp(r"^.+'s "), "");
  }

  bool checkWord(String input) {
    String inputWithoutUmlaute = formatName(input);

    return ingredients.containsKey(inputWithoutUmlaute);
  }

  String searchWord(String ingredient) {
    ingredient = formatName(ingredient);
    //print(ingredient);
    if (ingredient.length <= 1 || blackList.contains(ingredient)) return null;
    List<String> wordAdditions = [
      "",
      "saft",
      "konzentrat",
      "saftkonzentrat",
      "schorle",
      "mark",
      "mus",
      "eis",
      "sorbet",
      "ecken",
      "flocken",
      "kerne",
      "pulver",
      "mehl",
      "grieß",
      "extrakt"
    ];
    for (String addition in wordAdditions) {
      String concatenatedWord = ingredient + addition;
      //if (checkWord(concatenatedWord)) return concatenatedWord;

      /*String addDifferentForms = searchDifferentForms(concatenatedWord);
      if (addDifferentForms != null && !blackList.contains(addDifferentForms))
        return addDifferentForms;*/
      if (ingredient.length > addition.length) {
        if (ingredient.substring(
                ingredient.length - addition.length, ingredient.length) ==
            addition) {
          String removedWord =
              ingredient.substring(0, ingredient.length - addition.length);
          if (checkWord(removedWord)) return removedWord;

          String removeDifferentForms = searchDifferentForms(removedWord);
          if (removeDifferentForms != null) return removeDifferentForms;
        }
      }
    }
    // replace i with l, l with i, ü with ii, j with i, i with j
    /*List<List<String>> similarLookingCharGroups = [["i", "j", "l"], ["ü", "ll", "ii", "jj"], ["e", "b"], ["h", "k"]];
    for (List<String> similarChars in similarLookingCharGroups) {
      for (String similarChar in similarChars) {
        if (ingredient.contains(similarChar))
      }
    }*/
    // fallback if no match was found, searching
    List<List<dynamic>> matches = [];
    for (int y = ingredient.length - 1; y > 0; y--) {
      String substr = ingredient.substring(0, y);
      if (blackList.contains(substr)) break;
      if (checkWord(substr)) matches.add([substr, ingredients[substr]]);
    }
    if (matches.isNotEmpty) {
      matches.sort((a, b) => a[1]["duration"].compareTo(b[1]["duration"]));
      return matches[matches.length - 1][0];
    }

    return null;
  }

  String searchDifferentForms(String ingredient) {
    ingredient = formatName(ingredient);
    List<String> stems = ["e", "en", "s", "se", "n"];
    if (blackList.contains(ingredient)) return null;

    for (String stem in stems) {
      String concatenatedWord = ingredient + stem;
      if (checkWord(concatenatedWord) && !blackList.contains(concatenatedWord))
        return concatenatedWord;
      if (ingredient.length > stem.length &&
          ingredient.substring(
                  ingredient.length - stem.length, ingredient.length) ==
              stem) {
        String removedWord =
            ingredient.substring(0, ingredient.length - stem.length);
        if (checkWord(removedWord) && !blackList.contains(removedWord))
          return removedWord;
      }
    }
    return null;
  }

  bool checkIfNextPartOfString(
      String target, List<TextElement> elements, TextElement nextElem) {
    int currentWordLength = 0;
    String substr;
    for (TextElement element in elements) {
      currentWordLength += element.text.length;
    }
    if (currentWordLength >= target.length) return false;
    if (currentWordLength + nextElem.text.length >= target.length) {
      substr = target.substring(currentWordLength, target.length);
    } else {
      substr = target.substring(
          currentWordLength, currentWordLength + nextElem.text.length);
    }
    if (substr.indexOf(nextElem.text) == 0) return true;
    return false;
  }

  List<TextElement> getElementsFromLine(String target, TextLine line) {
    List<TextElement> targets = [];
    int lastIndex = 0;
    for (TextElement element in line.elements) {
      var text = formatName(element.text);
      // match whole line
      if (text != null && text != "") {
        String replacedWholeString =
            text.replaceAll(RegExp(r"[^A-zäöüß0-9 /-]+"), "");
        if (replacedWholeString != "" &&
            target.contains(replacedWholeString, lastIndex) &&
            !targets.contains(element)) {
          if (checkIfNextPartOfString(target, targets, element)) {
            lastIndex = target.indexOf(replacedWholeString);
            targets.add(element);
          }
        }
      }
      // match all space separated words in the line
      for (RegExpMatch ingrMatch
          in RegExp(r"[A-zäöüß0-9 ]+").allMatches(text).toList()) {
        String ingr = text.substring(ingrMatch.start, ingrMatch.end);
        if (ingr != null && ingr != "") {
          if (target.contains(ingr, lastIndex) && !targets.contains(element)) {
            if (checkIfNextPartOfString(target, targets, element)) {
              lastIndex = target.indexOf(ingr);
              targets.add(element);
            }
          }
        }
      }
    }
    return targets;
  }

  bool matchWholeLine(Canvas canvas, Size size, TextLine line) {
    String formatted = formatName(line.text.toLowerCase());
    for (var ingr in RegExp(r"[A-zäöüß0-9][A-zäöüß0-9 /-]*[A-zäöüß0-9]*")
        .allMatches(formatted)
        .toList()) {
      var text = formatted.substring(ingr.start, ingr.end);
      //print(text);
      String targetString = searchWord(text);
      //print(targetString);
      if (targetString != null) {
        if (shouldPaint(canvas, size, getElementsFromLine(targetString, line),
            targetString)) ;
      }
    }
    return false;
  }

  RegExp exp = RegExp(r"[Ee][ -]?[0-9]+[a-z]?|[A-zÀ-úaÄöÖüÜß]+");
  bool lastWordWasNewLined = false;
  TextContainer lastElement;
  String lastText;

  bool matchSingleElement(Canvas canvas, Size size, TextLine line) {
    for (TextElement element in line.elements) {
      // match each word in line
      /*if (lastWordWasNewLined) {
        lastWordWasNewLined = false;
        continue;
      }*/
      if (shouldPaint(canvas, size, [element],
          element.text.toLowerCase().replaceAll(RegExp(r"[^A-zäöüß-]+"), ""))) ;
      for (var ingr in exp.allMatches(element.text.toLowerCase()).toList()) {
        var text = element.text.toLowerCase().substring(ingr.start, ingr.end);
        lastElement = element;
        lastText = text;
        if (shouldPaint(canvas, size, [element], text)) ;
      }
    }
    return false;
  }

  bool matchLineBreak(
      Canvas canvas, Size size, TextBlock block, int lineIndex) {
    List<String> umbrueche = ["konzentrat", "zentrat", "öl", "pulver"];
    TextLine line = block.lines[lineIndex];
    if (lineIndex + 1 < block.lines.length && lastText != null) {
      String nextLine = block.lines[lineIndex + 1].text;
      if (line.text[line.text.length - 1] == "-" ||
          umbrueche.contains(formatName(getFirstMatch(exp, nextLine)))) {
        // word split by line with -
        TextLine otherLine = block.lines[lineIndex + 1];

        String end = getFirstMatch(exp, otherLine.text);
        String whole = lastText + end;
        if (shouldPaint(
                canvas, size, [lastElement, otherLine.elements[0]], whole) !=
            null) {
          lastWordWasNewLined = true;
          return true;
        }
      }
    }
    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    alreadyPainted = [];
    for (TextBlock block in visionText.blocks) {
      for (int lineIndex = 0; lineIndex < block.lines.length; lineIndex++) {
        if (lastWordWasNewLined) {
          lastWordWasNewLined = false;
          continue;
        }
        TextLine line = block.lines[lineIndex];
        // print(line.text);
        // match whole line split by everything except ,
        if (matchWholeLine(canvas, size, line)) {
          //continue;
        }
        if (matchSingleElement(canvas, size, line)) {
          //continue;
        }
        if (matchLineBreak(canvas, size, block, lineIndex)) {
          //continue;
        }
      }
    }
  }

  String getFirstMatch(RegExp exp, String string) {
    RegExpMatch endIndex = exp.firstMatch(string);
    if (endIndex == null) return "";
    String end = string.substring(endIndex.start, endIndex.end);
    return end;
  }

  bool shouldPaint(Canvas canvas, Size size, List<TextContainer> elements,
      String ingredient) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;
    Rect scaleRect(TextContainer container) {
      return Rect.fromLTRB(
        container.boundingBox.left * scaleX,
        container.boundingBox.top * scaleY,
        container.boundingBox.right * scaleX,
        container.boundingBox.bottom * scaleY,
      );
    }

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    paint.color = Colors.green;
    if (ingredient.contains("aroma") ||
        ingredient.contains("aromen") ||
        schlechteZubereitung.any((String ing) => ingredient.contains(ing))) {
      paint.color = Colors.blue;
      for (TextElement element in elements) {
        if (!alreadyPainted.contains(element)) {
          canvas.drawRect(scaleRect(element), paint);
          alreadyPainted.add(element);
        }
      }
    } else {
      //print("should paing " + ingredient);
      String found_word = searchWord(ingredient);
      if (found_word != null) {
        //print("found word " + found_word + elements.length.toString());
        switch (ingredients[formatName(found_word)]["duration"]) {
          case 1:
            {
              paint.color = Colors.green;
            }
            break;
          case 2:
            {
              paint.color = Colors.orange;
            }
            break;
          case 3:
            {
              paint.color = Colors.red;
            }
            break;
          case -1:
            {
              paint.color = Colors.blue;
            }
            break;
        }
        for (TextContainer element in elements) {
          if (!alreadyPainted.contains(element)) {
            canvas.drawRect(scaleRect(element), paint);
            alreadyPainted.add(element);
          }
        }
        return true;
      }
    }
    return false;
  }

  @override
  bool shouldRepaint(TextDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.visionText != visionText;
  }
}
