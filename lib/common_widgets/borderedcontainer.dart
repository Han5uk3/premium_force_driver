import 'package:flutter/material.dart';

class PremiumContainer extends StatelessWidget {
  const PremiumContainer({
    super.key,
    required this.height,
    required this.width,
    required this.child,
  });

  final double height;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.black,
        gradient: LinearGradient(
          colors: [Color(0xFF4A4A4A), Color(0xFFC0C0C0), Color(0xFF666666)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Container(
          height: height - 1.2,
          width: width - 1.2,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ),
    );
  }
}
