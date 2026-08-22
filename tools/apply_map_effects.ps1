$ErrorActionPreference = 'Stop'

Set-Location 'C:\src\seichi_quest'

$branch = (git branch --show-current).Trim()
if ($branch -ne 'refactor/modularize') {
    throw "Wrong branch: $branch"
}

if (git status --porcelain) {
    throw 'Working tree is not clean.'
}

git pull --ff-only origin refactor/modularize

$path = 'lib\main.dart'
$text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)

function Replace-RegexOnce([string]$source, [string]$pattern, [string]$replacement, [string]$name) {
    $matches = [regex]::Matches($source, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($matches.Count -ne 1) {
        throw "Regex target '$name' found $($matches.Count) times. Aborting safely."
    }
    return [regex]::Replace($source, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement }, 1, [System.Text.RegularExpressions.RegexOptions]::Singleline)
}

if ($text -notmatch "import 'dart:ui' as ui;") {
    $text = Replace-RegexOnce $text "import 'dart:math' as math;\r?\n" "import 'dart:math' as math;`r`nimport 'dart:ui' as ui;`r`n" 'ui import'
}

if ($text -notmatch '_markerIconDefault') {
    $text = Replace-RegexOnce $text "  late AnimationController _sonarController;\r?\n" @'
  late AnimationController _sonarController;

  BitmapDescriptor? _markerIconDefault;
  BitmapDescriptor? _markerIconCollected;
  BitmapDescriptor? _markerIconNext;
'@ 'marker icon fields'
}

if ($text -notmatch '_prepareMarkerIcons\(\)') {
    $text = Replace-RegexOnce $text "  Future<void> _initialize\(\) async \{.*?\r?\n  \}" @'
  Future<void> _initialize() async {
    await _loadSavedStamps();
    await _loadSeichi();
    await _prepareMarkerIcons();
    await _initializeLocation();
  }
'@ 'initialize marker icons'
}

