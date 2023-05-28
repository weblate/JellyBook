// The purpose of this file is to allow the user to listen to the audiobook they have downloaded

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:isar_flutter_libs/isar_flutter_libs.dart';
import 'package:jellybook/models/entry.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:jellybook/variables.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fancy_shimmer_image/fancy_shimmer_image.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

// audiobook reader
class AudioBookReader extends StatefulWidget {
  final String title;
  final String audioBookId;

  const AudioBookReader({
    Key? key,
    required this.title,
    required this.audioBookId,
  }) : super(key: key);

  @override
  _AudioBookReaderState createState() => _AudioBookReaderState();
}

class _AudioBookReaderState extends State<AudioBookReader> {
  late AudioPlayer audioPlayer;
  Timer? timer;
  String audioPath = '';
  Duration duration = Duration();
  Duration position = Duration();
  bool isPlaying = false;
  double playbackProgress = 0.0;
  String imageUrl = '';

  @override
  void initState() {
    super.initState();
    audioPlayer = AudioPlayer();
    // timer every 10 seconds to update the progress
    timer = Timer.periodic(
        const Duration(seconds: 10), (Timer t) => savePosition());

    audioPlayer.onPlayerStateChanged.listen((playerState) {
      if (playerState == PlayerState.playing) {
        isPlaying = true;
      } else {
        isPlaying = false;
      }
    });
    audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        playbackProgress = 0.0;
      });
    });
    audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        playbackProgress = position.inMilliseconds.toDouble();
      });
    });
  }

  Future<void> savePosition() async {
    Isar? isar = Isar.getInstance();
    if (isar != null) {
      var entry = await isar.entrys
          .where()
          .filter()
          .idEqualTo(widget.audioBookId)
          .findFirst();
      if (entry != null) {
        await isar.writeTxn(() async {
          entry.pageNum = position.inMilliseconds;
          isar.entrys.put(entry);
        });
        logger.d('saved position: ${entry.pageNum}');
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    audioPlayer.stop();
    audioPlayer.release();
    audioPlayer.dispose();
    timer?.cancel();
  }

  Future<void> playAudio(String audioPath) async {
    logger.d('audioPath: $audioPath');
    await audioPlayer.play(DeviceFileSource(audioPath));
    await audioPlayer.seek(position);
    FlutterBackgroundService().invoke("setAsForeground");
    setState(() {
      isPlaying = true;
    });
  }

  Future<void> pauseAudio() async {
    await savePosition();
    await audioPlayer.pause();
    FlutterBackgroundService().invoke("setAsBackground");
    setState(() {
      isPlaying = false;
    });
  }

  Future<void> stopAudio() async {
    await savePosition();
    await audioPlayer.stop();
    FlutterBackgroundService().invoke("setAsBackground");
    setState(() {
      isPlaying = false;
      playbackProgress = 0.0;
    });
  }

  Future<String> getAudioPath() async {
    Isar? isar = Isar.getInstance();
    if (isar != null) {
      var entry = await isar.entrys
          .where()
          .filter()
          .idEqualTo(widget.audioBookId)
          .findFirst();
      if (entry != null) {
        // find the duration
        duration = await audioPlayer.getDuration() ?? Duration();
        audioPath = entry.filePath;
        position = Duration(milliseconds: entry.pageNum);
        imageUrl = entry.imagePath;
        return entry.filePath;
      }
    }
    return '';
  }

  // Future<void> playAudio(String audioPath) async {
  //   logger.d('audioPath: $audioPath');
  //   await audioPlayer.play(DeviceFileSource(audioPath));
  //   await audioPlayer.seek(position);
  //   setState(() {
  //     isPlaying = true;
  //   });
  // }
  //
  // Future<void> pauseAudio() async {
  //   await savePosition();
  //   await audioPlayer.pause();
  //   setState(() {
  //     isPlaying = false;
  //   });
  // }
  //
  // Future<void> stopAudio() async {
  //   await savePosition();
  //   await audioPlayer.stop();
  //   setState(() {
  //     isPlaying = false;
  //     playbackProgress = 0.0;
  //   });
  // }

  String formatDuration(double milliseconds) {
    Duration duration = Duration(milliseconds: milliseconds.toInt());
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));

    String formattedDuration = "$minutes:$seconds";
    if (duration.inHours > 0) {
      formattedDuration = "$hours:$formattedDuration";
    }

    return formattedDuration;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        // back arrow
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: FutureBuilder(
          future: getAudioPath(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return audioPlayerWidget(snapshot.data.toString());
            } else {
              return const CircularProgressIndicator();
            }
          },
        ),
      ),
    );
  }

  Widget audioPlayerWidget(String audioPath) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // a image of the book (as a square)
        // Expanded(
        // flex: 2,
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          width: MediaQuery.of(context).size.width * 0.8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(2, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: imageUrl.isNotEmpty && imageUrl != "Asset"
                    ? FancyShimmerImage(
                        imageUrl: imageUrl,
                        boxFit: BoxFit.cover,
                        errorWidget: Image.asset(
                          "assets/images/NoCoverArt.png",
                          width: MediaQuery.of(context).size.width / 4 * 0.8,
                          fit: BoxFit.cover,
                        ),
                        width: MediaQuery.of(context).size.width / 4 * 0.8,
                      )
                    : Image.asset(
                        'assets/images/NoCoverArt.png',
                        width: MediaQuery.of(context).size.width / 4 * 0.8,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
        ),
        // spacer
        const SizedBox(height: 20),
        Slider(
          value: playbackProgress,
          min: 0.0,
          max: duration.inMilliseconds.toDouble(),
          // max: 1.0,
          // max: 100.0,
          // max: audioPlayer.getDuration();
          onChanged: (value) {
            setState(() {
              playbackProgress = value;
            });
            audioPlayer.seek(Duration(milliseconds: value.toInt()));
          },
        ),
        Text(
          "${formatDuration(playbackProgress)} / ${formatDuration(duration.inMilliseconds.toDouble())}",
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: isPlaying ? pauseAudio : () => playAudio(audioPath),
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: stopAudio,
            ),
          ],
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
      ],
    );
  }
}
