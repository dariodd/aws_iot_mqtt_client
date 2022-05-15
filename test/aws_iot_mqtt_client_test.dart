import 'package:flutter_test/flutter_test.dart';

import 'package:aws_iot_mqtt_client/aws_iot_mqtt_client.dart';

void main() {
  test('Try connection', () async {
    const test = {
      "api_gw_endpoint":"",
      "session_token":"",
      "secret_access_key":"",
      "access_key_id":""
    };
    var _list = test.values.toList();
    final client = AWSIoTClient('', _list[3], _list[2], _list[1], '');
    await client.connect('pippo');
  });
}
