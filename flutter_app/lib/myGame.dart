import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/position.dart';
import 'package:flame/sprite.dart';
import 'package:flame/text_config.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'bluetooth.dart';
import 'calibration.dart';

class MyGame extends Game {
  Size screenSize;
  Player player;
  Score score;
  MyTimer timer;
  double tileSize;
  List<Target> targets;
  Random random;
  bool gameOver;
  StartButton startButton;
  BluetoothManager bluetoothManager;
  Calibration calibration;

  MyGame() {
    initialize();
  }

  void initialize() async {
    resize(await Flame.util.initialDimensions());
    gameOver = true;
    random = Random();
    score = Score(this);
    timer = MyTimer(this, 3);
    targets = List<Target>();
    player =
        Player(this, screenSize.width / 2, screenSize.height / 2 - tileSize);
    startButton = StartButton(this);
    bluetoothManager = BluetoothManager(this);
    calibration = Calibration(this);
  }

  Future<void> startGame() async {
    targets.clear();
    spawnTarget();
    gameOver = false;
  }

  void stopGame() {
    gameOver = true;
    startButton.reStart();
    score.reStart();
    player.finishCalibration();
  }

  void spawnTarget() {
    double x = random.nextDouble() * (screenSize.width - 2 * tileSize);
    double y = -3;
    Target newTarget = Target(this, x, y);
    targets.add(newTarget);
  }

  void render(Canvas canvas) {
    Rect bgRect = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);

    Paint bgPaint = Paint();
    bgPaint.color = Color(0xffffffff);
    canvas.drawRect(bgRect, bgPaint);
    targets.forEach((Target target) => target.render(canvas));
    player.render(canvas);
    startButton.render(canvas);
    calibration.render(canvas);
    score.render(canvas);
  }

  void update(double t) {
    if (!gameOver) {
      player.update(t);
      if (targets.isNotEmpty) {
        targets.forEach((Target target) => target.update(1.0));
      }
    }
  }

  void resize(Size size) {
    screenSize = size;
    super.resize(size);
    tileSize = screenSize.width / 9;
  }

  void onTapDown(TapDownDetails d) {
    if (!gameOver) {
      targets.forEach((Target target) {
        if (target.targetRect.contains(player.playerRect.center)) {
          targets.remove(target);
          score.increment();
          timer.addTime(1);
          spawnTarget();
        }
      });
    } else {
      if (startButton.textContainer.contains(d.globalPosition)) {
        startButton.onTapDown();
      }
    }
  }

  void onTapUp(TapUpDetails d) {
    if (gameOver) {
      if (startButton.textContainer.contains(d.globalPosition)) {
        startButton.onTapUp();
      }
    }
  }

  void onSensorEvent(List<double> accl, List<double> gyro) {
    player.onSensorEvent(accl, gyro);
  }
}

class Player {
  final MyGame game;
  Rect playerRect;
  double sensitivity = 0.5;
  Sprite crosshair = Sprite('crosshair.png');
  bool setUp = false;
  bool calibrationPhase = false;
  int size = 4;
  List<double> initialPos = List(2);
  List<List<double>> position = List(2);
  List<List<double>> calibratePosition = List(2);
  List<double> average = List(2);

  Player(this.game, double x, double y) {
    playerRect = Rect.fromLTWH(x - game.tileSize, y - game.tileSize,
        game.tileSize * 2, game.tileSize * 2);
    position[0] = List(size);
    position[1] = List(size);
    for (var i = 0; i < size; i++) {
      position[0][i] = 0;
      position[1][i] = 0;
    }
    calibratePosition[0] = new List();
    calibratePosition[1] = new List();
    initialPos[0] = 0;
    initialPos[1] = 0;
  }

  void render(Canvas c) {
    crosshair.renderRect(c, playerRect);
  }

  void update(double t) {
    average = getAvgPosition(position);
    average[0] -= initialPos[0];
    average[1] -= initialPos[1];
    if (isInside(average[0] * sensitivity, 0))
      playerRect = playerRect.translate(average[0] * sensitivity, 0);
    if (isInside(0, average[1] * sensitivity))
      playerRect = playerRect.translate(0, average[1] * sensitivity);
  }

  bool isInside(double x, double y) {
    if (playerRect.bottom + y > game.screenSize.height) {
      return false;
    }
    if (playerRect.right + x > game.screenSize.width) {
      return false;
    }
    if (playerRect.top + y < 0) {
      return false;
    }
    if (playerRect.left + x < 0) {
      return false;
    }

    return true;
  }

  void finishCalibration() {
    if (calibrationPhase) {
      calibrationPhase = false;
      setUp = true;
      initialPos = getAvgPosition(calibratePosition);
    }
  }

