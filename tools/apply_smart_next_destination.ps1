$ErrorActionPreference = 'Stop'

$path = Join-Path (Get-Location) 'lib\main.dart'
if (-not (Test-Path $path)) {
  throw "lib/main.dart が見つかりません。プロジェクトルートで実行してください。"
}

$backup = 'lib\main.dart.before-smart-next-final-20260825'
if (-not (Test-Path $backup)) {
  Copy-Item $path $backup -Force
}

$encoding = New-Object System.Text.UTF8Encoding($false)
$source = [System.IO.File]::ReadAllText($path, $encoding)

$startMarker = '  void _updateNextDestination() {'
$endMarker = '  void _setNextDestination(Seichi seichi) {'
$start = $source.IndexOf($startMarker, [System.StringComparison]::Ordinal)
$end = $source.IndexOf($endMarker, $start, [System.StringComparison]::Ordinal)

if ($start -lt 0 -or $end -lt 0 -or $end -le $start) {
  throw '目的地選択ブロックを特定できませんでした。ファイルは変更していません。'
}

$newBlock = @'
  void _updateNextDestination() {
    final position = _currentPosition;

    if (position == null || _seichiList.isEmpty) {
      return;
    }

    Seichi? target;

    if (_manualNextSeichiId != null) {
      for (final seichi in _seichiList) {
        if (seichi.id == _manualNextSeichiId &&
            !_collectedIds.contains(seichi.id)) {
          target = seichi;
          break;
        }
      }

      if (target == null) {
        _manualNextSeichiId = null;
      }
    }

    if (target == null) {
      Seichi? nearest;
      double? nearestDistance;
      Seichi? inRange;
      double? inRangeDistance;

      for (final seichi in _seichiList) {
        if (_collectedIds.contains(seichi.id)) {
          continue;
        }

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          seichi.latitude,
          seichi.longitude,
        );

        if (nearestDistance == null || distance < nearestDistance) {
          nearest = seichi;
          nearestDistance = distance;
        }

        if (distance <= seichi.stampRadiusMeters &&
            (inRangeDistance == null || distance < inRangeDistance)) {
          inRange = seichi;
          inRangeDistance = distance;
        }
      }

      if (inRange != null) {
        target = inRange;
      } else {
        final current = _nextSeichi;

        if (current != null &&
            !_collectedIds.contains(current.id)) {
          final currentDistance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            current.latitude,
            current.longitude,
          );

          const switchMarginMeters = 150.0;

          if (nearest != null &&
              nearestDistance != null &&
              nearest.id != current.id &&
              nearestDistance + switchMarginMeters < currentDistance) {
            target = nearest;
          } else {
            target = current;
          }
        } else {
          target = nearest;
        }
      }
    }

    double? targetDistance;

    if (target != null) {
      targetDistance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        target.latitude,
        target.longitude,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _nextSeichi = target;
      _nextDistance = targetDistance;
    });
  }

'@

$updated = $source.Substring(0, $start) + $newBlock + $source.Substring($end)
[System.IO.File]::WriteAllText($path, $updated, $encoding)

Write-Host 'Smart next-destination selection applied.'
Write-Host "Backup: $backup"
Write-Host 'Next, run flutter analyze.'
