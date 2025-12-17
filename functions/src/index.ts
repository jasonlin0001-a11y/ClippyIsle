import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import * as sgMail from "@sendgrid/mail";

admin.initializeApp();

// 定義 Secret (對應你剛剛在終端機設定的名稱)
const sendgridApiKey = defineSecret("SENDGRID_API_KEY");

/**
 * Cloud Function: sendLinkToEmail (2nd Gen)
 */
export const sendLinkToEmail = onRequest(
    { secrets: [sendgridApiKey] }, // ⚠️ 關鍵：告訴 Firebase 這個函式需要用這把鑰匙
    async (req, res) => {

    // 1. CORS 設定
    res.set('Access-Control-Allow-Origin', '*');
    if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type');
        res.status(204).send('');
        return;
    }

    // 2. 請求檢查
    if (req.method !== 'POST') {
        res.status(405).send({ success: false, error: 'Method Not Allowed' });
        return;
    }

    const { email, link } = req.body;
    if (!email || !link) {
        res.status(400).send({ success: false, error: 'Missing email or link' });
        return;
    }

    try {
        // 3. 取得 API Key (直接從 Secret 讀取，不需要 config 了)
        const apiKey = sendgridApiKey.value();
        
        if (!apiKey) {
             throw new Error("SendGrid API Key not found in secrets.");
        }

        sgMail.setApiKey(apiKey);

        // 4. 寄信內容
        const msg = {
            to: email,
            from: 'no-reply@example.com', // ⚠️ 記得改成你驗證過的寄件者
            subject: 'CC ISLE: Your Shared Link',
            text: `Link: ${link}`,
            html: `
                <div style="font-family: Arial, sans-serif; padding: 20px;">
                    <h2>CC ISLE Link Share</h2>
                    <p>Here is your link:</p>
                    <p><a href="${link}" style="color: #007bff;">${link}</a></p>
                </div>
            `,
        };

        await sgMail.send(msg);
        res.status(200).send({ success: true, message: 'Email sent successfully' });

    } catch (error: any) {
        console.error("Error:", error);
        res.status(500).send({ success: false, error: error.message });
    }
});