/**
 * Cloud Functions for ClippyIsle
 * 
 * Push Notification Engine for Creator Subscription System
 * Link Preview Fetcher for Open Graph metadata
 * 
 * Triggers:
 * - onCreatorPostCreated: When a new post is added to creator_posts collection,
 *   sends FCM push notification to all subscribers of that creator's topic.
 * 
 * Callable Functions:
 * - fetchLinkPreview: Fetches Open Graph metadata from a URL
 */

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const ogs = require("open-graph-scraper");

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

/**
 * Callable function: Fetches Open Graph metadata from a URL
 *
 * Input: { url: string }
 * Output: { success: true, data: { title, image, description, url } }
 *         or { success: false, error: '...' } on failure
 *
 * Usage from iOS:
 *   functions.httpsCallable("fetchLinkPreview").call(["url": urlString])
 */
exports.fetchLinkPreview = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    return {
      success: false,
      error: "User must be authenticated to fetch link previews.",
    };
  }

  const url = data.url;

  // Validate URL input
  if (!url || typeof url !== "string") {
    return {
      success: false,
      error: "The function must be called with a valid URL string.",
    };
  }

  // Validate URL format
  let parsedUrl;
  try {
    parsedUrl = new URL(url);
    // Only allow http and https protocols
    if (!["http:", "https:"].includes(parsedUrl.protocol)) {
      return {
        success: false,
        error: "URL must use http or https protocol.",
      };
    }
  } catch (error) {
    return {
      success: false,
      error: "The provided URL is not valid.",
    };
  }

  // Fetch Open Graph metadata using open-graph-scraper
  try {
    const options = {
      url: url,
      timeout: 10000, // 10 second timeout
      fetchOptions: {
        headers: {
          "user-agent": "Mozilla/5.0 (compatible; ClippyIsle/1.0; +https://ccisle.app)",
        },
      },
    };

    const {error, result} = await ogs(options);

    if (error) {
      console.error("OGS error for URL:", url, result);
      return {
        success: false,
        error: "Failed to fetch link preview metadata.",
      };
    }

    // Extract Open Graph data
    const ogData = {
      title: result.ogTitle || result.dcTitle || result.twitterTitle || null,
      image: result.ogImage?.[0]?.url || result.twitterImage?.[0]?.url || null,
      description: result.ogDescription || result.dcDescription ||
                   result.twitterDescription || null,
      url: result.ogUrl || result.requestUrl || url,
    };

    console.log("Successfully fetched OG data for:", url);

    return {
      success: true,
      data: ogData,
    };
  } catch (error) {
    console.error("Error fetching link preview for URL:", url, error);
    return {
      success: false,
      error: "An error occurred while fetching the link preview.",
    };
  }
});
