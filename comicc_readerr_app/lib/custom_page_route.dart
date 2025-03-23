import 'package:flutter/material.dart';

class FadePageRoute<T> extends PageRoute<T> {
  final Widget child;
  
  FadePageRoute({
    required this.child,
    RouteSettings? settings,
  }) : super(settings: settings, fullscreenDialog: false);

  @override
  bool get opaque => false;
  
  @override
  bool get barrierDismissible => false;
  
  @override
  Color? get barrierColor => null;
  
  @override
  String? get barrierLabel => null;
  
  @override
  bool get maintainState => true;
  
  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
  
  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}