import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/models/quest_item.dart';
import 'package:seichi_quest/services/quest_map_cluster_service.dart';

QuestItem item(String id, double lat, double lon) => QuestItem(
      id: id,
      eventContentId: id,
      contentId: 'content-$id',
      placeId: 'place-$id',
      contentKey: id,
      title: id,
      latitude: lat,
      longitude: lon,
      radiusMeters: 200,
      description: '',
      icon: '📍',
      displayOrder: 0,
      isActive: true,
    );

void main() {
  const service = QuestMapClusterService();

  test('nearby items share a cluster at middle zoom', () {
    final clusters = service.build(
      items: [
        item('a', 36.39, 139.06),
        item('b', 36.41, 139.08),
      ],
      zoom: 7,
    );
    expect(clusters.length, 1);
    expect(clusters.single.count, 2);
  });

  test('cluster bounds include all items and have usable area', () {
    final cluster = service.build(
      items: [
        item('a', 36.39, 139.06),
        item('b', 36.41, 139.08),
      ],
      zoom: 7,
    ).single;
    final bounds = service.boundsFor(cluster);
    expect(bounds.southwest.latitude, lessThan(36.39));
    expect(bounds.northeast.latitude, greaterThan(36.41));
  });

  test('single item remains a tappable single-item cluster', () {
    final clusters = service.build(
      items: [item('solo', 43.06, 141.35)],
      zoom: 7,
    );
    expect(clusters.length, 1);
    expect(clusters.single.count, 1);
    expect(clusters.single.items.single.id, 'solo');
  });

  test('clusters split as map zoom increases', () {
    final items = [
      item('a', 36.10, 139.10),
      item('b', 36.45, 139.45),
    ];
    final wide = service.build(items: items, zoom: 6);
    final close = service.build(items: items, zoom: 9);
    expect(wide.length, lessThanOrEqualTo(close.length));
  });

  test('cluster membership is stable regardless of input order', () {
    final a = item('a', 36.39, 139.06);
    final b = item('b', 36.41, 139.08);
    final forward = service.build(items: [a, b], zoom: 7).single;
    final reverse = service.build(items: [b, a], zoom: 7).single;

    expect(forward.id, reverse.id);
    expect(forward.count, reverse.count);
    expect(forward.latitude, closeTo(reverse.latitude, 0.000001));
    expect(forward.longitude, closeTo(reverse.longitude, 0.000001));
  });
}
