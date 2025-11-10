const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Example Cloud Function skeleton: send FCM to a topic
exports.sendTopicNotification = functions.https.onRequest(async (req, res) => {
  const topic = req.query.topic || 'general';
  const message = {
    notification: {
      title: 'Test Notification',
      body: 'This is a test message from Cloud Functions',
    },
    topic,
  };
  try {
    const r = await admin.messaging().send(message);
    res.status(200).send({result: r});
  } catch (e) {
    res.status(500).send({error: e.toString()});
  }
});
