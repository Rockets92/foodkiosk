import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_app/src/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'offline, a totem that never reached a server takes the factory PIN',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect(await offlinePinMatches('1234'), isTrue);
      expect(await offlinePinMatches('0000'), isFalse);
    },
  );

  test(
    'offline, the last PIN the server accepted opens the staff menu',
    () async {
      SharedPreferences.setMockInitialValues({});
      await rememberStaffPin('9876');
      expect(await offlinePinMatches('9876'), isTrue);
      expect(await offlinePinMatches('1234'), isFalse);
    },
  );

  test('a typed server address gets scheme and default port', () {
    expect(
      parseServerAddress(' 192.168.1.20 ').toString(),
      'http://192.168.1.20:8080/',
    );
    expect(
      parseServerAddress('http://cassa:9000').toString(),
      'http://cassa:9000/',
    );
    expect(parseServerAddress(''), isNull);
  });
}
