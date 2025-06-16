const twilio = require('twilio');

module.exports = async (req, res) => {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Support both GET (e.g., query params) and POST (e.g., body payload)
  const event = req.method === 'GET' ? req.query : req.body;

  const twiml = new twilio.twiml.VoiceResponse();

  const to = event.to || event.To || event.Called;
  const from = event.from || event.From || event.Caller;

  console.log("📞 Received make-call event:", JSON.stringify(event));
  console.log(`➡️ to: ${to}, from: ${from}`);

  if (!to || !from) {
    twiml.say('Call info missing. Cannot connect.');
    res.setHeader('Content-Type', 'text/xml');
    return res.status(200).send(twiml.toString());
  }

  console.log("🔗 Bridging call to original caller...");

  const dial = twiml.dial({ callerId: from });
  dial.client(from); // Bridges back to the original caller

  res.setHeader('Content-Type', 'text/xml');
  return res.status(200).send(twiml.toString());
};
