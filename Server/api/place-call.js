require('dotenv').config();
const twilio = require('twilio');

module.exports = async (req, res) => {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const PUBLIC_HOST = process.env.PUBLIC_HOST || 'twilio-voice-server-mu.vercel.app';
  const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
  console.log("🔧 PUBLIC_HOST is:", PUBLIC_HOST);
  const event = req.method === 'GET' ? req.query : req.body;
  const to = (event.to || event.To || '').trim();
  const from = (event.from || event.From || '').trim();

  if (!to || !from) {
    return res.status(400).json({ error: 'Missing "to" or "from" parameters' });
  }

  // create a call with the Twilio client 


  const callOptions = {
    from: `client:${from}`,
    to: `client:${to}`,
    timeout: 60,
    // twimlApplicationSid: process.env.TWILIO_TWIML_APP_SID, // <-- THIS!
    statusCallback: `https://${PUBLIC_HOST}/api/call-events`,
    url: `https://${PUBLIC_HOST}/api/make-call`,
    statusCallbackMethod: 'POST',
    statusCallbackEvent: ['initiated', 'ringing', 'answered', 'completed'],
    answerOnBridge: true,
  };

  try {
    console.log("☎️ Calling with options:", callOptions);
    const result = await client.calls.create(callOptions);
    console.log("✅ Call initiated:", result.sid);
    res.status(200).json({ success: true, result: result });
  } catch (err) {
    console.error("❌ Call failed:", err.message);
    res.status(500).json({ error: err.message });
  }
};

