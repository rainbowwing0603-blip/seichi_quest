import 'package:flutter/material.dart';

class StampAnimation extends StatelessWidget {
  final bool justCollected;
  final String? collectedName;
  final int collectedCount;
  final int total;

  const StampAnimation({
    super.key,
    required this.justCollected,
    required this.collectedName,
    required this.collectedCount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (!justCollected) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child:
              TweenAnimationBuilder<double>(
            tween: Tween(
              begin: 0.7,
              end: 1.0,
            ),
            duration:
                const Duration(
              milliseconds: 500,
            ),
            builder: (
              context,
              scale,
              child,
            ) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Material(
              elevation: 16,
              borderRadius:
                  BorderRadius.circular(
                28,
              ),
              child: Container(
                width: 290,
                padding:
                    const EdgeInsets.all(
                  24,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    28,
                  ),
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Text(
                      '🏆',
                      style: TextStyle(
                        fontSize: 64,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    const Text(
                      '聖地到達！',
                      style:
                          TextStyle(
                        fontSize: 27,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      collectedName ?? '',
                      textAlign:
                          TextAlign.center,
                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    Text(
                      '$collectedCount / $total 聖地獲得',
                      style:
                          const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}