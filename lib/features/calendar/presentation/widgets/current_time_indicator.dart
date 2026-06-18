import 'package:flutter/material.dart';

class CurrentTimeIndicator extends StatelessWidget {
  final double top;
  final double leftOffset;

  const CurrentTimeIndicator({
    super.key,
    required this.top,
    this.leftOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: leftOffset,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
