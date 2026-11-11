import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/palabra.dart';

class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.palabra,
    required this.isFlipped,
    required this.onSpeak,
    required this.onFlip,
  });

  final Palabra palabra;
  final bool isFlipped;
  final VoidCallback onSpeak;
  final VoidCallback onFlip;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onFlip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = math.pi * _animation.value;
          final showTranslation = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(showTranslation ? math.pi : 0),
              child: _CardFace(
                label: showTranslation
                    ? widget.palabra.espanol
                    : widget.palabra.ingles,
                showAudio: !showTranslation,
                onSpeak: widget.onSpeak,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.label,
    required this.showAudio,
    required this.onSpeak,
  });

  final String label;
  final bool showAudio;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160D3425),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 72),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (showAudio)
            Positioned(
              bottom: 18,
              child: Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Escuchar pronunciación en inglés',
                  onPressed: onSpeak,
                  icon: Icon(
                    Icons.volume_up_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
