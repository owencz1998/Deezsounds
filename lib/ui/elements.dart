import 'dart:math';
import 'dart:ui';

import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings.dart';

class LeadingIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  const LeadingIcon(this.icon, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42.0,
      height: 42.0,
      decoration: BoxDecoration(
          color: (color ?? Theme.of(context).primaryColor),
          shape: BoxShape.circle),
      child: Icon(
        icon,
        color: Colors.white,
      ),
    );
  }
}

//Container with set size to match LeadingIcon
class EmptyLeading extends StatelessWidget {
  const EmptyLeading({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 42.0, height: 42.0);
  }
}

class FreezerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;
  final Widget? bottom;
  //Should be specified if bottom is specified
  final double height;

  const FreezerAppBar(this.title,
      {super.key, this.actions = const [], this.bottom, this.height = 64.0});

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
          primaryColor: (Theme.of(context).brightness == Brightness.light)
              ? Colors.white
              : Colors.black),
      child: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Theme.of(context).brightness),
        elevation: 0.0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: (Theme.of(context).brightness == Brightness.light)
            ? Colors.black
            : Colors.white,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        actions: actions,
        bottom: bottom as PreferredSizeWidget?,
      ),
    );
  }
}

class FreezerDivider extends StatelessWidget {
  const FreezerDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      thickness: 1.5,
      indent: 16.0,
      endIndent: 16.0,
    );
  }
}

TextStyle popupMenuTextStyle() {
  return TextStyle(color: settings.isDark ? Colors.white : Colors.black);
}

class DetailedAppBar extends StatefulWidget {
  final String title;
  final String? subtitle;
  final VoidCallback moreFunction;
  final List<Widget> screens;
  final Function? loadNextPage;
  final ScrollController scrollController;
  final double expandedHeight;
  const DetailedAppBar(
      {required this.title,
      this.subtitle,
      required this.moreFunction,
      required this.expandedHeight,
      required this.screens,
      required this.scrollController,
      this.loadNextPage,
      super.key});

  @override
  _DetailedAppBarState createState() => _DetailedAppBarState();
}

class _DetailedAppBarState extends State<DetailedAppBar> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool isCollapsed = false;

  @override
  void initState() {
    super.initState();

    widget.scrollController.addListener(() {
      double off = widget.scrollController.position.maxScrollExtent * 0.90;
      if (widget.scrollController.position.pixels >=
              (widget.expandedHeight - MediaQuery.of(context).padding.top) &&
          mounted) {
        setState(() {
          isCollapsed = true;
        });
      } else {
        if (mounted) {
          setState(() {
            isCollapsed = false;
          });
        }
      }
      if (widget.scrollController.position.pixels > off &&
          widget.loadNextPage != null) {
        widget.loadNextPage!();
      }
    });

    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });

    SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      actionsPadding: EdgeInsets.zero,
      stretch: true,
      pinned: true,
      title: AnimatedOpacity(
        opacity: isCollapsed ? 1 : 0,
        duration: Duration(milliseconds: 200),
        child: ListTile(
          title: Text(widget.title),
          subtitle: widget.subtitle != null
              ? Text(
                  widget.subtitle!,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                )
              : null,
        ),
      ),
      expandedHeight:
          widget.expandedHeight - MediaQuery.of(context).padding.top,
      iconTheme: Theme.of(context).iconTheme,
      actions: [
        IconButton(
          icon: Icon(AlchemyIcons.more_vert),
          onPressed: widget.moreFunction,
        )
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: SizedBox(
          width: double.infinity,
          height: widget.expandedHeight - MediaQuery.of(context).padding.top,
          child: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: widget.screens,
              ),
              if (widget.screens.length > 1)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(
                            2,
                            (i) => Container(
                                  margin: EdgeInsets.symmetric(
                                      horizontal: 2.0, vertical: 8.0),
                                  width: 12.0,
                                  height: 4.0,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(
                                        _currentPage == i ? 255 : 150),
                                    border:
                                        Border.all(color: Colors.transparent),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomOverflowText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int maxLines;

  const CustomOverflowText({
    super.key,
    required this.text,
    this.style = const TextStyle(),
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: maxLines,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.justify,
        );
        textPainter.layout(maxWidth: constraints.maxWidth);

        if (textPainter.didExceedMaxLines) {
          final ellipsisTextPainter = TextPainter(
            text: TextSpan(text: '...', style: style),
            maxLines: 1,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.justify,
          );
          ellipsisTextPainter.layout();
          final ellipsisWidth = ellipsisTextPainter.width;

          final viewAllTextPainter = TextPainter(
            text: TextSpan(
              text: ' View all',
              style: style.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color ??
                      Colors.white),
            ),
            maxLines: 1,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.justify,
          );
          viewAllTextPainter.layout();
          final viewAllWidth = viewAllTextPainter.width;

          final availableWidthForText =
              constraints.maxWidth - ellipsisWidth - viewAllWidth;

          final truncatedTextPainter = TextPainter(
            text: TextSpan(text: text, style: style),
            maxLines: maxLines,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.justify,
          );
          truncatedTextPainter.layout(maxWidth: availableWidthForText);

          TextPosition endOfLastLine =
              truncatedTextPainter.getPositionForOffset(Offset(
                  availableWidthForText,
                  (maxLines - 1) * truncatedTextPainter.height));
          final truncatedText = text.substring(0, endOfLastLine.offset);

          return RichText(
            maxLines: maxLines,
            overflow: TextOverflow.clip,
            textAlign: TextAlign
                .justify, // Applied textAlign: TextAlign.justify to RichText
            text: TextSpan(
              style: style,
              children: [
                TextSpan(text: truncatedText),
                const TextSpan(text: '...'),
                TextSpan(
                  text: ' View all',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color ??
                          Colors.white),
                ),
              ],
            ),
          );
        } else {
          return Text(
            text,
            style: style,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.justify,
          );
        }
      },
    );
  }
}

