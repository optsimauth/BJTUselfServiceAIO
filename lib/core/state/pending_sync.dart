import 'sync_result.dart';

final class PendingSync {
  PendingSync({required this.result, required this.commit});

  final SyncResult result;
  final Future<SyncResult> Function() commit;
}
