import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'models/event.dart';
import 'models/quest_item.dart';
import 'models/real_world_state.dart';
import 'services/event_service.dart';
import 'services/quest_item_service.dart';
import 'widgets/map_page.dart';
import 'widgets/quest_ui.dart';

const _supabaseUrl = 'https://wxlvhpmolrtcwryaazfb.supabase.co';
const _supabasePublishableKey =
    'sb_publishable_F5e3RPpeUzlQG31-yv4FeA_fExmYk3w';

/// Developer-only entry point for creating official SNS/store media.
///
/// Run only with:
/// flutter run --debug -t lib/main_media_studio.dart
///
/// The production entry point (lib/main.dart) never imports this file.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kDebugMode) {
    runApp(const _BlockedApp());
    return;
  }

  await supabase.Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );

  runApp(const _MediaStudioApp());
}

class _BlockedApp extends StatelessWidget {
  const _BlockedApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Media Studio is available only in Debug builds.'),
          ),
        ),
      );
}

class _MediaStudioApp extends StatelessWidget {
  const _MediaStudioApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '聖地クエスト Media Studio',
        debugShowCheckedModeBanner: false,
        theme: questTheme(),
        home: const _MediaStudioPage(),
      );
}

enum _CapturePhase { map, stamp }

class _MediaStudioPage extends StatefulWidget {
  const _MediaStudioPage();

  @override
  State<_MediaStudioPage> createState() => _MediaStudioPageState();
}

