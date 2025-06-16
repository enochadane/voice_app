const twilio = require('twilio');

const PUBLIC_HOST = 'twilio-voice-server-mu.vercel.app';
const callerNumber = '+13802200524';
function isNumber(to) {
  if (typeof to !== 'string') return false;
  const cleaned = to.replace(/\s+/g, '');
  return /^[+]*\d{7,15}$/.test(cleaned); // E.164 basic check
}

module.exports = async (req, res) => {
  if (req.method !== 'GET' && req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const event = req.method === 'GET' ? req.query : req.body;
  const to = (event.to || event.To || event.Called || '').trim().replace("client:", "");
  const from = (event.from || event.From || '').trim().replace("client:", "");

  console.log("🔧 PUBLIC_HOST is:", PUBLIC_HOST);
  console.log("📞 Incoming call request:", { to, from })
  console.log("📞 Caller number is:", callerNumber)
  console.log("📞 Request method is:", req.method)
  console.log("📞 Request body is:", req.body);

  const twiml = new twilio.twiml.VoiceResponse();

  if (!to) {
    twiml.say('No destination provided. Goodbye!');
    res.setHeader('Content-Type', 'text/xml');
    return res.status(200).send(twiml.toString());
  }

  if (isNumber(to)) {
    const dial = twiml.dial({ callerId: callerNumber });
    dial.number(to);
  } else {
    const dial = twiml.dial(
      {
        action: `https://${PUBLIC_HOST}/api/call-events`,
        method: 'POST',
        statusCallback: `https://${PUBLIC_HOST}/api/call-events`,
        statusCallbackMethod: 'POST',
        statusCallbackEvent: ['initiated', 'ringing', 'answered', 'completed'],
        timeout: 60,
      }
    );

    dial.client(to);

  }


  console.log("📞 Generated TwiML:", twiml.toString());
  res.setHeader('Content-Type', 'text/xml');
  return res.status(200).send(twiml.toString());
};
