import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'shared/widgets/catalog_thumbnail.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CatalogThumbnail.configureCache();
  await initializeDateFormatting('id_ID', null);
  runApp(const ProviderScope(child: PujanggaPosApp()));
}
