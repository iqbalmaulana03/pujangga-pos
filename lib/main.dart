import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/utils/app_date_formatting.dart';
import 'shared/widgets/catalog_thumbnail.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CatalogThumbnail.configureCache();
  initializeAppDateFormatting();
  runApp(const ProviderScope(child: PujanggaPosApp()));
}
