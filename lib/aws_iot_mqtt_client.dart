library aws_iot_mqtt_client;

import 'dart:async';

import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:tuple/tuple.dart';

class AWSIoTClient {
  final _SERVICE_NAME = 'iotdevicegateway';
  final _AWS4_REQUEST = 'aws4_request';
  final _AWS4_HMAC_SHA256 = 'AWS4-HMAC-SHA256';
  final _SCHEME = 'wss://';

  String _region;
  String _accessKeyId;
  String _secretAccessKey;
  String _sessionToken;
  String _host;
  bool _logging = true;

  var _onConnected;
  var _onDisconnected;
  var _onSubscribed;
  var _onSubscribeFail;
  var _onUnsubscribed;

  get onConnected => _onConnected;

  set onConnected(val) => _client.onConnected = _onConnected = val;

  get onDisconnected => _onDisconnected;

  set onDisconnected(val) => _client.onDisconnected = _onDisconnected = val;

  get onSubscribed => _onSubscribed;

  set onSubscribed(val) => _client.onSubscribed = _onSubscribed = val;

  get onSubscribeFail => _onSubscribeFail;

  set onSubscribeFail(val) => _client.onSubscribeFail = _onSubscribeFail = val;

  get onUnsubscribed => _onUnsubscribed;

  set onUnsubscribed(val) => _client.onUnsubscribed = _onUnsubscribed = val;

  get connectionStatus => _client.connectionStatus;

  var _client;

  StreamController<Tuple2<String, String>> _messagesController = StreamController<Tuple2<String, String>>();

  Stream<Tuple2<String, String>> get messages => _messagesController.stream;

  AWSIoTClient(
      this._region,
      this._accessKeyId,
      this._secretAccessKey,
      this._sessionToken,
      this._host,
      {
        bool logging = false,
        var onConnected,
        var onDisconnected,
        var onSubscribed,
        var onSubscribeFail,
        var onUnsubscribed,
      }) {
    _logging = logging;
    _onConnected = onConnected;
    _onDisconnected = onDisconnected;
    _onSubscribed = onSubscribed;
    _onSubscribeFail = onSubscribeFail;
    _onUnsubscribed = onUnsubscribed;

    if (_host.contains('amazonaws.com')) {
      _host = _host.split('.').first;
    }
  }

  Future<void> connect(String clientId) async {
    if (_client == null) {
      _prepare(clientId);
    }

    try {
      await _client.connect();
    } on Exception catch (e) {
      _client.disconnect();
      rethrow;
    }

    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt =
      MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      _messagesController.add(Tuple2<String, String>(c[0].topic, pt));
    });
  }

  _prepare(String clientId) {
    final url = _prepareWebSocketUrl();
    _client = MqttServerClient(url, clientId);
    _client.logging(on: _logging);
    _client.websocketProtocols = ['mqtt'];
    _client.useWebSocket = true;
    _client.port = 443;
    _client.connectionMessage =
        MqttConnectMessage().withClientIdentifier(clientId);
    _client.keepAlivePeriod = 60;
    if (_onConnected != null) {
      _client.onConnected = _onConnected;
    }

    if (_onUnsubscribed != null) {
      _client.onUnsubscribed = _onUnsubscribed;
    }

    if (_onSubscribeFail != null) {
      _client.onSubscribeFail = _onSubscribeFail;
    }

    if (_onSubscribed != null) {
      _client.onSubscribed = _onSubscribed;
    }

    if (_onDisconnected != null) {
      _client.onDisconnected = _onDisconnected;
    }
  }

  _prepareWebSocketUrl() {
    final now = _generateDatetime();
    final hostname = _buildHostname();

    final List creds = [
      _accessKeyId,
      _getDate(now),
      _region,
      _SERVICE_NAME,
      _AWS4_REQUEST,
    ];

    const payload = '';

    const path = '/mqtt';

    final queryParams = Map<String, String>.from({
      'X-Amz-Algorithm': _AWS4_HMAC_SHA256,
      'X-Amz-Credential': creds.join('/'),
      'X-Amz-Date': now,
      'X-Amz-SignedHeaders': 'host',
    });

    final canonicalQueryString = SigV4.buildCanonicalQueryString(queryParams);
    final request = SigV4.buildCanonicalRequest(
        'GET',
        path,
        queryParams,
        Map.from({
          'host': hostname,
        }),
        payload);

    final hashedCanonicalRequest = SigV4.hashCanonicalRequest(request);
    final stringToSign = SigV4.buildStringToSign(
        now,
        SigV4.buildCredentialScope(now, _region, _SERVICE_NAME),
        hashedCanonicalRequest);

    final signingKey = SigV4.calculateSigningKey(
        _secretAccessKey, now, _region, _SERVICE_NAME);

    final signature = SigV4.calculateSignature(signingKey, stringToSign);

    final finalParams =
        '$canonicalQueryString&X-Amz-Signature=$signature&X-Amz-Security-Token=${Uri.encodeComponent(_sessionToken)}';

    return '$_SCHEME$hostname$path?$finalParams';
  }

  String _generateDatetime() {
    return DateTime.now()
        .toUtc()
        .toString()
        .replaceAll(RegExp(r'\.\d*Z$'), 'Z')
        .replaceAll(RegExp(r'[:-]|\.\d{3}'), '')
        .split(' ')
        .join('T');
  }

  String _getDate(String dateTime) {
    return dateTime.substring(0, 8);
  }

  String _buildHostname() {
    if (_region.contains('cn-north')){
      return '$_host.ats.iot.$_region.amazonaws.com.cn';
    }
    return '$_host.iot.$_region.amazonaws.com';
  }

  void publishMessage(String topic, String payload) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  disconnect() {
    return _client.disconnect();
  }

  Subscription? subscribe(String topic,
      [MqttQos qosLevel = MqttQos.atMostOnce]) {
    return _client.subscribe(topic, qosLevel);
  }

  unsubscribe(String topic) {
    _client.unsubscribe(topic);
  }
}
