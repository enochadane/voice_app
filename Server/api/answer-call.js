exports.handler = function (context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
    console.log("event on answer call " + JSON.stringify(event));
  // Say a message when the function is triggered
  twiml.say('Hello from your pals at Twilio! Have fun.');

  // Optionally play a sound
  // twiml.play('https://demo.twilio.com/docs/classic.mp3');

  // Return the TwiML XML
  callback(null, twiml);
};
