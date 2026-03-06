const functions = require("firebase-functions");
const axios = require("axios");
const pdfParse = require("pdf-parse");
const admin = require('firebase-admin');

admin.initializeApp();

exports.chatWithRules = functions.runWith({ timeoutSeconds: 60, memory: "1GB" }).https.onCall(async (data, context) => {
    // Security Check: Ensure user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "You must be logged in.");
    }

    const question = data.question;
    if (!question) {
        throw new functions.https.HttpsError("invalid-argument", "Question text missing.");
    }

    try {
        // 1. Fetch latest rules PDF URL from Firestore
        const doc = await admin.firestore().collection('hostel_rules').doc('latest').get();
        if (!doc.exists) {
            throw new functions.https.HttpsError("failed-precondition", "Internal Error: Warden has not uploaded rules yet.");
        }

        // 2. Fetch and Parse PDF Context
        const pdfUrl = doc.data().fileUrl;
        const response = await axios.get(pdfUrl, { responseType: 'arraybuffer' });
        const pdfData = await pdfParse(response.data);
        const fullExtractedText = pdfData.text;

        // 3. Orchestrate with OpenRouter AI
        const systemPrompt = `You are a helpful, polite Hostel Assistant for our College students.
Answer ONLY using the official hostel rules below. Never invent information.
If the answer is not in the rules, reply: "According to the current hostel rules, I don't have that information. Please contact the warden."
Rules (last updated: ${doc.data().updatedAt.toDate().toISOString()}):
${fullExtractedText}

Student question: ${question}
Keep answers short, clear, and student-friendly. Use markdown where helpful for lists/bold text.`;

        const openRouterResponse = await axios.post(
            "https://openrouter.ai/api/v1/chat/completions",
            {
                model: "meta-llama/llama-3.3-70b-instruct",
                messages: [{ role: "system", content: systemPrompt }]
            },
            {
                headers: {
                    "Authorization": `Bearer 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`,
                    "HTTP-Referer": "https://hostelapp.com",
                    "X-Title": "Hostel Management App"
                }
            }
        );

        return { reply: openRouterResponse.data.choices[0].message.content };
    } catch (error) {
        console.error("AI Node Error:", error);
        throw new functions.https.HttpsError("internal", "Processing failed.");
    }
});
