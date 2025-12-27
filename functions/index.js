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
const axios = require("axios");
const cheerio = require("cheerio");

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

  // Fetch HTML and parse Open Graph metadata using axios and cheerio
  try {
    const response = await axios.get(url, {
      timeout: 10000, // 10 second timeout
      headers: {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
          "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
      },
      maxRedirects: 5,
      validateStatus: (status) => status >= 200 && status < 400,
    });

    const html = response.data;
    const $ = cheerio.load(html);

    // Extract Open Graph metadata with fallbacks
    const ogTitle = $("meta[property=\"og:title\"]").attr("content") ||
                    $("meta[name=\"twitter:title\"]").attr("content") ||
                    $("title").text() ||
                    null;

    const ogDescription = $("meta[property=\"og:description\"]").attr("content") ||
                          $("meta[name=\"twitter:description\"]").attr("content") ||
                          $("meta[name=\"description\"]").attr("content") ||
                          null;

    const ogImage = $("meta[property=\"og:image\"]").attr("content") ||
                    $("meta[name=\"twitter:image\"]").attr("content") ||
                    $("meta[name=\"twitter:image:src\"]").attr("content") ||
                    null;

    const ogUrl = $("meta[property=\"og:url\"]").attr("content") ||
                  $("link[rel=\"canonical\"]").attr("href") ||
                  url;

    const ogData = {
      title: ogTitle ? ogTitle.trim() : null,
      image: ogImage ? ogImage.trim() : null,
      description: ogDescription ? ogDescription.trim() : null,
      url: ogUrl ? ogUrl.trim() : url,
    };

    console.log("Successfully fetched OG data for:", url);

    return {
      success: true,
      data: ogData,
    };
  } catch (error) {
    console.error("Error fetching link preview for URL:", url, error.message);
    return {
      success: false,
      error: "An error occurred while fetching the link preview.",
    };
  }
});
