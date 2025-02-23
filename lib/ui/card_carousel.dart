import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class CardCarouselWidget<T> extends StatefulWidget {
  final List<T> cardData;
  final Duration animationDuration;
  final Duration downScrollDuration;
  final Duration stackDuration;
  final double maxScrollDistance;
  final double scrollDownLimit;
  final double thresholdValue;
  final void Function(int)? onCardChange;
  final Widget Function(BuildContext context, int index, int visibleIndex)
      cardBuilder;
  final bool shouldStartCardStackAnimation;
  final void Function(bool value) onCardStackAnimationComplete;

  final double topCardOffsetStart;
  final double topCardOffsetEnd;
  final double topCardScaleStart;
  final double topCardScaleEnd;
  final double topCardYDrop;

  final double secondCardOffsetStart;
  final double secondCardOffsetEnd;
  final double secondCardScaleStart;
  final double secondCardScaleEnd;

  const CardCarouselWidget({
    required this.cardData,
    required this.cardBuilder,
    this.animationDuration = const Duration(milliseconds: 800),
    this.downScrollDuration = const Duration(milliseconds: 300),
    this.stackDuration = const Duration(milliseconds: 1000),
    this.maxScrollDistance = 220.0,
    this.scrollDownLimit = -40.0,
    this.thresholdValue = 0.3,
    this.onCardChange,
    this.topCardOffsetStart = 0.0,
    this.topCardOffsetEnd = 15.0,
    this.topCardScaleStart = 1.0,
    this.topCardScaleEnd = 0.9,
    this.topCardYDrop = 0.0,
    this.secondCardOffsetStart = 15.0,
    this.secondCardOffsetEnd = 0.0,
    this.secondCardScaleStart = 0.85,
    this.secondCardScaleEnd = 1.0,
    this.shouldStartCardStackAnimation = false,
    required this.onCardStackAnimationComplete,
    super.key,
  });

  @override
  State<CardCarouselWidget<T>> createState() => _CardCarouselWidgetState<T>();
}

