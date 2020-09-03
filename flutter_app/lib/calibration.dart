import 'dart:math';
import 'dart:ui';

import 'package:flame/position.dart';
import 'package:flame/text_config.dart';
import 'package:flutter_app/myGame.dart';

class Calibration {
  final MyGame game;
  String hint;
  String status = " ";
  String entireText;
  TextConfig config;
  int lineLength;

  Calibration(this.game) {
    hint = "Aktivieren Sie den  \n Kopplungsmodus für Ihre Kopfhörer.";
    config = TextConfig(
        fontSize: game.tileSize / 3,
        fontFamily: 'Georgia',
        textAlign: TextAlign.center);
    generateText();
  }

  void render(Canvas c) {
    generateText();
    config.render(
        c,
        entireText,
        Position(
            game.screenSize.width / 2 -
                game.tileSize / 3 * (lineLength / 4 + 1.5),
            game.screenSize.height / 2 + game.tileSize / 2));
  }

  void updateStatus(String s) {
    status = "Status: " + s;
  }

  void getLengthOfLongestLine() {
    lineLength = entireText
        .split("\n")
        .fold(0, (prev, element) => max<int>(prev, element.length));
  }

  void generateText() {
    if (!game.bluetoothManager.connected)
      entireText = hint + "\n\n" + status;
    else {
      if (!game.player.setUp) {
        entireText =
            "Halten Sie Ihren Kopf für \n 3 Sekunden in einer neutralen Position";
      } else {
        entireText = "";
      }
    }
    getLengthOfLongestLine();
  }

  void update(double t) {}
}
