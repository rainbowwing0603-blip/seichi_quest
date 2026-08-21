import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

const supabaseUrl = 'https://wxlvhpmolrtcwryaazfb.supabase.co';
const supabasePublishableKey = 'sb_publishable_F5e3RPpeUzlQG31-yv4FeA_fExmYk3w';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await supabase.Supabase.initialize(url: supabaseUrl, anonKey: supabasePublishableKey);
  runApp(const SeichiQuestApp());
}

class Seichi {
  final String id;
  final String card;
  final String reading;
  final String name;
  final double latitude;
  final double longitude;
  final int stampRadiusMeters;
  final String description;
  final String icon;

  const Seichi({
    required this.id,
    required this.card,
    required this.reading,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.stampRadiusMeters,
    required this.description,
    required this.icon,
  });

  factory Seichi.fromMap(Map<String, dynamic> map) {
    return Seichi(
      id: map['id']?.toString() ?? '',
      card: map['card']?.toString() ?? '',
      reading: map['reading']?.toString() ?? '',
      name: map['name']?.toString() ?? '名称未設定',
      latitude: _doubleValue(map['latitude']),
      longitude: _doubleValue(map['longitude']),
      stampRadiusMeters: _intValue(map['stamp_radius_meters'], 200),
      description: map['description']?.toString() ?? '',
      icon: map['icon']?.toString() ?? '📍',
    );
  }

  static double _doubleValue(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
  static int _intValue(dynamic value, int fallback) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? fallback;
}

class SeichiQuestApp extends StatelessWidget {
  const SeichiQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '聖地クエスト',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A35C8)),
        scaffoldBackgroundColor: const Color(0xFFF7F5FB),
      ),
      home: const SeichiMapPage(),
    );
  }
}

class SeichiMapPage extends StatefulWidget {
  const SeichiMapPage({super.key});
  @override
  State<SeichiMapPage> createState() => _SeichiMapPageState();
}

class _SeichiMapPageState extends State<SeichiMapPage> with SingleTickerProviderStateMixin {
  static const List<String> _cards = [
    'い','ろ','は','に','ほ','へ','と','ち','り','ぬ','る','を',
    'わ','か','よ','た','れ','そ','つ','ね','な','ら','む','う',
    'の','お','く','や','ま','け','ふ','こ','え','て','あ','さ',
    'き','ゆ','め','み','ひ','も','せ','す',
  ];

  static const LatLng _defaultCenter = LatLng(36.3910, 139.0600);
  static const String _nextDestinationKey = 'next_destination_id';

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  SharedPreferences? _preferences;
  final Set<String> _collectedIds = <String>{};
  List<Seichi> _seichiList = <Seichi>[];
  bool _loading = true;
  bool _loadingLocation = false;
  String? _errorMessage;
  String? _manualNextId;
  Seichi? _nextSeichi;
  double? _nextDistance;
  bool _stampAnimation = false;
  String _collectedName = '';
  int _selectedTab = 0;
  int _collectionFilter = 0;
  late final AnimationController _sonarController;

  int _order(String card) {
    final index = _cards.indexOf(card.trim());
    return index < 0 ? 999 : index;
  }

  @override
  void initState() {
    super.initState();
    _sonarController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadStamps();
    await _loadSeichi();
    await _initializeLocation();
  }

  Future<void> _loadStamps() async {
    _preferences = await SharedPreferences.getInstance();
    final saved = _preferences!.getStringList('collected_seichi_ids') ?? <String>[];
    _collectedIds..clear()..addAll(saved);
    _manualNextId = _preferences!.getString(_nextDestinationKey);
  }

  Future<void> _saveStamps() async {
    await _preferences?.setStringList('collected_seichi_ids', _collectedIds.toList());
  }

  Future<void> _saveNextDestination() async {
    if (_manualNextId == null) {
      await _preferences?.remove(_nextDestinationKey);
    } else {
      await _preferences?.setString(_nextDestinationKey, _manualNextId!);
    }
  }

  int _collectedCount() {
    final ids = _seichiList.map((e) => e.id).toSet();
    return _collectedIds.where(ids.contains).length;
  }

  String _titleForCount(int count) {
    if (count >= 44) return '群馬マスター';
    if (count >= 30) return '上毛探訪者';
    if (count >= 20) return '聖地ハンター';
    if (count >= 10) return '群馬めぐり人';
    if (count >= 5) return '聖地ビギナー';
    if (count >= 1) return '冒険者';
    return '旅のはじまり';
  }

