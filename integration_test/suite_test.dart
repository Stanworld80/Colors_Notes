import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' as app_test;
import 'journal_flow_test.dart' as journal_flow_test;
import 'note_flow_test.dart' as note_flow_test;
import 'notification_flow_test.dart' as notification_flow_test;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // We group them to run sequentially
  group('App Test', () {
    app_test.main();
  });

  group('Journal Flow', () {
    journal_flow_test.main();
  });

  group('Note Flow', () {
    note_flow_test.main();
  });

  group('Notification Flow', () {
    notification_flow_test.main();
  });
}
