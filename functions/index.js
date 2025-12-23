/**
 * Cloud Functions for ClippyIsle
 * 
 * Push Notification Engine for Creator Subscription System
 * 
 * Triggers:
 * - onCreatorPostCreated: When a new post is added to creator_posts collection,
 *   sends FCM push notification to all subscribers of that creator's topic.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

/**
 * Firestore trigger: Sends push notification when a creator publishes a new post
 * 
 * Collection: creator_posts
 * Document fields:
 *   - creator_uid: String (creator's user ID)
 *   - title: String (post title)
 *   - content_url: String (link to article/content)
 *   - curator_note: String (optional review/comment)
 *   - created_at: Timestamp
 */
exports.onCreatorPostCreated = functions.firestore
    .document("creator_posts/{postId}")
    .onCreate(async (snapshot, context) => {
      const postData = snapshot.data();
      const postId = context.params.postId;

      const creatorUid = postData.creator_uid;
      const title = postData.title || "New Post";
      const contentUrl = postData.content_url;
      const curatorNote = postData.curator_note || "";

      if (!creatorUid) {
        console.error("Missing creator_uid in post:", postId);
        return null;
      }

      // Fetch creator's profile to get their name
      let creatorName = "Creator";
      try {
        const userDoc = await db.collection("users").doc(creatorUid).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          creatorName = userData.nickname || `User_${creatorUid.slice(-4)}`;
        }
      } catch (error) {
        console.error("Error fetching creator profile:", error);
      }

      // Build FCM message
      const topic = `creator_${creatorUid}`;

      // Notification body: "[Post Title] - [Curator Note]" or just "[Post Title]"
      let notificationBody = title;
      if (curatorNote && curatorNote.trim().length > 0) {
        notificationBody = `${title} - ${curatorNote}`;
      }

      const message = {
        notification: {
          title: `New update from ${creatorName}`,
          body: notificationBody,
        },
        data: {
          type: "creator_post",
          post_id: postId,
          creator_uid: creatorUid,
          url: contentUrl || "",
          title: title,
          curator_note: curatorNote,
        },
        topic: topic,
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: "default",
              "content-available": 1,
            },
          },
        },
        android: {
          notification: {
            sound: "default",
            priority: "high",
          },
        },
      };

      // Send the FCM message
      try {
        const response = await admin.messaging().send(message);
        console.log(`Successfully sent notification to topic ${topic}:`, response);
        return {success: true, messageId: response};
      } catch (error) {
        console.error("Error sending notification:", error);
        return {success: false, error: error.message};
      }
    });

/**
 * Optional: HTTP function to manually send a test notification
 * 
 * ⚠️ SECURITY WARNING: This function should be disabled or protected in production!
 * Only enable for debugging purposes with proper authentication.
 * 
 * TODO: Add Firebase Auth verification before production deployment
 */
exports.sendTestNotification = functions.https.onRequest(async (req, res) => {
  // Only allow POST requests
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  // WARNING: In production, verify the request is from an authenticated admin user
  // Example: const idToken = req.headers.authorization?.split('Bearer ')[1];
  // await admin.auth().verifyIdToken(idToken);

  const {creatorUid, title, body} = req.body;

  if (!creatorUid) {
    res.status(400).json({error: "Missing creatorUid"});
    return;
  }

  const topic = `creator_${creatorUid}`;

  const message = {
    notification: {
      title: title || "Test Notification",
      body: body || "This is a test notification",
    },
    topic: topic,
  };

  try {
    const response = await admin.messaging().send(message);
    res.json({success: true, messageId: response, topic: topic});
  } catch (error) {
    console.error("Error sending test notification:", error);
    res.status(500).json({success: false, error: error.message});
  }
});
