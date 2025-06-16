import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:twilio_voice_flutter/model/call.dart';
import 'package:twilio_voice_flutter/model/event.dart';
import 'package:twilio_voice_flutter/twilio_voice_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:twilio_voice/twilio_voice.dart';
import 'package:uuid/uuid.dart';

import 'main.dart';

class TwilioVoiceServices {
  static Future<String> _getAccessToken(String identity) async {
    final url = Uri.parse(
        // 'https://4in8hsk3i4.execute-api.us-west-2.amazonaws.com/dev/token',

        "https://twilio-voice-server-mu.vercel.app/api/access-token?identity=$identity");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      debugPrint("✅ Token Response for $identity: ${response.body}");
      final jsonBody = json.decode(response.body);
      debugPrint("✅ Token Response for $identity: $jsonBody");
      return jsonBody['token'];
    } else {
      debugPrint("❌ Failed to fetch Twilio token: ${response.body}");
      throw Exception("❌ Failed to fetch Twilio token");
    }
  }

  static Future<void> placeCall(
      {required String to, required String from}) async {
    final url =
        Uri.parse("https://twilio-voice-server-mu.vercel.app/api/place-call");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'to': to,
          'from': from,
          'To': to,
          'From': from,
          'identity': from,
          'callType': 'audio'
        }),
      );

      if (response.statusCode == 200) {
        // final jsonBody = json.decode(response.body);
        debugPrint("✅ Place Call Response: ${response.body}");
      } else {
        debugPrint("✅ failed Call Response: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Error while placing call: $e");
      throw Exception("❌ Error while placing call: $e");
    }
  }

  static Stream<TwilioVoiceFlutterEvent> get callEventsListener {
    return TwilioVoiceFlutter.onCallEvent;
  }

  static Future<void> initialize() async {
    await requestPermissionsForVoiceCall();
    await TwilioVoice.instance.requestMicAccess();
    await TwilioVoice.instance.requestCallPhonePermission();
    await TwilioVoice.instance.requestManageOwnCallsPermission();
    await TwilioVoice.instance.requestReadPhoneStatePermission();
    await TwilioVoice.instance.requestReadPhoneNumbersPermission();
    // alicecaller
    await setTwilioToken(
        "receiver"); //  to= user_receiver  alice caller and bob callee //alicecaller
  }

  static Future<void> _requestAudioPermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  static Future<void> _requestPermission(Permission permission) async {
    if (await permission.isDenied || await permission.isPermanentlyDenied) {
      await permission.request();
    }
  }

  static Future<bool> _isAndroid12orAbove() async {
    return (await Permission.bluetoothConnect.status !=
        PermissionStatus.denied);
  }

  static Future<void> requestPermissionsForVoiceCall() async {
    await _requestPermission(Permission.microphone);

    if (Platform.isAndroid && await _isAndroid12orAbove()) {
      await _requestPermission(Permission.bluetoothConnect);
    }

    if (Platform.isAndroid) {
      await _requestPermission(Permission.phone);
      await _requestPermission(Permission.notification);
    }

    if (Platform.isAndroid && await _isAndroid13orAbove()) {
      await _requestPermission(Permission.notification);
    }
  }

  static Future<bool> _isAndroid13orAbove() async {
    return (await Permission.notification.status != PermissionStatus.denied);
  }

  static Future<bool> setTwilioToken(String identity) async {
    String accessToken = await _getAccessToken(identity);
    String? fcmToken = await _getFcmToken();
    if (Platform.isAndroid) {
      try {
        if (fcmToken.isEmpty) {
          debugPrint("❌ FCM token is null or empty");
          return false;
        }
        debugPrint("Done FCM token is $fcmToken");
        await TwilioVoiceFlutter.register(
            identity: identity, accessToken: accessToken, fcmToken: fcmToken);
        debugPrint("fcmToken :: $accessToken $fcmToken");
      } on PlatformException catch (error) {
        debugPrint("Error while registering Twilio: ${error.message}");
        if (error.code == "TOKEN_EXPIRED") {
          showSnackBar(error.message.toString(), MsgStatus.error);
        } else {
          showSnackBar(error.message.toString(), MsgStatus.warning);
        }
      }
    } else {
      try {
        if (fcmToken.isEmpty) {
          debugPrint("❌ FCM token is null or empty");
          return false;
        }
        await TwilioVoiceFlutter.register(
            identity: identity, accessToken: accessToken, fcmToken: "");
      } on PlatformException catch (error) {
        debugPrint("Error while registering Twilio: ${error.message}");

        if (error.code == "TOKEN_EXPIRED") {
          showSnackBar(error.message.toString(), MsgStatus.error);
        } else {
          showSnackBar(error.message.toString(), MsgStatus.warning);
        }
      }
    }
    await TwilioVoice.instance.requestMicAccess();
    if (!await TwilioVoice.instance.isPhoneAccountEnabled()) {
      await TwilioVoice.instance.registerPhoneAccount();
      await TwilioVoice.instance.openPhoneAccountSettings();
    }
    return true;
  }

  static Future<String> _getFcmToken() async {
    return await FirebaseMessaging.instance.getToken() ?? "";
  }

  static Future<bool> makeCall({required String to}) async {
    try {
      await _requestAudioPermission();

      final String uuid = const Uuid().v4();

      // Optional: Show native UI
      CallKitParams params = CallKitParams(
        id: uuid,
        nameCaller: 'Calling $to',
        handle: to,
        type: 0, // audio
        extra: <String, dynamic>{'To': to},
        android: const AndroidParams(
          isCustomNotification: true,
          isShowCallID: true,
        ),
      );
      await FlutterCallkitIncoming.startCall(params);

      // Register the call with Twilio
      // Send request to backend to place the call
      TwilioVoiceFlutterCall twilioVoiceFlutterCall =
          await TwilioVoiceFlutter.makeCall(to: to, data: {
        'To': to,
        'to': to,
        'From': 'Calleruser', // Replace with your Twilio number or identity
        'identity': 'Calleruser',
        'from': 'Calleruser', // Replace with your Twilio number or identity
        'callType': 'audio',
        'uuid': uuid, // Use the generated UUID for the call
      });
      debugPrint("Call initiated with ID: ${twilioVoiceFlutterCall.status}");
      return true;
    } catch (e) {
      showSnackBar(e.toString());
      return false;
    }
  }

  static Future<bool?> hangUp() async {
    try {
      await TwilioVoiceFlutter.hangUp();
      // Optionally, you can also end the call in CallKit
      await FlutterCallkitIncoming.endAllCalls();
      return true; // Return true if hang up was successful
    } catch (e) {
      // Handle the exception, for example, log it or return a default value
      showSnackBar(e.toString());
      return null; // Return false if there's an error
    }
  }

  static Future<bool?> toggleMute() async {
    try {
      await TwilioVoiceFlutter.toggleMute();
      return await TwilioVoiceFlutter.isMuted();
    } catch (e) {
      // Handle the exception
      showSnackBar(e.toString());
      return null; // Return false if there's an error
    }
  }

  static Future<bool?> isMuted() async {
    try {
      return await TwilioVoiceFlutter.isMuted();
    } catch (e) {
      // Handle the exception
      showSnackBar(e.toString());
      return null; // Return false if there's an error
    }
  }

  static Future<bool?> isSpeaker() async {
    try {
      return await TwilioVoiceFlutter.isSpeaker();
    } catch (e) {
      // Handle the exception
      showSnackBar(e.toString());
      return null; // Return false if there's an error
    }
  }

  static Future<bool?> toggleSpeaker() async {
    try {
      await TwilioVoiceFlutter.toggleSpeaker();
      return await TwilioVoiceFlutter.isSpeaker();
    } catch (e) {
      showSnackBar(e.toString());
    }
    return null;
  }

  static showSnackBar(String message, [MsgStatus? msgStatus]) {
    if (appKey.currentState != null && message.isNotEmpty) {
      Color backgroundColor;
      switch (msgStatus) {
        case MsgStatus.success:
          backgroundColor = Colors.green;
          break;
        case MsgStatus.error:
          backgroundColor = Colors.red;
          break;
        case MsgStatus.warning:
        default:
          backgroundColor = Colors.black;
      }
      ScaffoldMessenger.of(appKey.currentState!.context).clearSnackBars();
      ScaffoldMessenger.of(appKey.currentState!.context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ));
    }
  }
}

enum MsgStatus { error, success, warning }
