import 'package:sqflite/sqflite.dart';

Future<bool> allowsNegativeStock(DatabaseExecutor executor) async {
  final settings = await executor.query(
    'app_settings',
    columns: ['stock_allow_negative'],
    orderBy: 'id',
    limit: 1,
  );
  return settings.isNotEmpty && settings.single['stock_allow_negative'] == 1;
}
