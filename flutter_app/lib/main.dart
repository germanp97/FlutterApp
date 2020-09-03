import 'package:flame/flame.dart';
import 'package:flame/util.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'myGame.dart';

void main() async {
  MyGame game = MyGame();
  Util flameUtil = Util();

  runApp(game.widget);
  flameUtil.fullScreen();
  flameUtil.setOrientation(DeviceOrientation.portraitUp);

  Flame.images.loadAll(<String>[
    'crossf.png',
    'start.png',
    'calibrate.png',
    'loading.png',
    'star.png',
  ]);

  TapGestureRecognizer tapper = TapGestureRecognizer();
  tapper.onTapDown = game.onTapDown;
  tapper.onTapUp = game.onTapUp;
  flameUtil.addGestureRecognizer(tapper);
}