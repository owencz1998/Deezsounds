import 'package:alchemy/fonts/alchemy_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

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
      if (widget.scrollController.position.pixels >= widget.expandedHeight &&
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
