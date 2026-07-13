import 'package:flutter/widgets.dart';

/// 앱 전역 RouteObserver — 화면이 다른 화면을 push했다가 복귀했을 때
/// `RouteAware.didPopNext`로 데이터를 다시 읽기 위해 MaterialApp에 등록한다.
final appRouteObserver = RouteObserver<PageRoute<dynamic>>();
