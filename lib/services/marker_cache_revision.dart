class MarkerCacheRevision {
  int _value = 0;

  int get value => _value;

  void markChanged() {
    _value++;
  }

  bool isCurrent(int cachedRevision) {
    return cachedRevision == _value;
  }
}
