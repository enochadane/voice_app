require('dotenv').config();

module.exports = async (req, res) => {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Support both GET (e.g., query params) and POST (e.g., body payload)
  const event = req.method === 'GET' ? req.query : req.body;


  console.log('📞 Call Status Event Received:');
  console.log('Event Payload:', JSON.stringify(event, null, 2));

  const {
    CallSid,
    CallStatus,
    From,
    To,
    Direction,
    AnsweredBy,
    CallDuration,
  } = event;

  console.log(`CallSid: ${CallSid}`);
  console.log(`CallStatus: ${CallStatus}`);
  console.log(`From: ${From}`);
  console.log(`To: ${To}`);
  console.log(`Direction: ${Direction}`);
  console.log(`AnsweredBy: ${AnsweredBy || 'Unknown'}`);

  switch (CallStatus) {
    case 'queued':
    case 'initiated':
      console.log('🔄 Call is queued or initiated...');
      break;
    case 'ringing':
      console.log('🔔 Phone is ringing...'); // user A 
      break;
    case 'answered':
      console.log('✅ Call answered!');
      break;
    case 'in-progress':
      console.log('📞 Call is in progress...');
      break;
    case 'completed':
      console.log('✅ Call completed.');
      if (CallDuration) {
        console.log(`⏱️ Duration: ${CallDuration} seconds`);
      }
      break;
    case 'failed':
    case 'no-answer':
    case 'busy':
      console.warn(`⚠️ Call failed or not answered: ${CallStatus}`);
      break;
    default:
      console.log(`ℹ️ Call status: ${CallStatus}`);
  }

  if (AnsweredBy === 'machine_start' || AnsweredBy === 'fax') {
    console.log('🤖 Answered by machine or fax.');
  } else if (AnsweredBy === 'human') {
    console.log('👤 Answered by a human.');
  }

  return res.status(200).json({ received: true, event: event, message: 'Call event processed successfully.' });
};
