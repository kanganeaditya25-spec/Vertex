const webpush = require('web-push');
const { db, getSetting, setSetting } = require('../db/database');

let vapidKeysInitialized = false;

function initVapidKeys() {
  if (vapidKeysInitialized) return;

  let publicKey = getSetting('vapid_public_key');
  let privateKey = getSetting('vapid_private_key');

  if (!publicKey || !privateKey) {
    const keys = webpush.generateVAPIDKeys();
    publicKey = keys.publicKey;
    privateKey = keys.privateKey;
    setSetting('vapid_public_key', publicKey);
    setSetting('vapid_private_key', privateKey);
    console.log('[Push] Generated new VAPID keys');
  }

  webpush.setVapidDetails(
    'mailto:productivity@localhost',
    publicKey,
    privateKey
  );

  vapidKeysInitialized = true;
}

function getPublicKey() {
  initVapidKeys();
  return getSetting('vapid_public_key');
}

async function sendNotification(subscription, payload) {
  initVapidKeys();
  try {
    const sub = typeof subscription === 'string' ? JSON.parse(subscription) : subscription;
    await webpush.sendNotification(sub, JSON.stringify(payload));
    return true;
  } catch (error) {
    console.error('[Push] Send failed:', error.statusCode || error.message);
    // Remove invalid subscriptions (410 = gone, 404 = not found)
    if (error.statusCode === 410 || error.statusCode === 404) {
      const subStr = typeof subscription === 'string' ? subscription : JSON.stringify(subscription);
      db.prepare('DELETE FROM push_subscriptions WHERE subscription = ?').run(subStr);
      console.log('[Push] Removed invalid subscription');
    }
    return false;
  }
}

async function broadcastNotification(payload) {
  initVapidKeys();
  const subs = db.prepare('SELECT * FROM push_subscriptions').all();
  const results = await Promise.allSettled(
    subs.map(sub => sendNotification(sub.subscription, payload))
  );
  const sent = results.filter(r => r.status === 'fulfilled' && r.value).length;
  console.log(`[Push] Broadcast to ${sent}/${subs.length} subscribers`);
  return sent;
}

module.exports = { initVapidKeys, getPublicKey, sendNotification, broadcastNotification };