  void setUpSensor(List<double> accl, List<double> gyro) {
    if (calibrationPhase) {
      calibratePosition[0].add(gyro[0]);
      calibratePosition[1].add(gyro[2]);
    }
  }

  void onSensorEvent(List<double> accl, List<double> gyro) {
    addValues(gyro[0], gyro[2], position);
  }

  void addValues(double x, double y, List<List<double>> vec) {
    for (var i = 0; i < vec[0].length - 1; i++) {
      vec[0][i] = vec[0][i + 1];
      vec[1][i] = vec[1][i + 1];
    }
    vec[0][vec[0].length - 1] = x;
    vec[1][vec[1].length - 1] = y;
  }

  List<double> getAvgPosition(List<List<double>> vec) {
    List<double> avg = List(2);
    avg[0] = vec[0].reduce((current, next) => current + next) / vec[0].length;
    avg[1] = vec[1].reduce((current, next) => current + next) / vec[1].length;
    return avg;
  }
}

class Score {
  final MyGame game;
  String textScore;
  int intScore;
  TextConfig config;

  Score(this.game) {
    intScore = 0;
    textScore = "Punkte: 0";
    config = TextConfig(
        fontSize: game.tileSize,
        fontFamily: 'Roboto',
        textAlign: TextAlign.center);
  }

  void reStart() {
    intScore = 0;
    textScore = "Punkte: 0";
  }

  void render(Canvas c) {
    config.render(
        c,
        textScore,
        Position(
            game.tileSize / 2, game.screenSize.height - 3 / 2 * game.tileSize));
  }

  void update(double t) {}

  void increment() {
    intScore++;
    textScore = "Punkte: " + intScore.toString();
  }
}

Timer timer;

class MyTimer {
  int time;
  bool isFinished = false;
  final MyGame game;
  TextConfig config;

  MyTimer(this.game, this.time) {
    config = TextConfig(
        fontSize: game.tileSize * 4,
        fontFamily: 'Roboto',
        textAlign: TextAlign.center,
        color: Color(0x20000000));
  }

  void render(Canvas c) {
    config.render(
        c,
        time.toString(),
        Position(
            game.screenSize.width / 2 -
                game.tileSize * (1.25) * time.toString().length,
            game.screenSize.height / 2 - game.tileSize * 8));
  }

  void addTime(int extra) {
    time += extra;
  }

  void decrement() {
    if (time > 0)
      time--;
    else {
      isFinished = true;
      timer.cancel();
      game.stopGame();
    }
  }

  void start() {
    timer = Timer.periodic(Duration(seconds: 1), (Timer t) => decrement());
  }
}

class StartButton {
  final MyGame game;
  Rect textContainer;
  Sprite startButton = Sprite('start.png');
  bool up;
  bool start = false;
  double left;
  double top;
  double width;
  double height;

  StartButton(this.game) {
    up = true;
    left = 3 / 2 * game.tileSize;
    top = game.screenSize.height / 2 - 5 / 2 * game.tileSize;
    width = 6 * game.tileSize;
    height = 3 * game.tileSize;
    textContainer = Rect.fromLTWH(left, top, width, height);
  }

  void reStart() {
    textContainer = Rect.fromLTWH(left, top, width, height);
    start = false;
  }

  void render(Canvas c) {
    startButton.renderRect(c, textContainer);
  }

  void update(double t) {}

  void onTapDown() {
    up = false;
  }

  void onTapUp() {
    up = true;
    if (game.bluetoothManager.connected) {
      if (!game.player.setUp) {
        if (!game.player.calibrationPhase) {
          game.player.calibrationPhase = true;
          game.timer.start();
        }
      } else {
        start = true;
        Timer(Duration(milliseconds: 500), () async {
          game.startGame();
          textContainer = Rect.fromLTWH(0, 0, 0, 0);
        });
      }
    }
  }
}

class Target {
  final MyGame game;
  Rect targetRect;
  Sprite box = Sprite('star.png');
  double i = 0;
  int counter = 0;

  Target(this.game, double x, double y) {
    targetRect = Rect.fromLTWH(x, y, 2 * game.tileSize, 2 * game.tileSize);
  }

  void render(Canvas c) {
    box.renderRect(c, targetRect);
  }

  void update(double t) {
    counter++;
    if(counter % 3 == 0) {
      i += 0.05;
    }
      targetRect = Rect.fromLTWH(targetRect.left,
          targetRect.top + (t * (1 + i)), 2 * game.tileSize, 2 * game.tileSize);
      if (targetRect.top > game.screenSize.height) {
        game.stopGame();
      }
  }
}
