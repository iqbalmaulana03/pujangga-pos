import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Changes only after a successful replacement of the whole local dataset.
/// Data providers watch this so caches and drafts share the same lifetime.
/// Watch from query/draft providers, keeping database services and repositories
/// stable. Replacing shared service objects can notify other consumers while
/// a newly mounted screen is lazily rebuilding its dependencies.
final datasetGenerationProvider = NotifierProvider<DatasetGeneration, int>(
  DatasetGeneration.new,
);

class DatasetGeneration extends Notifier<int> {
  @override
  int build() => 0;

  void advance() => state++;
}
