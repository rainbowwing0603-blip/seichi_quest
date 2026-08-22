$ErrorActionPreference = 'Stop'

Set-Location 'C:\src\seichi_quest'

$branch = (git branch --show-current).Trim()
if ($branch -ne 'refactor/modularize') {
    throw "現在のブランチは '$branch' です。refactor/modularize で実行してください。"
}

$status = git status --porcelain
if ($status) {
    throw '作業ツリーに未コミット変更があります。先に保存してください。'
}

git pull --ff-only origin refactor/modularize

$path = 'lib\main.dart'
$text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)

function Replace-Once([string]$source, [string]$old, [string]$new, [string]$name) {
    $count = ([regex]::Matches($source, [regex]::Escape($old))).Count
    if ($count -ne 1) {
        throw "$name の対象が $count 箇所です。安全のため変更を中止しました。"
    }
    return $source.Replace($old, $new)
}

$text = Replace-Once $text "import 'dart:math' as math;`r`n" "import 'dart:math' as math;`r`nimport 'dart:ui' as ui;`r`n" 'ui import'

$text = Replace-Once $text @'
  late AnimationController _sonarController;
'@ @'
  late AnimationController _sonarController;

  BitmapDescriptor? _markerIconDefault;
  BitmapDescriptor? _markerIconCollected;
  BitmapDescriptor? _markerIconNext;
'@ 'marker icon fields'

$text = Replace-Once $text @'
      _updateNextDestination();
    } catch (e) {
'@ @'
      await _prepareMarkerIcons();
      _updateNextDestination();
    } catch (e) {
'@ 'marker icon preparation'

$oldMarker = @'
  // ============================================================
  // マーカー
  // ============================================================

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    for (final seichi in _seichiList) {
      final collected =
          _collectedIds.contains(seichi.id);

      markers.add(
        Marker(
          markerId: MarkerId(seichi.id),
          position: LatLng(
            seichi.latitude,
            seichi.longitude,
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(
            collected
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueViolet,
          ),
          infoWindow: InfoWindow(
            title:
                '${seichi.icon} ${seichi.card} ${seichi.name}',
            snippet: collected
                ? '🏆 スタンプ獲得済み'
                : '${seichi.reading} ・ '
                    '到達半径 ${seichi.stampRadiusMeters}m',
          ),
          onTap: () {
            _showSeichiDetails(seichi);
          },
        ),
      );
    }

    return markers;
  }
'@

$newMarker = @'
  // ============================================================
  // かわいいマーカー + 地図ソナー
  // ============================================================

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

    return BitmapDescriptor.fromBytes(
      bytes!.buffer.asUint8List(),
    );
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

    if (!mounted) {
      return;
    }

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
                ? '🎯 ${seichi.card} ${seichi.name}'
                : '${seichi.icon} ${seichi.card} ${seichi.name}',
            snippet: collected
                ? '🏆 スタンプ獲得済み'
                : '${seichi.reading} ・ 到達半径 ${seichi.stampRadiusMeters}m',
          ),
          onTap: () {
            _showSeichiDetails(seichi);
          },
        ),
      );
    }

    return markers;
  }

  Set<Circle> _buildMapCircles() {
    final seichi = _nextSeichi;
    if (seichi == null) {
      return const <Circle>{};
    }

    final intensity = _sonarIntensity();
    final progress = _sonarController.value;
    final baseRadius = seichi.stampRadiusMeters.toDouble();
    final rippleRadius = baseRadius * (0.35 + progress * 0.85);

    return {
      Circle(
        circleId: const CircleId('next-arrival-zone'),
        center: LatLng(seichi.latitude, seichi.longitude),
        radius: baseRadius,
        fillColor: Colors.deepPurple.withOpacity(
          0.035 + intensity * 0.045,
        ),
        strokeColor: Colors.deepPurple.withOpacity(
          0.18 + intensity * 0.30,
        ),
        strokeWidth: 2,
        zIndex: 1,
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
        zIndex: 2,
      ),
      Circle(
        circleId: const CircleId('next-sonar-core'),
        center: LatLng(seichi.latitude, seichi.longitude),
        radius: math.max(8.0, baseRadius * 0.12),
        fillColor: Colors.deepPurple.withOpacity(
          0.08 + intensity * 0.16,
        ),
        strokeColor: Colors.deepPurple.withOpacity(
          0.25 + intensity * 0.35,
        ),
        strokeWidth: 2,
        zIndex: 3,
      ),
    };
  }
'@
$text = Replace-Once $text $oldMarker $newMarker 'marker implementation'

$oldMap = @'
      mapToolbarEnabled: false,
      markers: _buildMarkers(),
      onMapCreated:
          (controller) {
        _mapController = controller;

        if (_currentPosition != null) {
          _moveCameraToCurrentLocation();
        }
      },
      onTap: (_) {},
    );
'@
$newMap = @'
      mapToolbarEnabled: false,
      markers: _buildMarkers(),
      circles: _buildMapCircles(),
      onMapCreated:
          (controller) {
        _mapController = controller;

        if (_currentPosition != null) {
          _moveCameraToCurrentLocation();
        }
      },
      onTap: (_) {},
    );
'@
$text = Replace-Once $text $oldMap $newMap 'Google Maps circles'

$oldPage = @'
  Widget _buildMapPage() {
    return Stack(
      children: [
        _buildMap(),
        _buildNextDestinationCard(),
'@
$newPage = @'
  Widget _buildMapPage() {
    return AnimatedBuilder(
      animation: _sonarController,
      builder: (context, child) {
        return Stack(
          children: [
            _buildMap(),
            _buildNextDestinationCard(),
'@
$text = Replace-Once $text $oldPage $newPage 'map animation wrapper'

$oldEnd = @'
        _buildStampAnimation(),
      ],
    );
  }
'@
$newEnd = @'
            _buildStampAnimation(),
          ],
        );
      },
    );
  }
'@
$text = Replace-Once $text $oldEnd $newEnd 'map animation wrapper end'

[System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false))

flutter format lib\main.dart | Out-Host
flutter test
if ($LASTEXITCODE -ne 0) {
    throw 'flutter test に失敗したため、コミットしていません。'
}

git add lib\main.dart tools\apply_map_effects.ps1
git commit -m "Add map sonar ripple and cute seichi markers"
git push origin refactor/modularize

Write-Host ''
Write-Host '実装・テスト・GitHubへの保存まで完了しました。' -ForegroundColor Green
