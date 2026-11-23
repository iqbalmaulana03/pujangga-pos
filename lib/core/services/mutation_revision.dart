import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MutationDomain { financial, stock, catalog }

typedef MutationRevisions = ({int financial, int stock, int catalog});

final mutationRevisionProvider =
    NotifierProvider<MutationRevision, MutationRevisions>(MutationRevision.new);

/// Publishes all affected revisions after a repository write commits.
class MutationRevision extends Notifier<MutationRevisions> {
  @override
  MutationRevisions build() => (financial: 0, stock: 0, catalog: 0);

  Future<T> commit<T>(
    Set<MutationDomain> domains,
    Future<T> Function() write,
  ) async {
    final operationRef = ref;
    final result = await write();
    if (operationRef.mounted) {
      final current = state;
      state = (
        financial:
            current.financial +
            (domains.contains(MutationDomain.financial) ? 1 : 0),
        stock: current.stock + (domains.contains(MutationDomain.stock) ? 1 : 0),
        catalog:
            current.catalog +
            (domains.contains(MutationDomain.catalog) ? 1 : 0),
      );
    }
    return result;
  }
}