  List<String> _achievements(int count) {
    final result = <String>[];
    if (count >= 1) result.add('最初の聖地');
    if (count >= 5) result.add('聖地ビギナー');
    if (count >= 10) result.add('コレクター');
    if (count >= 25) result.add('群馬探訪');
    if (count >= 44) result.add('完全制覇');
    return result;
  }

  Future<void> _loadSeichi() async {
    try {
      final data = await supabase.Supabase.instance.client.from('seichi').select('id, card, reading, name, latitude, longitude, stamp_radius_meters, description, icon, is_active').eq('is_active', true);
      final list = List<Map<String, dynamic>>.from(data).map(Seichi.fromMap).where((e) => e.id.isNotEmpty && e.latitude != 0 && e.longitude != 0).toList();
      list.sort((a, b) {
        final result = _order(a.card).compareTo(_order(b.card));
        return result == 0 ? a.card.compareTo(b.card) : result;
      });
      if (!mounted) return;
      setState(() { _seichiList = list; _loading = false; });
      _updateNextDestination();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _errorMessage = '聖地データを取得できませんでした。\n$e'; });
    }
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;
    setState(() => _loadingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('位置情報サービスがOFFになっています。');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception('位置情報の利用が許可されていません。');
      if (permission == LocationPermission.deniedForever) throw Exception('端末の設定から位置情報を許可してください。');
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;
      setState(() { _currentPosition = position; _loadingLocation = false; });
      _updateNextDestination();
      await _moveToCurrentLocation();
      _startLocationStream();
      await _checkStampDistance();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingLocation = false; _errorMessage = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  void _startLocationStream() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)).listen((position) {
      if (!mounted) return;
      setState(() => _currentPosition = position);
      _updateNextDestination();
      _checkStampDistance();
    });
  }

  void _updateNextDestination() {
    final position = _currentPosition;
    if (position == null || _seichiList.isEmpty) return;
    Seichi? target;
    if (_manualNextId != null) {
      for (final item in _seichiList) {
        if (item.id == _manualNextId && !_collectedIds.contains(item.id)) { target = item; break; }
      }
      if (target == null) { _manualNextId = null; _saveNextDestination(); }
    }
    if (target == null) {
      double? nearest;
      for (final item in _seichiList) {
        if (_collectedIds.contains(item.id)) continue;
        final distance = Geolocator.distanceBetween(position.latitude, position.longitude, item.latitude, item.longitude);
        if (nearest == null || distance < nearest) { nearest = distance; target = item; }
      }
    }
    double? distance;
    if (target != null) distance = Geolocator.distanceBetween(position.latitude, position.longitude, target.latitude, target.longitude);
    if (!mounted) return;
    setState(() { _nextSeichi = target; _nextDistance = distance; });
  }

  Future<void> _setNextDestination(Seichi seichi) async {
    if (_collectedIds.contains(seichi.id)) return;
    setState(() { _manualNextId = seichi.id; _nextSeichi = seichi; });
    await _saveNextDestination();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${seichi.card} ${seichi.name} を次の目的地に設定しました。')));
  }

  Future<void> _checkStampDistance() async {
    final position = _currentPosition;
    if (position == null || _seichiList.isEmpty) return;
    for (final item in _seichiList) {
      if (_collectedIds.contains(item.id)) continue;
      final distance = Geolocator.distanceBetween(position.latitude, position.longitude, item.latitude, item.longitude);
      if (distance <= item.stampRadiusMeters) { await _collectStamp(item); break; }
    }
  }

  Future<void> _collectStamp(Seichi seichi) async {
    if (_collectedIds.contains(seichi.id)) return;
    _collectedIds.add(seichi.id);
    if (_manualNextId == seichi.id) { _manualNextId = null; await _saveNextDestination(); }
    await _saveStamps();
    if (!mounted) return;
    setState(() { _stampAnimation = true; _collectedName = seichi.name; });
    _updateNextDestination();
    Future.delayed(const Duration(milliseconds: 2800), () { if (mounted) setState(() => _stampAnimation = false); });
  }

  Future<void> _moveToCurrentLocation() async {
    final position = _currentPosition;
    final controller = _mapController;
    if (position == null || controller == null) return;
    await controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 14)));
  }

  Future<void> _moveToSeichi(Seichi seichi) async {
    if (mounted) setState(() => _selectedTab = 0);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (_mapController == null) return;
    await _mapController!.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(seichi.latitude, seichi.longitude), zoom: 17)));
  }

  Future<void> _moveToNext() async { if (_nextSeichi != null) await _moveToSeichi(_nextSeichi!); }

  Set<Marker> _markers() => _seichiList.map((item) {
    final collected = _collectedIds.contains(item.id);
    return Marker(
      markerId: MarkerId(item.id),
      position: LatLng(item.latitude, item.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(collected ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueViolet),
      infoWindow: InfoWindow(title: '${item.card} ${item.name}', snippet: collected ? '🏆 スタンプ獲得済み' : '到達半径 ${item.stampRadiusMeters}m'),
      onTap: () => _showSeichiDetail(item),
    );
  }).toSet();

  void _showSeichiDetail(Seichi seichi) {
    final collected = _collectedIds.contains(seichi.id);
    showModalBottomSheet<void>(
      context: context, showDragHandle: true, isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [CircleAvatar(radius: 28, child: Text(seichi.icon, style: const TextStyle(fontSize: 25))), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(seichi.card, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)), Text(seichi.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)), if (seichi.reading.isNotEmpty) Text(seichi.reading, style: const TextStyle(color: Colors.grey))])), if (collected) const Icon(Icons.verified, color: Colors.green, size: 30)]),
        const SizedBox(height: 14), Text(seichi.description.isEmpty ? '説明は登録されていません。' : seichi.description, style: const TextStyle(height: 1.5)), const SizedBox(height: 12), Text('到達判定 ${seichi.stampRadiusMeters}m'), const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () async { Navigator.pop(sheetContext); await _moveToSeichi(seichi); }, icon: const Icon(Icons.map), label: const Text('この聖地を地図で見る'))),
        if (!collected) ...[const SizedBox(height: 9), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () { Navigator.pop(sheetContext); _setNextDestination(seichi); }, icon: const Icon(Icons.flag_rounded), label: const Text('次の目的地にする')))],
      ]))),
    );
  }

  String _distance(double? value) { if (value == null) return '---'; if (value < 1000) return '${value.round()}m'; return '${(value / 1000).toStringAsFixed(1)}km'; }
  double _sonarIntensity() { final distance = _nextDistance; if (distance == null) return .15; if (distance <= (_nextSeichi?.stampRadiusMeters ?? 200)) return 1; return (1 - distance / 2000).clamp(.1, 1.0); }

  Widget _mapPage() {
    final target = _nextSeichi;
    return Stack(children: [
      GoogleMap(initialCameraPosition: CameraPosition(target: _currentPosition == null ? _defaultCenter : LatLng(_currentPosition!.latitude, _currentPosition!.longitude), zoom: 10.5), myLocationEnabled: _currentPosition != null, myLocationButtonEnabled: false, compassEnabled: true, zoomControlsEnabled: false, mapToolbarEnabled: false, markers: _markers(), onMapCreated: (controller) { _mapController = controller; if (_currentPosition != null) _moveToCurrentLocation(); }),
      if (target != null) Positioned(top: 14, left: 14, right: 14, child: _nextCard(target)),
      Positioned(top: 145, right: 14, child: _badge()),
      Positioned(right: 14, bottom: 150, child: FloatingActionButton(heroTag: 'location', onPressed: _moveToCurrentLocation, child: _loadingLocation ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location))),
      if (target != null) Positioned(left: 16, right: 16, bottom: 78, child: FilledButton.icon(onPressed: _moveToNext, icon: const Icon(Icons.navigation_rounded), label: Text('次の聖地へ  ${target.card}'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)))),
      if (_errorMessage != null) Positioned(left: 16, right: 16, bottom: 135, child: _errorCard()),
      if (_stampAnimation) _stampOverlay(),
    ]);
  }

  Widget _nextCard(Seichi target) => Material(elevation: 8, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [AnimatedBuilder(animation: _sonarController, builder: (context, _) => SizedBox(width: 50, height: 50, child: CustomPaint(painter: SonarPainter(progress: _sonarController.value, intensity: _sonarIntensity()), child: Center(child: Text(target.icon, style: const TextStyle(fontSize: 23))))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('NEXT DESTINATION', style: TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: Colors.grey)), Text('${target.card}  ${target.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))])), IconButton(onPressed: _moveToNext, icon: const Icon(Icons.navigation_rounded))]), const SizedBox(height: 8), Row(children: [Expanded(child: Text('現在地から ${_distance(_nextDistance)}', style: const TextStyle(fontWeight: FontWeight.w600))), Text('到達 ${target.stampRadiusMeters}m', style: const TextStyle(fontSize: 12, color: Colors.grey))]), const SizedBox(height: 7), LinearProgressIndicator(value: _sonarIntensity(), minHeight: 6)])));

  Widget _badge() => Material(elevation: 5, borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.workspace_premium, size: 19), const SizedBox(width: 6), Text('${_collectedCount()} / 44', style: const TextStyle(fontWeight: FontWeight.bold))])));
  Widget _errorCard() => Material(elevation: 7, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.orange), const SizedBox(width: 9), Expanded(child: Text(_errorMessage!, maxLines: 3, overflow: TextOverflow.ellipsis)), IconButton(onPressed: () => setState(() => _errorMessage = null), icon: const Icon(Icons.close))])));

  Widget _stampOverlay() => Positioned.fill(child: IgnorePointer(child: Center(child: TweenAnimationBuilder<double>(tween: Tween(begin: .75, end: 1), duration: const Duration(milliseconds: 500), builder: (context, scale, child) => Transform.scale(scale: scale, child: child), child: Material(elevation: 16, borderRadius: BorderRadius.circular(28), child: Container(width: 290, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('🏆', style: TextStyle(fontSize: 64)), const Text('聖地到達！', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(_collectedName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), const SizedBox(height: 12), Text('${_collectedCount()} / 44 聖地獲得', style: const TextStyle(color: Colors.grey))]))))));

  Widget _collectionPage() {
    final count = _collectedCount();
    final remaining = math.max(0, 44 - count);
    final progress = count / 44;
    final filtered = _cards.map((card) { for (final item in _seichiList) { if (item.card == card) return item; } return null; }).where((item) { final collected = item != null && _collectedIds.contains(item.id); if (_collectionFilter == 1) return collected; if (_collectionFilter == 2) return !collected; return true; }).toList();
    return SafeArea(child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(18, 14, 18, 18), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF9333EA)]), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.workspace_premium, color: Colors.white, size: 32), SizedBox(width: 12), Expanded(child: Text('スタンプ帳', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold))), Text('44札', style: TextStyle(color: Colors.white70))]), const SizedBox(height: 16), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${(progress * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 40, height: 1, fontWeight: FontWeight.w800)), const SizedBox(width: 10), Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(remaining == 0 ? '完全制覇！' : 'あと $remaining 札', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)))]), const SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 9, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white))) ]),
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: Row(children: [_filter('全札', 0), const SizedBox(width: 8), _filter('獲得済み', 1), const SizedBox(width: 8), _filter('未獲得', 2)])),
      Expanded(child: GridView.builder(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), itemCount: filtered.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .82), itemBuilder: (context, index) { final item = filtered[index]; final card = item?.card ?? _cards.firstWhere((c) => !_seichiList.any((s) => s.card == c && (_collectionFilter == 1 ? !_collectedIds.contains(s.id) : _collectionFilter == 2 ? _collectedIds.contains(s.id) : false)), orElse: () => _cards[index % 44]); final collected = item != null && _collectedIds.contains(item.id); return _stampCard(card, item, collected); }))
    ]));
  }

  Widget _filter(String label, int value) { final selected = _collectionFilter == value; return Expanded(child: InkWell(onTap: () => setState(() => _collectionFilter = value), borderRadius: BorderRadius.circular(14), child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(vertical: 11), decoration: BoxDecoration(color: selected ? Colors.deepPurple : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? Colors.deepPurple : Colors.black12)), child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.grey.shade700))))); }

  Widget _stampCard(String card, Seichi? item, bool collected) => Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(22), onTap: item == null ? null : () => _showStampDetail(item, collected), child: Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: collected ? Colors.green.withOpacity(.35) : Colors.black12), boxShadow: const [BoxShadow(blurRadius: 10, offset: Offset(0, 4), color: Color(0x11000000))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(card, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: collected ? Colors.green.shade700 : Colors.deepPurple)), const Spacer(), if (collected) const Icon(Icons.check_circle, color: Colors.green, size: 21)]), Expanded(child: Center(child: _stampVisual(card, item, collected))), Text(collected ? item!.name : '？？？', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: collected ? Colors.black87 : Colors.grey.shade500)), const SizedBox(height: 4), Text(collected ? item!.reading : '聖地を訪れて獲得', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: collected ? Colors.grey.shade600 : Colors.grey.shade400))]))));

  Widget _stampVisual(String card, Seichi? item, bool collected) {
    if (!collected) return Container(width: 108, height: 108, decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300, width: 2)), child: Stack(alignment: Alignment.center, children: [Text(card, style: TextStyle(fontSize: 68, fontWeight: FontWeight.w900, color: Colors.grey.shade300)), Positioned(right: 14, bottom: 13, child: Container(width: 31, height: 31, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)), child: Icon(Icons.question_mark_rounded, color: Colors.grey.shade500, size: 20)))]));
    return Container(width: 108, height: 108, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFE8F8EA), Color(0xFFD0F0D4)]), border: Border.all(color: Colors.green.withOpacity(.45), width: 3)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(card, style: const TextStyle(fontSize: 35, fontWeight: FontWeight.w900, color: Colors.green)), Text(item!.icon, style: const TextStyle(fontSize: 25)), const Text('STAMP GET', style: TextStyle(fontSize: 7, letterSpacing: 1, color: Colors.green, fontWeight: FontWeight.w800))]));
  }

  void _showStampDetail(Seichi item, bool collected) => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 5, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, children: [_largeStamp(item, collected), const SizedBox(height: 14), Text(item.card, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)), Text(collected ? item.name : '未獲得の聖地', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(collected ? (item.description.isEmpty ? 'この聖地のスタンプを獲得しました。' : item.description) : 'この聖地を訪れて、スタンプを獲得しよう！', textAlign: TextAlign.center), const SizedBox(height: 18), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () async { Navigator.pop(sheetContext); await _moveToSeichi(item); }, icon: const Icon(Icons.map), label: Text(collected ? '獲得した聖地を地図で見る' : 'この聖地を地図で見る'))), if (!collected) ...[const SizedBox(height: 9), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () { Navigator.pop(sheetContext); _setNextDestination(item); }, icon: const Icon(Icons.flag_rounded), label: const Text('次の目的地にする')))] ]))));

  Widget _largeStamp(Seichi item, bool collected) => Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: collected ? const Color(0xFFE6F6E9) : Colors.grey.shade100, border: Border.all(color: collected ? Colors.green : Colors.grey.shade300, width: 4)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(item.card, style: TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: collected ? Colors.green : Colors.grey.shade300)), Text(collected ? item.icon : '?', style: TextStyle(fontSize: 32, color: collected ? null : Colors.grey.shade500)), Text(collected ? 'STAMP GET' : 'LOCKED', style: TextStyle(fontSize: 9, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: collected ? Colors.green : Colors.grey))]));

  Widget _questPage() {
    final next = _nextSeichi; final count = _collectedCount(); final achievements = _achievements(count);
    return SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header('クエスト', '次の聖地を目指そう', Icons.flag), const SizedBox(height: 12),
      if (next != null) Container(width: double.infinity, padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF24123D), Color(0xFF6A35C8)]), borderRadius: BorderRadius.circular(26)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('NEXT QUEST', style: TextStyle(color: Colors.white70, letterSpacing: 2, fontWeight: FontWeight.bold)), const SizedBox(height: 12), Row(children: [Text(next.icon, style: const TextStyle(fontSize: 45)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(next.card, style: const TextStyle(color: Colors.white70)), Text(next.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))]))]), const SizedBox(height: 16), Text('現在地から ${_distance(_nextDistance)}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)), const SizedBox(height: 14), SizedBox(width: double.infinity, child: FilledButton(onPressed: _moveToNext, style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF6A35C8)), child: const Text('目的地を見る'))])) else _simpleCard('🏆', '完全制覇！', 'すべての聖地を獲得しました。'),
      const SizedBox(height: 20), const Text('チャレンジ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
      _mission('最初の聖地', '1つの聖地を獲得', count, 1, Icons.location_on), _mission('コレクター', '10個の聖地を獲得', count, 10, Icons.emoji_events), _mission('群馬探訪', '25個の聖地を獲得', count, 25, Icons.map), _mission('完全制覇', '44個すべてを獲得', count, 44, Icons.workspace_premium),
      if (achievements.isNotEmpty) ...[const SizedBox(height: 10), const Text('獲得した称号', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: achievements.map((a) => Chip(avatar: const Icon(Icons.workspace_premium, size: 17), label: Text(a))).toList())],
    ])));
  }

  Widget _mission(String title, String subtitle, int progress, int total, IconData icon) { final value = (progress / total).clamp(0.0, 1.0).toDouble(); final done = progress >= total; return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Row(children: [Icon(done ? Icons.check : icon, color: done ? Colors.green : Colors.deepPurple), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 7), LinearProgressIndicator(value: value, minHeight: 5)])), const SizedBox(width: 10), Text('$progress/$total', style: const TextStyle(fontWeight: FontWeight.bold))])); }

  Widget _rankingPage() { final count = _collectedCount(); return SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_header('ランキング', '聖地巡礼の記録', Icons.leaderboard), const SizedBox(height: 12), _simpleCard('🏆', '$count / 44', 'あなたの現在の獲得聖地数'), const SizedBox(height: 18), const Text('称号ランク', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 10), _rankRow('🏆', 1, _titleForCount(count), count), const SizedBox(height: 10), const Text('※現在は端末内の進行状況を表示しています。オンラインランキングはユーザー認証・ランキングDB連携後に有効化できます。', style: TextStyle(fontSize: 12, color: Colors.grey))])); }
  Widget _rankRow(String medal, int rank, String name, int count) => Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Row(children: [Text(medal, style: const TextStyle(fontSize: 25)), const SizedBox(width: 12), Text('$rank', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 14), Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))), Text('$count / 44', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))]));

  Widget _myPage() { final count = _collectedCount(); final achievements = _achievements(count); return SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [const SizedBox(height: 14), const CircleAvatar(radius: 47, backgroundColor: Color(0xFF6A35C8), child: Icon(Icons.person, color: Colors.white, size: 48)), const SizedBox(height: 13), const Text('ゲストユーザー', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(_titleForCount(count), style: const TextStyle(color: Colors.grey)), const SizedBox(height: 24), Row(children: [_stat('$count', '獲得聖地', Icons.workspace_premium), const SizedBox(width: 10), _stat('44', '札', Icons.style), const SizedBox(width: 10), _stat('${(count / 44 * 100).round()}%', '制覇率', Icons.percent)]), const SizedBox(height: 20), _simpleCard('🗺️', '聖地クエスト', '現在のスタンプ獲得状態は端末に保存されています。'), if (achievements.isNotEmpty) ...[const SizedBox(height: 20), Align(alignment: Alignment.centerLeft, child: Text('獲得実績 ${achievements.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), const SizedBox(height: 10), ...achievements.map((a) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.workspace_premium, color: Colors.deepPurple), const SizedBox(width: 10), Text(a, style: const TextStyle(fontWeight: FontWeight.w700))])))]]))); }
  Widget _stat(String value, String label, IconData icon) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Column(children: [Icon(icon, size: 21, color: Colors.deepPurple), const SizedBox(height: 5), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))])));
  Widget _header(String title, String subtitle, IconData icon) => Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Colors.deepPurple)), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12))])]);
  Widget _simpleCard(String emoji, String title, String subtitle) => Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)), child: Column(children: [Text(emoji, style: const TextStyle(fontSize: 48)), const SizedBox(height: 8), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 7), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))]));

  Widget _page() { if (_loading) return const Center(child: CircularProgressIndicator()); switch (_selectedTab) { case 1: return _questPage(); case 2: return _collectionPage(); case 3: return _rankingPage(); case 4: return _myPage(); default: return _mapPage(); } }

  @override
  Widget build(BuildContext context) => Scaffold(body: _page(), bottomNavigationBar: NavigationBar(selectedIndex: _selectedTab, onDestinationSelected: (index) => setState(() => _selectedTab = index), destinations: const [NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'マップ'), NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'クエスト'), NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium), label: 'スタンプ'), NavigationDestination(icon: Icon(Icons.leaderboard_outlined), selectedIcon: Icon(Icons.leaderboard), label: 'ランキング'), NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'マイページ')]));

  @override
  void dispose() { _positionSubscription?.cancel(); _sonarController.dispose(); super.dispose(); }
}

class SonarPainter extends CustomPainter {
  final double progress;
  final double intensity;
  const SonarPainter({required this.progress, required this.intensity});
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero); final base = size.shortestSide / 2; final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2;
    for (int i = 0; i < 3; i++) { final phase = (progress + i / 3) % 1.0; paint.color = Colors.deepPurple.withOpacity((1 - phase) * .45 * intensity + .05); canvas.drawCircle(center, base * (.25 + phase * .75), paint); }
    final fill = Paint()..color = Colors.deepPurple.withOpacity(.08 + .10 * intensity); canvas.drawCircle(center, base * .30, fill);
  }
  @override
  bool shouldRepaint(covariant SonarPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.intensity != intensity;
}