class MinimalistSoundWave extends StatefulWidget {
  final Color color;
  final int barCount;
  final double width;
  final double height;
  final Duration duration;
  final double barWidth; // Optional: specify bar width
  final double gap; // Optional: specify gap between bars

  const MinimalistSoundWave({
    super.key,
    this.color = Colors.blue,
    this.barCount = 5,
    required this.width,
    required this.height,
    this.duration = const Duration(milliseconds: 800),
    this.barWidth = -1, // Default to calculated width
    this.gap = -1, // Default to calculated gap
  });

  @override
  _MinimalistSoundWaveState createState() => _MinimalistSoundWaveState();
}

class _MinimalistSoundWaveState extends State<MinimalistSoundWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
  }

  // Update duration if widget rebuilds with a new one
  @override
  void didUpdateWidget(MinimalistSoundWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      // Update the controller's duration
      _controller.duration = widget.duration;
      if (_controller.isAnimating) {
        _controller.repeat(reverse: true);
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
    // Using the updated painter below
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _SoundWavePainter(
              // Painter is updated
              animation: _controller,
              color: widget.color,
              barCount: widget.barCount,
              initialBarWidth: widget.barWidth,
              initialGap: widget.gap,
            ),
          );
        },
      ),
    );
  }
}

// --- MODIFIED Painter for More Complex Animation ---
class _SoundWavePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final int barCount;
  final double initialBarWidth;
  final double initialGap;

  // Parameters for the sine waves - tweak these for different effects!
  final double freq1 = 0.3; // Spatial frequency of the first wave
  final double freq2 = 0.9; // Spatial frequency of the second wave
  final double speed1 = 1.0; // Temporal speed multiplier for the first wave
  final double speed2 = 1.5; // Temporal speed multiplier for the second wave

  _SoundWavePainter({
    required this.animation,
    required this.color,
    required this.barCount,
    required this.initialBarWidth,
    required this.initialGap,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Calculation of barWidth and gap (same as before)
    double barWidth = initialBarWidth;
    double gap = initialGap;
    if (barWidth <= 0 || gap < 0) {
      double totalGapSpace = (gap >= 0) ? (gap * (barCount - 1)) : 0;
      double availableWidth = size.width - totalGapSpace;
      if (barWidth <= 0) {
        barWidth = availableWidth / barCount;
        if (gap < 0) {
          gap = barWidth / 4;
          totalGapSpace = gap * (barCount - 1);
          availableWidth = size.width - totalGapSpace;
          barWidth = availableWidth / barCount;
        }
      } else if (gap < 0) {
        gap = (size.width - (barWidth * barCount)) / max(1, barCount - 1);
      }
    }
    gap = max(0, gap);
    barWidth = max(1, barWidth);

    final double totalWidthOfBarsAndGaps =
        (barWidth * barCount) + (gap * (barCount - 1));
    final double startX = (size.width - totalWidthOfBarsAndGaps) / 2;

    final double maxBarHeight = size.height;
    final double minBarHeight = size.height * 0.1; // Or adjust if needed
    final double verticalCenter = size.height / 2;

    // Calculate base phases based on animation value and speeds
    final double basePhase = animation.value * 2 * pi;
    final double phase1 = basePhase * speed1;
    final double phase2 = basePhase * speed2;

    for (int i = 0; i < barCount; i++) {
      // Calculate the value of each sine wave for this bar (i) and phase
      final double wave1 = sin(i * freq1 + phase1); // Value between -1 and 1
      final double wave2 = sin(i * freq2 + phase2); // Value between -1 and 1

      // Combine the waves. The result is between -2 and 2.
      final double combinedWaves = wave1 + wave2;

      // Normalize the combined value to the range 0.0 to 1.0
      final double normalizedHeight = (combinedWaves + 2) / 4;

      // Clamp to ensure it stays strictly within bounds (optional but safe)
      final double clampedHeight = normalizedHeight.clamp(0.0, 1.0);

      // Calculate the actual bar height using lerp
      final double barHeight =
          lerpDouble(minBarHeight, maxBarHeight, clampedHeight)!;

      // Calculate position (centered alignment)
      final double top = verticalCenter - (barHeight / 2);
      final double x = startX + i * (barWidth + gap);

      // Draw the rounded rectangle (same as before)
      final Rect rect = Rect.fromLTWH(x, top, barWidth, barHeight);
      final RRect rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(barWidth));
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoundWavePainter oldDelegate) {
    // Only repaint if essential properties change, animation handles itself.
    return oldDelegate.color != color ||
        oldDelegate.barCount != barCount ||
        oldDelegate.initialBarWidth != initialBarWidth ||
        oldDelegate.initialGap != initialGap;
  }
}
