bool haveSameStringValues(Set<String> current, Iterable<String> next) {
  final nextSet = next is Set<String> ? next : next.toSet();

  return current.length == nextSet.length && current.containsAll(nextSet);
}
