/**
 * Cloud Functions for ClippyIsle
<<<<<<< HEAD
 * 1. Push Notification Engine (onCreatorPostCreated)
 * 2. Manual Link Preview Fetcher (fetchLinkPreview)
 * 3. Auto Metadata Scraper (fetchLinkMetadata) - V3.0 Deep Mining
=======
 *
 * Push Notification Engine for Creator Subscription System
 * Link Preview Fetcher for Open Graph metadata
 *
 * Triggers:
 * - onCreatorPostCreated: When a new post is added to creator_posts collection,
 *   sends FCM push notification to all subscribers of that creator's topic.
 * - fetchLinkMetadata: When a new post is created, automatically fetches and
 *   populates link metadata (title, description, image, domain) from the URL.
 *
 * Callable Functions:
 * - fetchLinkPreview: Fetches Open Graph metadata from a URL
>>>>>>> copilot/create-firebase-function-scrape-metadata
 */

const functions = require("firebase-functions/v1");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const axios = require("axios");
const cheerio = require("cheerio");
const logger = require("firebase-functions/logger");

admin.initializeApp();
const db = admin.firestore();

<<<<<<< HEAD
// --- 全域設定 ---
const USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const MAX_DESCRIPTION_LENGTH = 200;
=======
// Constants
const MAX_DESCRIPTION_LENGTH = 200;
const GOOGLEBOT_USER_AGENT = "Mozilla/5.0 (compatible; Googlebot/2.1; " +
    "+http://www.google.com/bot.html)";
>>>>>>> copilot/create-firebase-function-scrape-metadata

/**
 * ============================================================
 * 1. 推播通知引擎 (維持原樣)
 * ============================================================
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

    if (!creatorUid) return null;

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

    const topic = `creator_${creatorUid}`;
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
    };

    try {
      await admin.messaging().send(message);
      return { success: true };
    } catch (error) {
      return { success: false, error: error.message };
    }
  });

/**
 * ============================================================
 * 2. 測試通知 API (維持原樣)
 * ============================================================
 */