if ($text -notmatch 'Future<BitmapDescriptor> _createCuteMarkerIcon') {
    $markerPattern = "  Set<Marker> _buildMarkers\(\) \{.*?\r?\n  \}\r?\n\r?\n  // ============================================================\r?\n  // 聖地詳細"
    $markerReplacement = @'
  Future<BitmapDescriptor> _createCuteMarkerIcon({
    required Color color,
    required IconData icon,
  }) async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(size / 2, 38);

    final shadowPaint = Paint()..color = Colors.black.withOpacity(0.16);
    canvas.drawCircle(const Offset(size / 2, 42), 30, shadowPaint);

    final pinPaint = Paint()..color = color;
    final pinPath = Path()
      ..moveTo(size / 2, 82)
      ..cubicTo(42, 68, 27, 55, 27, 39)
      ..cubicTo(27, 21, 41, 8, 48, 8)
      ..cubicTo(55, 8, 69, 21, 69, 39)
      ..cubicTo(69, 55, 54, 68, 48, 82)
      ..close();
    canvas.drawPath(pinPath, pinPaint);

    final innerPaint = Paint()..color = Colors.white.withOpacity(0.95);
    canvas.drawCircle(center, 19, innerPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 23,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _prepareMarkerIcons() async {
    final defaultIcon = await _createCuteMarkerIcon(
      color: const Color(0xFF7C3AED),
      icon: Icons.auto_awesome,
    );
    final collectedIcon = await _createCuteMarkerIcon(
      color: const Color(0xFF16A34A),
      icon: Icons.workspace_premium,
    );
    final nextIcon = await _createCuteMarkerIcon(
      color: const Color(0xFFEC4899),
      icon: Icons.flag_rounded,
    );

    if (!mounted) return;

    setState(() {
      _markerIconDefault = defaultIcon;
      _markerIconCollected = collectedIcon;
      _markerIconNext = nextIcon;
    });
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    for (final seichi in _seichiList) {
      final collected = _collectedIds.contains(seichi.id);
      final isNext = _nextSeichi?.id == seichi.id;

      final markerIcon = isNext
          ? _markerIconNext
          : collected
              ? _markerIconCollected
              : _markerIconDefault;

      markers.add(
        Marker(
          markerId: MarkerId(seichi.id),
          position: LatLng(seichi.latitude, seichi.longitude),
          anchor: const Offset(0.5, 0.92),
          icon: markerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                isNext
                    ? BitmapDescriptor.hueRose
                    : collected
                        ? BitmapDescriptor.hueGreen
                        : BitmapDescriptor.hueViolet,
              ),
          infoWindow: InfoWindow(
            title: isNext
                ? '次の目的地: ${seichi.card} ${seichi.name}'
                : '${seichi.icon} ${seichi.card} ${seichi.name}',
            snippet: collected
                ? 'スタンプ獲得済み'
                : '${seichi.reading} ・ 到達半径 ${seichi.stampRadiusMeters}m',
          ),
          onTap: () => _showSeichiDetails(seichi),
        ),
      );
    }

    return markers;
  }

  Set<Circle> _buildMapCircles() {
    final seichi = _nextSeichi;
    if (seichi == null) return const <Circle>{};

    final intensity = _sonarIntensity();
    final progress = _sonarController.value;
    final baseRadius = seichi.stampRadiusMeters.toDouble();
    final rippleRadius = baseRadius * (0.35 + progress * 0.85);

    return {
      Circle(
        circleId: const CircleId('next-arrival-zone'),
        center: LatLng(seichi.latitude, seichi.longitude),
        radius: baseRadius,
        fillColor: Colors.deepPurple.withOpacity(0.035 + intensity * 0.045),
        strokeColor: Colors.deepPurple.withOpacity(0.18 + intensity * 0.30),
        strokeWidth: 2,
      ),
      Circle(
        circleId: const CircleId('next-sonar-ripple'),
        center: LatLng(seichi.latitude, seichi.longitude),
        radius: rippleRadius,
        fillColor: Colors.transparent,
        strokeColor: Colors.deepPurple.withOpacity(
          (1.0 - progress) * (0.20 + intensity * 0.55),
        ),
        strokeWidth: 4,
      ),
      Circle(
        circleId: const CircleId('next-sonar-core'),
        center: LatLng(seichi.latitude, seichi.longitude),
        radius: math.max(8.0, baseRadius * 0.12),
        fillColor: Colors.deepPurple.withOpacity(0.08 + intensity * 0.16),
        strokeColor: Colors.deepPurple.withOpacity(0.25 + intensity * 0.35),
        strokeWidth: 2,
      ),
    };
  }

  // ============================================================
  // 聖地詳細
'@
    $text = Replace-RegexOnce $text $markerPattern $markerReplacement 'marker implementation'
}

$mapPattern = "  Widget _buildMap\(\) \{.*?\r?\n  \}\r?\n\r?\n  // ============================================================\r?\n  // マップ画面"
$mapReplacement = @'
  Widget _buildMap() {
    LatLng initialTarget = _defaultCenter;

    if (_currentPosition != null) {
      initialTarget = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }

    return AnimatedBuilder(
      animation: _sonarController,
      builder: (context, child) {
        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: 10.5,
          ),
          mapType: MapType.normal,
          myLocationEnabled: _currentPosition != null,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          markers: _buildMarkers(),
          circles: _buildMapCircles(),
          onMapCreated: (controller) {
            _mapController = controller;

            if (_currentPosition != null) {
              _moveCameraToCurrentLocation();
            }
          },
          onTap: (_) {},
        );
      },
    );
  }

  // ============================================================
  // マップ画面
'@
$text = Replace-RegexOnce $text $mapPattern $mapReplacement 'Google Maps animation'

[System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))

flutter format lib\main.dart
if ($LASTEXITCODE -ne 0) { throw 'flutter format failed.' }

flutter test
if ($LASTEXITCODE -ne 0) { throw 'flutter test failed. Nothing was committed.' }

git add lib\main.dart
git commit -m "Add map sonar ripple and cute seichi markers"
git push origin refactor/modularize

Write-Host 'Map effects applied and pushed.' -ForegroundColor Green