class _MediaStudioPageState extends State<_MediaStudioPage>
    with TickerProviderStateMixin {
  static const _captureChannel =
      MethodChannel('jp.seichiquest.app/media_studio_capture');

  final EventService _eventService = EventService();
  final QuestItemService _questItemService = QuestItemService();

  late final AnimationController _sonarController;

  List<Event> _events = const [];
  List<QuestItem> _items = const [];
  Event? _event;
  QuestItem? _item;
  GoogleMapController? _mapController;

  bool _loading = true;
  bool _generating = false;
  _CapturePhase _phase = _CapturePhase.map;
  int _completed = 0;
  String _status = '準備中…';

  @override
  void initState() {
    super.initState();
    _sonarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    unawaited(_load());
  }

  @override
  void dispose() {
    _sonarController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final selection = await _eventService.loadCurrentEvent();
      final event = selection.currentEvent;
      final items = await _questItemService.loadActiveItems(event.id);
      if (!mounted) return;
      setState(() {
        _events = selection.events;
        _event = event;
        _items = items;
        _item = items.firstOrNull;
        _loading = false;
        _status = '${items.length}スポットを読み込みました';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = '読み込み失敗: $error';
      });
    }
  }

  Future<void> _selectEvent(Event event) async {
    if (_generating) return;
    setState(() {
      _event = event;
      _loading = true;
      _status = '${event.name}を読み込み中…';
    });
    try {
      final items = await _questItemService.loadActiveItems(event.id);
      if (!mounted) return;
      setState(() {
        _items = items;
        _item = items.firstOrNull;
        _loading = false;
        _completed = 0;
        _status = '${items.length}スポットを読み込みました';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = '読み込み失敗: $error';
      });
    }
  }

  String _safeName(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return normalized.isEmpty ? 'spot' : normalized;
  }

  Future<void> _capture(String name) async {
    await _captureChannel.invokeMethod<void>('capturePng', {'name': name});
  }

  Future<void> _focus(QuestItem item) async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(item.latitude, item.longitude),
          zoom: 15.8,
        ),
      ),
    );
  }

  Future<void> _generateAll() async {
    if (_generating || _items.isEmpty || _event == null) return;

    setState(() {
      _generating = true;
      _completed = 0;
      _phase = _CapturePhase.map;
    });

    try {
      for (var index = 0; index < _items.length; index++) {
        if (!mounted) return;
        final item = _items[index];
        setState(() {
          _item = item;
          _phase = _CapturePhase.map;
          _status = '${index + 1} / ${_items.length}  ${item.name}  MAP生成中';
        });

        await WidgetsBinding.instance.endOfFrame;
        await _focus(item);

        // Google Maps is a native platform view. Give tiles/labels time to
        // settle before PixelCopy captures the real Android window.
        await Future<void>.delayed(const Duration(milliseconds: 1800));

        final prefix =
            '${(index + 1).toString().padLeft(2, '0')}_${_safeName(item.name)}';
        await _capture('${prefix}_map.png');

        if (!mounted) return;
        setState(() {
          _phase = _CapturePhase.stamp;
          _status =
              '${index + 1} / ${_items.length}  ${item.name}  STAMP GET生成中';
        });
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await _capture('${prefix}_stamp_get_SAMPLE.png');

        if (!mounted) return;
        setState(() => _completed = index + 1);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      if (!mounted) return;
      setState(() {
        _phase = _CapturePhase.map;
        _status = '完了: $_completed / ${_items.length} スポット';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '生成を停止しました: $error');
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  Set<Marker> _markersFor(QuestItem item) => {
        Marker(
          markerId: MarkerId(item.id),
          position: LatLng(item.latitude, item.longitude),
          infoWindow: InfoWindow(title: item.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
          zIndexInt: 20,
        ),
      };

  Set<Circle> _circlesFor(QuestItem item) => {
        Circle(
          circleId: CircleId('capture_range_${item.id}'),
          center: LatLng(item.latitude, item.longitude),
          radius: item.stampRadiusMeters.toDouble(),
          strokeWidth: 2,
          strokeColor: const Color(0xFF5968E8),
          fillColor: const Color(0x225968E8),
        ),
      };

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final event = _event;

    if (_loading || item == null || event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Media Studio')),
        body: Center(child: Text(_status)),
      );
    }

    final fakeDistance = _phase == _CapturePhase.stamp
        ? 0.0
        : (item.stampRadiusMeters * 2.4).clamp(320.0, 850.0).toDouble();

    return Scaffold(
      body: Stack(
        children: [
          MapPage(
            mapController: _mapController,
            currentPosition: null,
            realWorldState: RealWorldState.fromLocalTime(
              DateTime(2026, 9, 28, 14),
              weather: WeatherCondition.clear,
              temperatureCelsius: 24,
            ),
            weatherUnavailable: false,
            nextSeichi: item,
            nextDistance: fakeDistance,
            collectedIds: const <String>{},
            isLoadingLocation: false,
            errorMessage: null,
            errorActionLabel: null,
            onErrorAction: null,
            sonarController: _sonarController,
            justCollected: _phase == _CapturePhase.stamp,
            collectedName: item.name,
            collectedCount: _phase == _CapturePhase.stamp ? 1 : 0,
            total: _items.length,
            defaultCenter: LatLng(item.latitude, item.longitude),
            markers: _markersFor(item),
            destinationRangeCircles: _circlesFor(item),
            onCameraMove: (_) {},
            onCameraIdle: () {},
            onMoveToCurrentLocation: () {},
            onToggleHeadingUp: () {},
            onMoveToNextSeichi: () => unawaited(_focus(item)),
            onStartNavigation: () {},
            onMapCreated: (controller) {
              _mapController = controller;
              unawaited(_focus(item));
            },
            onDismissError: () {},
          ),

          // Never put fake acquisition material into circulation without an
          // unmistakable mark. Normal map captures intentionally have no mark.
          if (_phase == _CapturePhase.stamp)
            const Positioned.fill(child: _SampleWatermark()),

          // Controls are hidden automatically while PixelCopy is taking a
          // capture, because native capture receives the exclusion rect.
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: _StudioControls(
                event: event,
                events: _events,
                itemCount: _items.length,
                completed: _completed,
                status: _status,
                generating: _generating,
                onEventChanged: _selectEvent,
                onGenerate: _generateAll,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleWatermark extends StatelessWidget {
  const _SampleWatermark();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Center(
          child: Transform.rotate(
            angle: -0.28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.78),
                  width: 2,
                ),
              ),
              child: Text(
                'SAMPLE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 7,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _StudioControls extends StatelessWidget {
  const _StudioControls({
    required this.event,
    required this.events,
    required this.itemCount,
    required this.completed,
    required this.status,
    required this.generating,
    required this.onEventChanged,
    required this.onGenerate,
  });

  final Event event;
  final List<Event> events;
  final int itemCount;
  final int completed;
  final String status;
  final bool generating;
  final ValueChanged<Event> onEventChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xF2FFFFFF),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.movie_creation_outlined),
                  const SizedBox(width: 8),
                  const Text(
                    'MEDIA STUDIO',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  DropdownButton<Event>(
                    value: event,
                    underline: const SizedBox.shrink(),
                    items: events
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: generating
                        ? null
                        : (value) {
                            if (value != null) onEventChanged(value);
                          },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: itemCount == 0 ? 0 : completed / itemCount,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: generating ? null : onGenerate,
                    icon: generating
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library_outlined),
                    label: Text(
                      generating ? '生成中' : '全$itemCountスポット一括生成',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
