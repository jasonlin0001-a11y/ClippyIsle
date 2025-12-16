import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const Busboy = require("busboy");
const EmailReplyParser = require("node-email-reply-parser");

if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

export const receiveEmail = functions.https.onRequest((req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const busboy = Busboy({ headers: req.headers });
  const fields: { [key: string]: string } = {};

  busboy.on("field", (fieldname: string, val: string) => {
    fields[fieldname] = val;
  });

  busboy.on("finish", async () => {
    try {
      const fromLine = fields["from"] || ""; 
      const subject = fields["subject"] || "(無標題)";
      const originalText = fields["text"] || ""; 
      // 這裡原本有一行 html 的定義，已經刪除，修正 TS6133 錯誤

      const emailMatch = fromLine.match(/<(.+)>/);
      const senderEmail = emailMatch ? emailMatch[1] : fromLine.trim();

      // ★ 清洗內容 ★
      const cleanText = EmailReplyParser(originalText, true);
      const finalText = cleanText.length > 0 ? cleanText : originalText;

      console.log(`收到信件: ${senderEmail}, 清洗前長度: ${originalText.length}, 清洗後: ${finalText.length}`);

      const mappingSnap = await db.collection("email_mapping").doc(senderEmail).get();

      if (mappingSnap.exists) {
        const userId = mappingSnap.data()?.uid;
        
        await db.collection("users").doc(userId).collection("inbox").add({
          subject: subject,
          content: finalText, 
          originalContent: originalText, 
          from: senderEmail,
          receivedAt: admin.firestore.FieldValue.serverTimestamp(),
          isProcessed: false, 
          source: "email"
        });

        console.log(`✅ 已存入使用者 ${userId} 的收件匣`);
        res.status(200).send("Saved");
      } else {
        console.log(`⚠️ 找不到使用者: ${senderEmail}`);
        res.status(200).send("Ignored");
      }

    } catch (error) {
      console.error("❌ Error:", error);
      res.status(500).send("Internal Server Error");
    }
  });

  // @ts-ignore
  busboy.end(req.rawBody);
});