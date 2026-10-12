import 'package:workmanager/workmanager.dart';

import '../../core/secure_store.dart';
import '../../core/session.dart';
import 'backup_controller.dart';

const _task = 'alcove-photo-backup';

/// Entry point of the background isolate (Android WorkManager).
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    final session = Session(store: SecureStore());
    await session.restore();
    if (!session.isSignedIn) return true;
    final controller = await BackupController.create(session);
    // WorkManager stops tasks after about 10 minutes; the next run continues where this one stopped.
    await controller.runNow(budget: const Duration(minutes: 8));
    return true;
  });
}

Future<void> initBackgroundBackup() => Workmanager().initialize(backgroundDispatcher);

/// About every hour, when the network allows it (Wi-Fi only: unmetered networks).
Future<void> scheduleBackgroundBackup({required bool wifiOnly}) =>
    Workmanager().registerPeriodicTask(
      _task,
      _task,
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );

Future<void> cancelBackgroundBackup() => Workmanager().cancelByUniqueName(_task);
