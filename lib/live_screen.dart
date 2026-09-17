import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  static const String _tokenServerId = 'notebook-1rvi4h';

  Room? _room;
  LocalVideoTrack? _videoTrack;
  LocalAudioTrack? _audioTrack;

  bool _cameraEnabled = false;
  bool _microphoneEnabled = false;
  bool _loading = true;
  bool _connected = false;

  String _status = 'Connecting to NoteBook Live...';

  @override
  void initState() {
    super.initState();
    _startLive();
  }

  Future<void> _startLive() async {
    try {
      setState(() {
        _loading = true;
        _status = 'Getting LiveKit token...';
      });

      final tokenSource = DevelopmentTokenSource(id: _tokenServerId);

      final tokenResponse = await tokenSource.fetch(
        const TokenRequestOptions(
          roomName: 'notebook-live-room',
          participantName: 'NoteBook User',
        ),
      );

      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );

      _room = room;

      setState(() {
        _status = 'Connecting to LiveKit room...';
      });

      await room.connect(
        tokenResponse.serverUrl,
        tokenResponse.participantToken,
      );

      if (!mounted) return;

      setState(() {
        _connected = true;
        _status = 'Connected to NoteBook Live';
      });

      await _startCameraAndMicrophone();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _connected = false;
        _status = 'Live connection failed';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('LiveKit connection error: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _startCameraAndMicrophone() async {
    try {
      setState(() {
        _status = 'Starting camera and microphone...';
      });

      final videoTrack = await LocalVideoTrack.createCameraTrack();
      final audioTrack = await LocalAudioTrack.create();

      _videoTrack = videoTrack;
      _audioTrack = audioTrack;

      final localParticipant = _room!.localParticipant!;

      await localParticipant.publishVideoTrack(videoTrack);

      await localParticipant.publishAudioTrack(audioTrack);

      if (!mounted) return;

      setState(() {
        _cameraEnabled = true;
        _microphoneEnabled = true;
        _loading = false;
        _status = 'You are live';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _status = 'Camera or microphone failed';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Camera/microphone error: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _toggleCamera() async {
    final track = _videoTrack;

    if (track == null) return;

    try {
      if (_cameraEnabled) {
        await track.mute();
      } else {
        await track.unmute();
      }

      if (!mounted) return;

      setState(() {
        _cameraEnabled = !_cameraEnabled;
        _status = _cameraEnabled ? 'You are live' : 'Camera is off';
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Camera error: $e')));
    }
  }

  Future<void> _toggleMicrophone() async {
    final track = _audioTrack;

    if (track == null) return;

    try {
      if (_microphoneEnabled) {
        await track.mute();
      } else {
        await track.unmute();
      }

      if (!mounted) return;

      setState(() {
        _microphoneEnabled = !_microphoneEnabled;
        _status = _microphoneEnabled ? 'You are live' : 'Microphone is off';
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Microphone error: $e')));
    }
  }

  Future<void> _endLive() async {
    try {
      await _videoTrack?.dispose();
      await _audioTrack?.dispose();

      _videoTrack = null;
      _audioTrack = null;

      await _room?.disconnect();
      await _room?.dispose();

      _room = null;
    } catch (_) {}

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _videoTrack?.dispose();
    _audioTrack?.dispose();
    _room?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'NoteBook Live',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: Stack(
        children: [
          Positioned.fill(
            child: _videoTrack != null && _cameraEnabled
                ? VideoTrackRenderer(_videoTrack!, fit: VideoViewFit.cover)
                : Container(
                    color: Colors.black,
                    child: Center(
                      child: Icon(
                        Icons.videocam_off_outlined,
                        size: 90,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
          ),

          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          Positioned(
            left: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _connected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _status,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.20),
                    child: IconButton(
                      onPressed: _toggleCamera,
                      icon: Icon(
                        _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                  ),

                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.20),
                    child: IconButton(
                      onPressed: _toggleMicrophone,
                      icon: Icon(
                        _microphoneEnabled ? Icons.mic : Icons.mic_off,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                  ),

                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: _endLive,
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