exports.sendTestNotification = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }
  const { creatorUid, title, body } = req.body;
  const topic = `creator_${creatorUid}`;
  const message = {
    notification: {
      title: title || "Test Notification",
      body: body || "Test Body",
    },
    topic: topic,
  };
  try {
    const response = await admin.messaging().send(message);
    res.json({ success: true, messageId: response });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
<<<<<<< HEAD
 * ============================================================
 * 3. 前端呼叫的預覽 API (維持原樣)
 * ============================================================
=======
 * Firestore trigger: Fetches link metadata when a new creator post is created
 *
 * Collection: creator_posts
 * This function automatically populates link metadata for new posts:
 *   - link_title: From og:title or <title> tag
 *   - link_description: From og:description or meta description (max 200 chars)
 *   - link_image: From og:image
 *   - link_domain: Extracted hostname from URL
 *
 * Skips execution if link_title or link_image are already present.
 */
exports.fetchLinkMetadata = functions.firestore
    .document("creator_posts/{postId}")
    .onCreate(async (snapshot, context) => {
      const postData = snapshot.data();
      const postId = context.params.postId;

      // Validation: Check if content_url exists
      const contentUrl = postData.content_url;
      if (!contentUrl || typeof contentUrl !== "string") {
        console.log(`Post ${postId}: No content_url found, skipping metadata fetch`);
        return null;
      }

      // Skip if metadata is already present (e.g., from Web Portal)
      if (postData.link_title || postData.link_image) {
        console.log(`Post ${postId}: Metadata already present, skipping fetch`);
        return null;
      }

      // Extract domain from URL
      let domain = "";
      let parsedUrl;
      try {
        parsedUrl = new URL(contentUrl);
        domain = parsedUrl.hostname;
        // Only allow http and https protocols
        if (!["http:", "https:"].includes(parsedUrl.protocol)) {
          console.error(`Post ${postId}: Invalid protocol ${parsedUrl.protocol}`);
          await snapshot.ref.update({link_title: domain || "Link"});
          return null;
        }
      } catch (error) {
        console.error(`Post ${postId}: Invalid URL - ${contentUrl}`);
        await snapshot.ref.update({link_title: "Link"});
        return null;
      }

      // Fetch HTML and parse Open Graph metadata
      try {
        const response = await axios.get(contentUrl, {
          timeout: 10000, // 10 second timeout
          headers: {
            "User-Agent": GOOGLEBOT_USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
          },
          maxRedirects: 5,
          validateStatus: (status) => status >= 200 && status < 400,
        });

        const html = response.data;
        const $ = cheerio.load(html);

        // Extract Open Graph metadata with fallbacks
        let linkTitle = $("meta[property=\"og:title\"]").attr("content") ||
                        $("title").text() ||
                        null;

        let linkDescription = $("meta[property=\"og:description\"]").attr("content") ||
                              $("meta[name=\"description\"]").attr("content") ||
                              null;

        const linkImage = $("meta[property=\"og:image\"]").attr("content") || null;

        // Data cleaning
        // Truncate description to MAX_DESCRIPTION_LENGTH characters
        if (linkDescription && linkDescription.length > MAX_DESCRIPTION_LENGTH) {
          linkDescription = linkDescription.substring(0, MAX_DESCRIPTION_LENGTH - 3) + "...";
        }

        // Ensure title is not empty (default to domain name)
        if (!linkTitle || linkTitle.trim().length === 0) {
          linkTitle = domain;
        } else {
          linkTitle = linkTitle.trim();
        }

        if (linkDescription) {
          linkDescription = linkDescription.trim();
        }

        // Update Firestore document with metadata
        const updateData = {
          link_title: linkTitle,
          link_domain: domain,
        };

        if (linkDescription) {
          updateData.link_description = linkDescription;
        }

        if (linkImage) {
          updateData.link_image = linkImage.trim();
        }

        await snapshot.ref.update(updateData);

        console.log(`Post ${postId}: Successfully fetched metadata for ${contentUrl}`);
        return {success: true, postId: postId};
      } catch (error) {
        console.error(`Post ${postId}: Error fetching metadata - ${error.message}`);
        // On error, set link_title to domain name so App stops waiting
        await snapshot.ref.update({
          link_title: domain || "Link",
          link_domain: domain,
        });
        return {success: false, error: error.message};
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
>>>>>>> copilot/create-firebase-function-scrape-metadata
 */
exports.fetchLinkPreview = functions.https.onCall(async (data, context) => {
  if (!context.auth) return { success: false, error: "Auth required." };
  const url = data.url;
  if (!url) return { success: false, error: "Invalid URL." };

  try {
    const response = await axios.get(url, {
      timeout: 10000,
      headers: {
        "User-Agent": USER_AGENT,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      },
    });

    const html = response.data;
    const $ = cheerio.load(html);

    const getMeta = (prop) => (
      $(`meta[property="${prop}"]`).attr("content") ||
      $(`meta[name="${prop}"]`).attr("content") ||
      null
    );

    const ogData = {
      title: (getMeta("og:title") || $("title").text() || "").trim(),
      image: (getMeta("og:image") || "").trim(),
      description: (getMeta("og:description") || "").trim(),
      url: (getMeta("og:url") || url).trim(),
    };

    return { success: true, data: ogData };
  } catch (error) {
    return { success: false, error: "Failed to fetch preview." };
  }
});

/**
 * ============================================================
 * 4. [新功能 V3.0] 後端自動爬蟲 (深層挖掘版)
 * 加入 Regex 暴力搜尋，解決 Threads/IG 隱藏文字的問題
 * ============================================================
 */
exports.fetchLinkMetadata = onDocumentCreated("creator_posts/{postId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const data = snapshot.data();
  const url = data.content_url;

  // 即使之前爬過了，如果描述是空的，我們再給它一次機會
  if (!url) return;
  if (data.link_title && data.link_image && data.link_description && data.link_description.length > 5) {
    return;
  }

  try {
    logger.log(`Fetching metadata V3 (Deep Mine) for: ${url}`);

    const response = await axios.get(url, {
      headers: {
        'User-Agent': USER_AGENT,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        'Referer': 'https://www.google.com/',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'cross-site',
        'Upgrade-Insecure-Requests': '1'
      },
      timeout: 15000 // 延長一點時間
    });

    const html = response.data; // 原始 HTML 字串
    const $ = cheerio.load(html);

    const getMeta = (prop) => (
      $(`meta[property="${prop}"]`).attr("content") ||
      $(`meta[name="${prop}"]`).attr("content") ||
      ""
    );

    // 1. 基本抓取
    let title = getMeta("og:title") || $("title").text() || "";
    let image = getMeta("og:image") || getMeta("twitter:image");
    let description = getMeta("og:description") || getMeta("description") || "";

    // 2. [V3 核心] 暴力破解：在原始碼中搜尋隱藏的文字
    // 許多 React 網站會把資料放在 JSON 字串裡
    if (!description || description.length < 5) {
        
        // 嘗試從 Threads/IG 特有的 JSON 結構中抓取
        // 尋找 "description":"..." 或 "caption":"..." 或 "text":"..."
        const patterns = [
            /"description"\s*:\s*"([^"]{10,300})"/, // 抓 description 欄位
            /"caption"\s*:\s*"([^"]{10,300})"/,     // 抓 caption 欄位
            /"text"\s*:\s*"([^"]{10,300})"/         // 抓 text 欄位
        ];

        for (const pattern of patterns) {
            const match = html.match(pattern);
            if (match && match[1]) {
                // 解碼 Unicode (例如 \u0026 -> &)
                try {
                    const rawText = JSON.parse(`"${match[1]}"`); 
                    // 排除掉像 "View on Threads" 這種無意義的系統預設字
                    if (!rawText.includes("View on Threads") && !rawText.includes("Log in")) {
                         description = rawText;
                         logger.log(`Found description via Regex: ${description.substring(0, 30)}...`);
                         break;
                    }
                } catch (e) {
                    // 如果 JSON 解析失敗，就直接用抓到的字
                    description = match[1];
                }
            }
        }
    }

    // 3. 網域處理
    let domain = "";
    try {
      domain = new URL(url).hostname.replace("www.", "");
      if (!title) title = domain;
    } catch (e) {
      domain = "Link";
    }

    // 4. 裁切與防呆
    if (description && description.length > MAX_DESCRIPTION_LENGTH) {
      description = description.substring(0, MAX_DESCRIPTION_LENGTH) + "...";
    }
    
    // 如果標題被設為預設的 "Threads" 或 "Login"，試著用 domain 代替
    if (title.includes("Login") || title === "Threads") {
        title = `Post on ${domain}`;
    }

    // 寫回資料庫
    await snapshot.ref.update({
      link_title: title.trim(),
      link_description: description ? description.trim() : "", // 確保不是 null
      link_image: image || "",
      link_domain: domain,
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    });

    logger.log(`Metadata V3 updated for ${url}`);

  } catch (error) {
    logger.error("Error fetching metadata:", error.message);
  }
});