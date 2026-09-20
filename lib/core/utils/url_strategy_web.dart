// ignore_for_file: avoid_web_libraries_in_flutter, depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';

/// Configures clean HTML5 path URLs (removes `#` from URLs) on Flutter Web.
void configureAppUrlStrategy() {
  usePathUrlStrategy();
}
