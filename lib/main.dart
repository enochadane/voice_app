import 'dart:async';
import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:launch_pad/twilio_voice_services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:twilio_voice_flutter/model/call.dart';
import 'package:twilio_voice_flutter/model/event.dart';
import 'package:twilio_voice_flutter/model/status.dart';
import 'package:twilio_voice_flutter/twilio_voice_flutter.dart';

import 'incoming_call.dart';

GlobalKey<NavigatorState> appKey = GlobalKey<NavigatorState>();

void setupFirebaseMessageHandlers() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print('🔔 onMessage: ${message.data}');
    // handle foreground notification
    // await showIncomingCallFromTwilioNotification(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('📲 onMessageOpenedApp: ${message.data}');
    // handle when the app is opened from background due to a notification
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  setupFirebaseMessageHandlers();
  TwilioVoiceFlutter.init();
  
  await TwilioVoiceServices.initialize();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    TwilioVoiceFlutterCall? activeCall =
        await TwilioVoiceFlutter.getActiveCall();
    debugPrint(
        "on notification opened app onMessage ${activeCall?.status} ${activeCall?.id} $message");

    if (message.data['twi_message_type'] == 'twilio.voice.call') {
      // TwilioVoiceFlutter.setForeground(true); // Ensure Twilio answers
      await showIncomingCallFromTwilioNotification(message);
    }
  });

  // FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
  //   TwilioVoiceFlutterCall? activeCall =
  //       await TwilioVoiceFlutter.getActiveCall();

  //   debugPrint(
  //       "on notification opened app ${activeCall?.status} ${activeCall?.id} $message");

  //   if (message.data['twi_message_type'] == 'twilio.voice.call') {
  //     // TwilioVoiceFlutter.setForeground(true); // Ensure Twilio answers
  //           await showIncomingCallFromTwilioNotification(message);

  //   }
  // });
  runApp(const MyApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background call notification
  log('🔔 Background Message Received: ${message.data}');

  showIncomingCallFromTwilioNotification(message);
  // TwilioVoiceFlutter.setForeground(true);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appKey,
      title: 'Twilio Voice Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isSpeaker = false;
  bool _isMuted = false;
  bool _isCalling = false;
  String _callStatus = "";

  StreamSubscription<TwilioVoiceFlutterEvent>? callEventsListener;

  final TextEditingController identifyController = TextEditingController();

  void setCallEventsListener() {
    callEventsListener = TwilioVoiceServices.callEventsListener.listen((event) {
      debugPrint("callEventsListener is Call Event: ${event.status} ${event}");
      
      switch (event.status) {
        case TwilioVoiceFlutterStatus.ringing:
          _callStatus = "Ringing...";
          break;
        case TwilioVoiceFlutterStatus.connecting:
          _callStatus = "Connecting...";
          break;
        case TwilioVoiceFlutterStatus.reconnected:
          _callStatus = "Reconnected...";
          break;
        case TwilioVoiceFlutterStatus.disconnected:
          endCall();
          break;
        case TwilioVoiceFlutterStatus.connected:
          _callStatus = "Call Connected";
          break;
        case TwilioVoiceFlutterStatus.answered:
          _callStatus = "Call Answered";
          break;
        case TwilioVoiceFlutterStatus.busy:
          _callStatus = "Call Busy";
          break;
        case TwilioVoiceFlutterStatus.failed:
          _callStatus = "Call Failed";
          break;
        default:
          _callStatus = "";
          break;
      }
      setState(() {});
    });
  }

 void setupCallKitEventListener() {
  FlutterCallkitIncoming.onEvent.listen((event) async {
    debugPrint("CallKit event received: ${event?.event}, body: ${event?.body}");

    switch (event?.event) {
      case Event.actionCallStart:
        debugPrint("Call started: ${event?.body}");
        // You can handle call start here
        break;

      case Event.actionCallIncoming:
        debugPrint("Incoming call: ${event?.body}");
        
        // You can optionally handle incoming UI logic here
        break;

      case Event.actionCallCustom:
        debugPrint("Custom action: ${event?.body}");
        break;

      case Event.actionCallAccept:
        final data = event?.body['extra'];
        final bridgeToken = data['bridgeToken'];
        final callSid = data['callSid'];

        debugPrint("Call accepted with data: $data");

        try {
          await Permission.microphone.request();
          await TwilioVoice.instance.call.answer();
          debugPrint("Call answered successfully");

          setState(() {
            _isCalling = true;
            _callStatus = "Call Accepted";
          });

          // Optionally: navigate to in-call screen here

        } catch (e) {
          debugPrint('Error answering call: $e');
        }

        break;

      case Event.actionCallDecline:
        debugPrint("Call declined: ${event?.body}");
        // End or clean up the call here if needed
        break;

      case Event.actionCallEnded:
        debugPrint("Call ended: ${event?.body}");
        // Clean up call state
        break;

      default:
        debugPrint("Unhandled event: ${event?.event}");
        break;
    }
  });
}


  @override
  void initState() {
    setupCallKitEventListener();
    setCallEventsListener();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Twilio Voice Call Example"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextField(
              controller: identifyController,
              decoration: InputDecoration(
                  hintText: "Enter call identifier", enabled: !_isCalling),
            ),
            const Spacer(),
            Text(
              _callStatus,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: () {
                    toggleSpeaker();
                  },
                  icon: _isMuted
                      ? const Icon(
                          Icons.mic,
                          size: 30,
                        )
                      : const Icon(
                          Icons.mic_off_rounded,
                          size: 30,
                        ),
                ),
                const SizedBox(
                  width: 15,
                ),
                Theme(
                  data: ThemeData(
                      iconButtonTheme: IconButtonThemeData(
                          style: ButtonStyle(
                              backgroundColor: WidgetStatePropertyAll(
                                  _isCalling ? Colors.red : Colors.green)))),
                  child: IconButton.filled(
                    color: Colors.white,
                    onPressed: ()async {
                      //  setState(() {
                      //     _isCalling = !_isCalling;
                      //   endCall();
                      //  });
                      //  return;

                   
                      debugPrint("_isCalling $_isCalling");
                      if (!_isCalling) {
                        makeCall(identifyController.text);
                      } else {
                        endCall();
                      }
                    },
                    icon: _isCalling
                        ? const Icon(
                            Icons.call_end,
                            size: 30,
                          )
                        : const Icon(
                            Icons.call,
                            size: 30,
                          ),
                  ),
                ),
                const SizedBox(
                  width: 15,
                ),
                IconButton.filled(
                    onPressed: () {
                      toggleSpeaker();
                    },
                    icon: _isSpeaker
                        ? const Icon(
                            CupertinoIcons.speaker_fill,
                            size: 30,
                          )
                        : const Icon(
                            CupertinoIcons.speaker_slash_fill,
                            size: 30,
                          )),
              ],
            )
          ],
        ),
      ),
    );
  }

  void endCall() async {
    var info = await TwilioVoiceServices.hangUp();

    debugPrint("statement: $info");
    setState(() {
      _isCalling = false;
      _callStatus = "";
    });
  }

  void makeCall(String identify) async {
    setState(() {
      _isCalling = true;
    });
    final status = await TwilioVoiceServices.makeCall(to: identify);
    if (!status) {
      setState(() {
        _isCalling = false;
      });
    }
  }

  toggleSpeaker() async {
    _isSpeaker = await TwilioVoiceServices.toggleSpeaker() ?? _isSpeaker;
    setState(() {});
  }

  toggleMuted() async {
    _isMuted = await TwilioVoiceServices.toggleMute() ?? _isMuted;
    setState(() {});
  }
}
