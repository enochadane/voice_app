const twilio = require('twilio');

module.exports = async (req, res) => {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Support both GET (e.g., query params) and POST (e.g., body payload)
  const event = req.method === 'GET' ? req.query : req.body;

  console.log('📞 Dial completed — action URL hit');
  console.log('CallSid:', event.DialCallSid);
  console.log('DialCallStatus:', event.DialCallStatus); // completed, busy, failed, no-answer
  console.log('DialCallDuration:', event.DialCallDuration);

  const VoiceResponse = twilio.twiml.VoiceResponse;
  const twiml = new VoiceResponse();

  if (event.DialCallStatus === 'completed') {
    twiml.say('Thank you for your call.');
  } else {
    twiml.say('Sorry, the person you are trying to reach is unavailable.');
  }

  res.setHeader('Content-Type', 'text/xml');
  return res.status(200).send(twiml.toString());
};
