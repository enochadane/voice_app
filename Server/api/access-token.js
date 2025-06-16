const twilio = require('twilio');

module.exports = async (req, res) => {
  const identity =
    req.query.identity ||
    req.body?.identity ||
    req.headers['x-identity'] ||
    'default_identity';

  const AccessToken = twilio.jwt.AccessToken;

  const VoiceGrant = AccessToken.VoiceGrant;

  const {
    TWILIO_ACCOUNT_SID,
    TWILIO_API_KEY,
    TWILIO_API_SECRET,
    TWILIO_TWIML_APP_SID,
    TWILIO_PUSH_CREDENTIAL_SID,
  } = process.env;

  if (
    !TWILIO_ACCOUNT_SID ||
    !TWILIO_API_KEY ||
    !TWILIO_API_SECRET ||
    !TWILIO_TWIML_APP_SID ||
    !TWILIO_PUSH_CREDENTIAL_SID
  ) {
    return res.status(500).json({ error: 'Missing environment variables.' });
  }

  const token = new AccessToken(
    TWILIO_ACCOUNT_SID,
    TWILIO_API_KEY,
    TWILIO_API_SECRET,
    {
      identity: identity,
      ttl: 3600, // Token valid for 1 hour
      region: 'us1', // Adjust region as needed
    }
  );

  const voiceGrant = new VoiceGrant(
    identity,
    {
      outgoingApplicationSid: TWILIO_TWIML_APP_SID,
      incomingAllow: true,
      pushCredentialSid: TWILIO_PUSH_CREDENTIAL_SID,
      region: 'us1',
      outgoingApplicationParams: {
        url: `https://${process.env.PUBLIC_HOST || 'twilio-voice-server-mu.vercel.app'}/api/make-call`,
        method: 'POST',
        statusCallback: `https://${process.env.PUBLIC_HOST || 'twilio-voice-server-mu.vercel.app'}/api/call-events`,
        statusCallbackMethod: 'POST',
        statusCallbackEvent: ['initiated', 'ringing', 'answered', 'completed'],
      },
    });

  token.addGrant(voiceGrant);
  token.region('us1'); // Adjust region as needed
  token.identity(identity); // Set the identity for the token
  token.ttl(3600); // Token valid for 1 hour
  token.pushCredentialSid(TWILIO_PUSH_CREDENTIAL_SID); // Set push credential SID
  token.outgoingApplicationSid(TWILIO_TWIML_APP_SID); // Set TwiML application SID for outgoing calls
  token.outgoingApplicationParams({
    url: `https://${process.env.PUBLIC_HOST || 'twilio-voice-server-mu.vercel.app'}/api/make-call`,
    method: 'POST',
    statusCallback: `https://${process.env.PUBLIC_HOST || 'twilio-voice-server-mu.vercel.app'}/api/call-events`,
    statusCallbackMethod: 'POST',
    statusCallbackEvent: ['initiated', 'ringing', 'answered', 'completed'],
  });
  console.log("🔧 Generated Access Token for identity:", identity);

  return res.status(200).json({ token: token.toJwt(), identity });
};
