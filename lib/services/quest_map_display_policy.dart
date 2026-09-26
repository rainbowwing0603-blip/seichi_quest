enum QuestMapDisplayMode {
  spots,
  clusters,
  regionalProgress,
}

class QuestMapDisplayPolicy {
  const QuestMapDisplayPolicy();

  static const double spotsMinZoom = 9.0;
  static const double clustersMinZoom = 6.0;

  QuestMapDisplayMode modeForZoom(double zoom) {
    if (zoom >= spotsMinZoom) return QuestMapDisplayMode.spots;
    if (zoom >= clustersMinZoom) return QuestMapDisplayMode.clusters;
    return QuestMapDisplayMode.regionalProgress;
  }

  int viewportLimitForZoom(double zoom) {
    switch (modeForZoom(zoom)) {
      case QuestMapDisplayMode.spots:
        return 400;
      case QuestMapDisplayMode.clusters:
        return 1000;
      case QuestMapDisplayMode.regionalProgress:
        return 0;
    }
  }
}