class _CardCarouselWidgetState<T> extends State<CardCarouselWidget<T>>
    with TickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _yOffsetAnimation;
  Animation<double>? _rotationAnimation;
  Animation<double>? _animation;
  AnimationController? _downScrollController;
  Animation<double>? _downScrollAnimation;
  AnimationController? _cardStackAnimationController;
  Animation<double>? _cardStackYOffsetAnimation;

  double _startAnimationValue = 0.0;
  double _scrollStartPosition = 0.0;
  double _scrollOffset = 0.0;
  bool _isCardMoved = false;
  bool _hasReachedHalf = false;
  bool _isAnimationBlocked = false;
  bool _shouldPlayVibration = true;

  late List<T> _cardData;

  Timer? _debounceTimer;

  Widget? _topCardWidget;
  int? _topCardIndex;

  Widget? _secondCardWidget;
  int? _secondCardIndex;

  Widget? _thirdCardWidget;
  int? _thirdCardIndex;

  Widget? _poppedCardWidget;
  int? _poppedCardIndex;

  Future<void> onCardMoveVibration() async {}

  Future<void> onCardBlockVibration() async {}

  @override
  void initState() {
    super.initState();

    _cardData = List.from(widget.cardData);

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller ?? AnimationController(vsync: this),
      curve: Curves.easeInOut,
    );

    _yOffsetAnimation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: 0.5),
        weight: 45.0,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.5, end: 1.0),
        weight: 55.0,
      ),
    ]).animate(_animation ?? const AlwaysStoppedAnimation(0.0));

    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: -180.0),
        weight: 45.0,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -180.0, end: -180.0),
        weight: 55.0,
      ),
    ]).animate(_animation ?? const AlwaysStoppedAnimation(0.0));

    _downScrollController = AnimationController(
      duration: widget.downScrollDuration,
      vsync: this,
    );

    _downScrollAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(_downScrollController ?? AnimationController(vsync: this))
      ..addListener(() {
        _scrollOffset = _downScrollAnimation?.value ?? 0.0;
      });

    _controller?.addListener(() {
      if (_cardData.length > 1) {
        if (!_isCardMoved && (_controller?.value ?? 0.0) >= 0.5) {
          if (_debounceTimer?.isActive ?? false) {
            _isCardMoved = true;
            return;
          }

          var firstCard = _cardData.removeAt(0);
          _poppedCardIndex = widget.cardData.indexOf(firstCard);
          _poppedCardWidget =
              widget.cardBuilder(context, _poppedCardIndex ?? 0, -1);
          _cardData.add(firstCard);
          onCardMoveVibration();

          _isCardMoved = true;

          _updateCardWidgets();

          if (widget.onCardChange != null) {
            widget.onCardChange?.call(widget.cardData.indexOf(_cardData[0]));
          }

          _debounceTimer = Timer(const Duration(milliseconds: 300), () {});
        }

        if ((_controller?.value ?? 0.0) == 1.0) {
          _isCardMoved = false;
          _controller?.reset();
          _hasReachedHalf = false;
        }
      } else {
        _controller?.reset();
      }
    });

    if (widget.shouldStartCardStackAnimation) {
      _cardStackAnimationController = AnimationController(
        duration: widget.stackDuration,
        vsync: this,
      );

      _cardStackYOffsetAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent:
            _cardStackAnimationController ?? AnimationController(vsync: this),
        curve: Curves.easeOutCubic,
      ));

      _cardStackAnimationController
          ?.forward()
          .then((_) => widget.onCardStackAnimationComplete(false));
    }

    _updateCardWidgets();
  }

  void _updateCardWidgets() {
    if (_cardData.isNotEmpty) {
      _topCardIndex = widget.cardData.indexOf(_cardData[0]);
      _topCardWidget = widget.cardBuilder(context, _topCardIndex ?? 0, 0);
    } else {
      _topCardIndex = null;
      _topCardWidget = null;
    }

    if (_cardData.length > 1) {
      _secondCardIndex = widget.cardData.indexOf(_cardData[1]);
      _secondCardWidget = widget.cardBuilder(context, _secondCardIndex ?? 0, 1);
    } else {
      _secondCardIndex = null;
      _secondCardWidget = null;
    }

    if (_cardData.length > 2) {
      _thirdCardIndex = widget.cardData.indexOf(_cardData[2]);
      _thirdCardWidget = widget.cardBuilder(context, _thirdCardIndex ?? 0, 2);
    } else {
      _thirdCardIndex = null;
      _thirdCardWidget = null;
    }
  }

  @override
  void didUpdateWidget(CardCarouselWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.cardData != oldWidget.cardData) {
      _controller?.stop();
      _downScrollController?.stop();

      _cardData = List.from(widget.cardData);
      _isCardMoved = false;
      _hasReachedHalf = false;
      _startAnimationValue = 0.0;
      _scrollStartPosition = 0.0;
      _scrollOffset = 0.0;

      _controller?.reset();
      _downScrollController?.reset();

      _updateCardWidgets();
    }

    if (widget.shouldStartCardStackAnimation !=
        oldWidget.shouldStartCardStackAnimation) {
      if (widget.shouldStartCardStackAnimation) {
        _cardStackAnimationController = AnimationController(
          duration: const Duration(milliseconds: 1000),
          vsync: this,
        );

        _cardStackYOffsetAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent:
              _cardStackAnimationController ?? AnimationController(vsync: this),
          curve: Curves.easeOutCubic,
        ));

        _cardStackAnimationController
            ?.forward()
            .then((_) => widget.onCardStackAnimationComplete(false));
      } else {
        _cardStackAnimationController?.dispose();
        _cardStackAnimationController = null;
        _cardStackYOffsetAnimation = null;
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _downScrollController?.dispose();
    _debounceTimer?.cancel();
    _cardStackAnimationController?.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_controller?.isAnimating == true ||
        _downScrollController?.isAnimating == true ||
        widget.shouldStartCardStackAnimation ||
        _cardData.length == 1) {
      return;
    }
    _isAnimationBlocked = false;
    _startAnimationValue = _controller?.value ?? 0.0;
    _scrollStartPosition = details.globalPosition.dx;
    _controller?.stop(canceled: false);
    _downScrollController?.stop();
    _hasReachedHalf = false;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_controller?.isAnimating == true ||
        _downScrollController?.isAnimating == true ||
        _hasReachedHalf ||
        widget.shouldStartCardStackAnimation ||
        _isAnimationBlocked ||
        _cardData.length == 1) {
      return;
    }
    if (_hasReachedHalf) {
      return;
    }

    double scrollDistance = _scrollStartPosition - details.globalPosition.dx;

    if (scrollDistance >= 0) {
      double scrollFraction = scrollDistance / widget.maxScrollDistance;
      double newValue = (_startAnimationValue + scrollFraction).clamp(0.0, 1.0);
      if (_controller != null) {
        _controller?.value = newValue;
      }
      _scrollOffset = 0.0;

      if ((_controller?.value ?? 0.0) >= 0.5 && !_hasReachedHalf) {
        _hasReachedHalf = true;
        final double remaining = 1.0 - (_controller?.value ?? 0.0);
        final int duration =
            ((_controller?.duration?.inMilliseconds ?? 0) * remaining).round();
        if (duration > 0) {
          _controller?.animateTo(1.0,
              duration: Duration(milliseconds: duration),
              curve: Curves.easeOut);
          _isAnimationBlocked = true;
        } else {
          if (_controller != null) {
            _controller?.value = 1.0;
          }
        }
      }
    } else {
      if (_controller != null) {
        _controller?.value = _startAnimationValue;
      }
      double downScrollOffset =
          scrollDistance.clamp(widget.scrollDownLimit, 0.0);
      _scrollOffset = -downScrollOffset;
      if (downScrollOffset == widget.scrollDownLimit) {
        if (_shouldPlayVibration) {
          onCardBlockVibration();
          _shouldPlayVibration = false;
        }
      }
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_controller?.isAnimating == true ||
        _downScrollController?.isAnimating == true ||
        widget.shouldStartCardStackAnimation ||
        _isAnimationBlocked ||
        _cardData.length == 1) {
      return;
    }
    if (_scrollOffset != 0.0) {
      _downScrollAnimation = Tween<double>(
        begin: _scrollOffset,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _downScrollController ?? AnimationController(vsync: this),
        curve: Curves.easeOutCubic,
      ));
      _downScrollController?.forward(from: 0.0);
    } else if (!_hasReachedHalf) {
      if ((_controller?.value ?? 0.0) >= widget.thresholdValue) {
        final double remaining = 1.0 - (_controller?.value ?? 0.0);
        final int duration =
            ((_controller?.duration?.inMilliseconds ?? 0) * remaining).round();
        if (duration > 0) {
          _controller?.animateTo(1.0,
              duration: Duration(milliseconds: duration),
              curve: Curves.easeOut);
          _isAnimationBlocked = true;
        } else {
          if (_controller != null) {
            _controller?.value = 1.0;
          }
        }
      } else {
        final int duration = ((_controller?.duration?.inMilliseconds ?? 0) *
                (_controller?.value ?? 0.0))
            .round();
        if (duration > 0) {
          _controller?.animateBack(0.0,
              duration: Duration(milliseconds: duration),
              curve: Curves.easeOut);
        } else {
          if (_controller != null) {
            _controller?.value = 0.0;
          }
        }
      }
    }
    _shouldPlayVibration = true;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _controller ?? AnimationController(vsync: this),
            _downScrollController ?? AnimationController(vsync: this),
            if (widget.shouldStartCardStackAnimation)
              _cardStackAnimationController ?? AnimationController(vsync: this),
          ]),
          builder: (context, child) {
            double yOffsetAnimationValue = _yOffsetAnimation?.value ?? 0.0;
            double rotation = _rotationAnimation?.value ?? 0.0;
            double totalXOffset = widget.topCardOffsetStart -
                yOffsetAnimationValue * widget.maxScrollDistance +
                (_downScrollController?.isAnimating == true
                    ? _downScrollAnimation?.value ?? 0.0
                    : _scrollOffset);
            double totalYOffset =
                (_controller?.value ?? 0.0) * widget.topCardYDrop;

            List<Widget> stackChildren = [];

            if (_cardData.length == 1) {
              stackChildren.add(_topCardWidget ?? const SizedBox.shrink());
            } else {
              int cardCount = min(_cardData.length, 3);

              if (_isCardMoved) {
                for (int i = 0; i < cardCount; i++) {
                  if (i == 0) {
                    stackChildren.add(
                        buildTopCard(totalXOffset, rotation, totalYOffset));
                  } else {
                    stackChildren.add(buildCard(cardCount - i));
                  }
                }
              } else {
                for (int i = cardCount - 1; i >= 0; i--) {
                  if (i == 0) {
                    stackChildren.add(
                        buildTopCard(totalXOffset, rotation, totalYOffset));
                  } else {
                    stackChildren.add(buildCard(i));
                  }
                }
              }
            }

            return Stack(
              alignment: Alignment.center,
              children: stackChildren,
            );
          },
        ),
      ),
    );
  }

  Widget buildTopCard(double xOffset, double rotation, double yOffset) {
    if (_topCardWidget == null) {
      return const SizedBox.shrink();
    }

    Widget cardWidget = _isCardMoved && _cardData.length > 1
        ? (_poppedCardWidget ?? const SizedBox.shrink())
        : (_topCardWidget ?? const SizedBox.shrink());

    return AnimatedBuilder(
      animation: _controller ?? const AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        double scale;

        double controllerValue = _controller?.value ?? 0.0;

        if (_cardData.length == 2) {
          if (controllerValue <= 0.5 && _cardData.length > 1) {
            if (controllerValue >= 0.45) {
              double progress = (controllerValue - 0.45) / 0.05;
              scale = 1.0 - 0.05 * progress;
            } else {
              scale = 1.0;
            }
          } else {
            scale = 0.95;
          }
        } else {
          if (controllerValue <= 0.5 && _cardData.length > 1) {
            if (controllerValue >= 0.4) {
              double progress = (controllerValue - 0.4) / 0.1;
              scale = 1.0 - 0.1 * progress;
            } else {
              scale = 1.0;
            }
          } else {
            scale = 0.9;
          }
        }

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(xOffset, yOffset)
            ..translate(
                0.0,
                _isCardMoved
                    ? (-widget.secondCardOffsetStart) *
                        (((_rotationAnimation?.value ?? 0) + 180) / 90)
                    : 0)
            ..setEntry(3, 2, 0.001)
            ..rotateZ(rotation * pi / 720)
            ..scale(scale, scale),
          child: AnimatedOpacity(
            opacity: controllerValue >= 0.5 ? 1 - controllerValue : 1,
            duration: const Duration(milliseconds: 500),
            child: child,
          ),
        );
      },
      child: cardWidget,
    );
  }

  Widget buildCard(int index) {
    if (_cardData.length <= 1 || index >= _cardData.length) {
      return const SizedBox.shrink();
    }

    Widget? cardWidget;
    if (_isCardMoved) {
      if (index == 1) {
        cardWidget = _topCardWidget;
      } else if (index == 2) {
        cardWidget = _secondCardWidget;
      } else {
        return const SizedBox.shrink();
      }
    } else {
      if (index == 1) {
        cardWidget = _secondCardWidget;
      } else if (index == 2) {
        cardWidget = _thirdCardWidget;
      } else {
        return const SizedBox.shrink();
      }
    }

    if (cardWidget == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller ?? const AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        double initialOffset = 0.0;
        double initialScale = 1.0;
        double targetScale = 1.0;

        double controllerValue = _controller?.value ?? 0.0;

        if (_cardData.length == 2) {
          if (index == 1) {
            initialOffset = widget.secondCardOffsetStart;
            initialScale = widget.secondCardScaleStart;
            targetScale = widget.secondCardScaleEnd;
          }
        } else {
          if (index == 0) {
            initialOffset = widget.topCardOffsetStart;
          }
          if (index == 1) {
            initialOffset = widget.secondCardOffsetStart;
            initialScale = widget.secondCardScaleStart;
            targetScale = widget.secondCardScaleEnd;
          } else if (index == 2) {
            initialOffset = widget.secondCardOffsetStart;
            initialScale = widget.secondCardScaleStart;
            targetScale = widget.secondCardScaleStart;
          }
        }

        double yOffset = initialOffset;
        double scale = initialScale;

        if (controllerValue <= 0.5) {
          double progress = controllerValue / 0.5;

          if (_cardData.length == 2) {
            yOffset = initialOffset - widget.secondCardOffsetStart * progress;
          } else {
            yOffset = index >= 2
                ? initialOffset
                : initialOffset - widget.secondCardOffsetStart * progress;
          }
          progress = Curves.easeOut.transform(progress);

          scale = initialScale;
        } else {
          double progress = (controllerValue - 0.5) / 0.5;

          if (_cardData.length == 2) {
            yOffset = initialOffset -
                widget.secondCardOffsetStart +
                widget.secondCardOffsetEnd * progress;
          } else {
            yOffset = index >= 2
                ? initialOffset
                : initialOffset -
                    widget.secondCardOffsetStart +
                    widget.secondCardOffsetEnd * progress;
          }
          progress = Curves.easeOut.transform(progress);

          scale = initialScale + (targetScale - initialScale) * progress;
        }

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(
                widget.shouldStartCardStackAnimation &&
                        _cardStackYOffsetAnimation != null
                    ? _cardStackYOffsetAnimation
                            ?.drive(CurveTween(
                                curve: Interval((0.4 * (index - 1)), 0.9)))
                            .drive(CurveTween(curve: Curves.easeOut))
                            .drive(Tween(begin: yOffset, end: yOffset + 20))
                            .value ??
                        0
                    : yOffset,
                0.0)
            ..scale(scale, scale),
          child: child,
        );
      },
      child: cardWidget,
    );
  }
}
