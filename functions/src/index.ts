/**
 * Cloud Functions for Tadabbur.
 *
 * Right now this contains a single trigger: every time a new document
 * lands in the `/feedback` Firestore collection (written from the in-app
 * "Send Feedback" sheet), the function composes an email and sends it
 * to the founder address via Gmail SMTP.
 *
 * Why Gmail SMTP and not a transactional-email provider:
 *   - Volume is tiny (founder-personal feedback, not transactional).
 *   - No external account signup needed beyond a Google App Password.
 *   - Works inside a free-tier Firebase project without extra billing.
 *
 * Setup (one-time):
 *   1. Enable 2-Step Verification on the Gmail account that will send
 *      the emails (typically thetadabburapp@gmail.com).
 *   2. Generate an App Password at https://myaccount.google.com/apppasswords
 *      (label it "Tadabbur Functions").
 *   3. Store it as a Firebase secret:
 *        firebase functions:secrets:set GMAIL_APP_PASSWORD
 *      (paste the 16-character password when prompted).
 *   4. Deploy:
 *        firebase deploy --only functions
 *
 * If you ever want to change the destination address, edit
 * `feedbackDestination` below and redeploy.
 */

import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions";
import * as nodemailer from "nodemailer";

// Gmail account that sends the email. Must match the account whose
// App Password is stored in GMAIL_APP_PASSWORD.
const senderAddress = "thetadabburapp@gmail.com";

// Where feedback emails land. Same address by default — feedback comes
// to the same inbox that sends — but you could split sender vs receiver
// if you ever want to.
const feedbackDestination = "thetadabburapp@gmail.com";

const gmailAppPassword = defineSecret("GMAIL_APP_PASSWORD");

/**
 * Trigger: a new doc in `/feedback` from the in-app feedback sheet.
 * Composes a human-readable email and sends via Gmail SMTP.
 *
 * Failure mode: if SMTP rejects (wrong password, account locked, etc.),
 * the function logs the error and exits cleanly. The Firestore document
 * is still preserved, so a manual re-send is always possible from the
 * Firebase Console.
 */
export const onFeedbackCreated = onDocumentCreated(
  {
    document: "feedback/{docId}",
    secrets: [gmailAppPassword],
    region: "us-central1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      logger.warn("onFeedbackCreated: empty event data, skipping");
      return;
    }

    const data = snap.data();
    const docId = event.params.docId;

    const category = (data.category as string) ?? "general";
    const message = (data.message as string) ?? "(no message body)";
    const userId = (data.user_id as string) ?? "guest";
    const authType = (data.auth_type as string) ?? "unknown";
    const displayName = (data.display_name as string) ?? "";
    const email = (data.email as string) ?? "";
    const qfUsername = (data.qf_username as string) ?? "";
    const language = (data.language as string) ?? "?";
    const verseKey = (data.verse_key as string) ?? "?";
    const platform = (data.platform as string) ?? "?";
    const createdAt = data.created_at?.toDate?.() ?? new Date();

    // Subject line shows the most-identifying thing we have. Falls
    // back through display name → email → short uid → "guest" so a
    // glance at the inbox tells the founder who to reach out to.
    const subjectIdentity = displayName.length > 0
      ? displayName
      : email.length > 0
        ? email
        : userId === "guest"
          ? "guest"
          : userId.substring(0, 8);
    const subject = `[Tadabbur · ${category}] feedback from ${subjectIdentity}`;

    // Identity block. Only renders the lines we actually have data
    // for so the email stays clean on guest submissions instead of
    // showing a wall of empty fields.
    const identityLines: string[] = [
      `Auth method: ${authType}`,
    ];
    if (displayName) identityLines.push(`Name: ${displayName}`);
    if (email) identityLines.push(`Email: ${email}`);
    if (qfUsername) identityLines.push(`quran.com handle: ${qfUsername}`);
    identityLines.push(`Firebase UID: ${userId}`);

    // Plain-text body. Keeping it simple so it reads cleanly in any
    // mail client and doesn't trip Gmail's "view full message" cutoff.
    const body = [
      `Category: ${category}`,
      ...identityLines,
      `Language: ${language}`,
      `Verse on screen: ${verseKey}`,
      `Platform: ${platform}`,
      `Submitted: ${createdAt.toISOString()}`,
      `Document: feedback/${docId}`,
      "",
      "──────── message ────────",
      "",
      message,
      "",
      "─────────────────────────",
      "",
      email
        ? `Reply directly: ${email}`
        : `Reply-to: open Firebase Console → Firestore → feedback/${docId}`,
    ].join("\n");

    // Gmail SMTP via Nodemailer. Port 465 with TLS is the most reliable
    // path; the older 587/STARTTLS combo also works but occasionally
    // gets throttled on cold starts.
    const transporter = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 465,
      secure: true,
      auth: {
        user: senderAddress,
        pass: gmailAppPassword.value(),
      },
    });

    try {
      await transporter.sendMail({
        from: `Tadabbur Feedback <${senderAddress}>`,
        to: feedbackDestination,
        subject,
        text: body,
      });
      logger.info(`Sent feedback email for ${docId}`, {category, language});
    } catch (err) {
      // Log but don't rethrow — Firestore doc is preserved either way,
      // and rethrowing would cause Cloud Functions to retry-storm if
      // the failure is something unrecoverable like a bad password.
      logger.error(`Failed to send feedback email for ${docId}`, err);
    }
  }
);
