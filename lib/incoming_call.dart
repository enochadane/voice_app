import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

Set<String> _processedCallSids = {};
Future<void> showIncomingCallFromTwilioNotification(RemoteMessage message) async {
  final data = message.data;
  final String callSid = data['twi_call_sid'];

  if (_processedCallSids.contains(callSid)) return;
  _processedCallSids.add(callSid);

  final String uuid = const Uuid().v4();
  final String callerName = data['twi_from']?.replaceFirst('client:', '') ?? 'Unknown Caller';
  final String receiver = data['twi_to']?.replaceFirst('client:', '') ?? 'You';

  final CallKitParams callParams = CallKitParams(
    id: uuid,
    nameCaller: callerName,
    appName: 'Twilio Voice',
    handle: receiver,
    type: 0,
    duration: 30000,
    textAccept: 'Accept',
    
    extra: {
      'callSid': callSid,
      'bridgeToken': data['twi_bridge_token'],
      'from': data['twi_from'],
      'to': data['twi_to'],
    },
    android: const AndroidParams(
      isCustomNotification: true,
      backgroundColor: '#0955fa',
      incomingCallNotificationChannelName: 'Incoming Call',
    ),
  );

  await FlutterCallkitIncoming.showCallkitIncoming(callParams);
}
