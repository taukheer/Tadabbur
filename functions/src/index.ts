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
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions";
import {getApps, initializeApp} from "firebase-admin/app";
import {getAuth, UpdateRequest} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {createRemoteJWKSet, jwtVerify, JWTPayload} from "jose";
import * as nodemailer from "nodemailer";

if (getApps().length === 0) {
  initializeApp();
}

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

// =============================================================================
// Quran.com identity backfill
// =============================================================================

/**
 * The app signs every install into Firebase anonymously — Firestore's
 * rules need a real `request.auth`, and a QF OAuth flow can't mint a
 * Firebase credential on its own. The consequence is that the Firebase
 * Auth console shows every account as "(anonymous)" with no identifier
 * and no provider, even for users who did sign in with Quran.com.
 *
 * This callable closes that gap. The client hands over the OIDC
 * id_token it received from QF; we verify it properly and then stamp
 * the email / name / avatar onto the *existing* anonymous account via
 * the Admin SDK.
 *
 * Deliberately keeps the anonymous UID. Every Firestore document the
 * app writes is keyed by it (`/users/{uid}` plus journal and bookmark
 * subcollections), so minting a new UID from the QF `sub` would orphan
 * all existing user data. Updating in place costs nothing and keeps the
 * console readable.
 *
 * Setup (one-time):
 *   firebase functions:secrets:set QF_CLIENT_ID
 *   firebase deploy --only functions:linkQfIdentity
 */

const qfIssuer = "https://oauth2.quran.foundation";

/**
 * QF's public signing keys. Module scope so warm instances reuse the
 * cached key set instead of refetching JWKS on every invocation; `jose`
 * handles the cache lifetime and key rotation internally.
 */
const qfJwks = createRemoteJWKSet(
  new URL(`${qfIssuer}/.well-known/jwks.json`)
);

// The OAuth client the id_token must be issued for. Verifying `aud`
// against it is what stops a caller from replaying a token minted for
// some other application.
const qfClientId = defineSecret("QF_CLIENT_ID");

/**
 * Builds a display name from QF's claims, mirroring the client's
 * `_parseIdToken`. Per QF support, a user who never set a name has only
 * `sub` and `email` on the token, so this can legitimately come back
 * undefined.
 */
function displayNameFrom(payload: JWTPayload): string | undefined {
  const str = (key: string): string | undefined => {
    const v = payload[key];
    return typeof v === "string" && v.length > 0 ? v : undefined;
  };

  const full = [str("first_name"), str("last_name")]
    .filter((s): s is string => Boolean(s))
    .join(" ");

  return (
    (full.length > 0 ? full : undefined) ??
    str("name") ??
    str("preferred_username") ??
    str("given_name")
  );
}

/** Admin SDK rejects a malformed photoURL outright, so validate first. */
function photoUrlFrom(payload: JWTPayload): string | undefined {
  const picture = payload["picture"];
  if (typeof picture !== "string" || picture.length === 0) return undefined;
  try {
    new URL(picture);
    return picture;
  } catch {
    return undefined;
  }
}

export const linkQfIdentity = onCall(
  {secrets: [qfClientId], region: "us-central1"},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "Must be signed in to Firebase before linking a Quran.com identity."
      );
    }

    const idToken = (request.data ?? {}).idToken;
    if (typeof idToken !== "string" || idToken.length === 0) {
      throw new HttpsError("invalid-argument", "idToken is required.");
    }

    // Full verification — signature, issuer, audience, expiry. Without
    // this the endpoint would let any signed-in client claim any email
    // address, since the caller controls the token body.
    let payload: JWTPayload;
    try {
      ({payload} = await jwtVerify(idToken, qfJwks, {
        issuer: qfIssuer,
        audience: qfClientId.value(),
      }));
    } catch (err) {
      logger.warn("linkQfIdentity: id_token failed verification", {
        uid,
        error: String(err),
      });
      throw new HttpsError(
        "permission-denied",
        "Quran.com token failed verification."
      );
    }

    const email = typeof payload.email === "string" && payload.email.length > 0
      ? payload.email
      : undefined;
    const displayName = displayNameFrom(payload);
    const photoURL = photoUrlFrom(payload);

    const update: UpdateRequest = {};
    if (email) update.email = email;
    if (displayName) update.displayName = displayName;
    if (photoURL) update.photoURL = photoURL;

    if (Object.keys(update).length === 0) {
      logger.info("linkQfIdentity: token carried no profile claims", {uid});
      return {linked: false, reason: "no-claims"};
    }

    try {
      await getAuth().updateUser(uid, update);
      logger.info("linkQfIdentity: linked", {uid, hasEmail: Boolean(email)});
      return {linked: true, emailLinked: Boolean(email)};
    } catch (err) {
      const code = (err as {code?: string}).code;

      // Expected whenever someone reinstalls or adds a second device:
      // anonymous accounts are per-install, so an earlier account
      // already holds this email. Firebase requires emails to be
      // unique, so keep the name and avatar and leave the email on the
      // older account rather than failing the whole call.
      if (code === "auth/email-already-exists") {
        delete update.email;
        if (Object.keys(update).length > 0) {
          await getAuth().updateUser(uid, update);
        }
        logger.info("linkQfIdentity: email already on another account", {uid});
        return {linked: true, emailLinked: false, reason: "email-taken"};
      }

      logger.error("linkQfIdentity: updateUser failed", {uid, error: String(err)});
      throw new HttpsError("internal", "Could not link Quran.com identity.");
    }
  }
);

// =============================================================================
// Quran.com sign-in (custom token)
// =============================================================================

/**
 * Exchanges a verified Quran.com id_token for a Firebase custom token
 * keyed on the QF `sub`, so one human maps to exactly one Firebase
 * account for good.
 *
 * Supersedes {@link linkQfIdentity}, which could only stamp an email
 * onto whatever anonymous account the current install happened to
 * create. Anonymous accounts are per-install, and Firebase requires
 * emails to be unique — so every reinstall stranded the address on a
 * dead account and left the live one blank. Deriving the UID from the
 * QF identity removes that failure mode entirely.
 *
 * `linkQfIdentity` is intentionally left deployed so clients running
 * the previous build keep working.
 *
 * Because switching UIDs would otherwise orphan the user's data, the
 * caller passes the anonymous UID it is leaving behind and this
 * function migrates `/users/{previousUid}` — document plus `journal`
 * and `bookmarks` subcollections — across before handing back a token.
 * The Admin SDK bypasses security rules, which is why this has to
 * happen server-side: after the switch the client can no longer read
 * its own former document.
 */

/** Namespaced so a QF-derived UID can never collide with an anonymous one. */
function qfUid(sub: string): string {
  return `qf_${sub}`;
}

/**
 * Frees an email held by a stranded anonymous account.
 *
 * Only ever deletes an account with no provider records and no email
 * password — i.e. an abandoned anonymous install. Anything with a real
 * sign-in method is left untouched and the email is simply skipped.
 */
async function reclaimEmail(email: string, targetUid: string): Promise<boolean> {
  try {
    const holder = await getAuth().getUserByEmail(email);
    if (holder.uid === targetUid) return true;
    if (holder.providerData.length > 0 || holder.passwordHash) {
      logger.warn("reclaimEmail: held by a real account, skipping", {
        holder: holder.uid,
      });
      return false;
    }
    await getAuth().deleteUser(holder.uid);
    logger.info("reclaimEmail: freed from stranded anonymous account", {
      freedFrom: holder.uid,
      targetUid,
    });
    return true;
  } catch (err) {
    if ((err as {code?: string}).code === "auth/user-not-found") return true;
    logger.warn("reclaimEmail failed", {error: String(err)});
    return false;
  }
}

/**
 * The subset of profile fields we set. Deliberately narrower than
 * UpdateRequest so the same object is valid for both updateUser and
 * createUser — the two request types diverge on multi-factor settings.
 */
type QfProfile = {email?: string; displayName?: string; photoURL?: string};

/** Create or update the QF-keyed account, tolerating email collisions. */
async function ensureQfUser(uid: string, profile: QfProfile): Promise<void> {
  const auth = getAuth();

  const attempt = async (props: QfProfile): Promise<void> => {
    try {
      await auth.getUser(uid);
      await auth.updateUser(uid, props);
    } catch (err) {
      if ((err as {code?: string}).code !== "auth/user-not-found") throw err;
      await auth.createUser({uid, ...props});
    }
  };

  try {
    await attempt(profile);
  } catch (err) {
    if ((err as {code?: string}).code !== "auth/email-already-exists") throw err;
    const freed = profile.email
      ? await reclaimEmail(profile.email, uid)
      : false;
    if (freed) {
      await attempt(profile);
    } else {
      // Keep the name and avatar rather than failing sign-in outright.
      const {email, ...rest} = profile;
      void email;
      await attempt(rest);
    }
  }
}

/**
 * Copy a departing anonymous account's Firestore data onto the
 * QF-keyed document. Idempotent: documents keep their ids and the
 * source is stamped `migrated_to` so a repeat call is a no-op.
 */
async function migrateUserData(
  fromUid: string,
  toUid: string
): Promise<boolean> {
  const db = getFirestore();
  const fromDoc = db.collection("users").doc(fromUid);
  const snap = await fromDoc.get();
  if (!snap.exists) return false;
  if (snap.get("migrated_to")) return false;

  const toDoc = db.collection("users").doc(toUid);
  const data = snap.data() ?? {};
  // merge:true so a device that already wrote under the QF uid keeps
  // its newer values instead of being overwritten by the old doc.
  await toDoc.set(data, {merge: true});

  for (const sub of ["journal", "bookmarks"]) {
    const docs = await fromDoc.collection(sub).get();
    let batch = db.batch();
    let pending = 0;
    for (const d of docs.docs) {
      batch.set(toDoc.collection(sub).doc(d.id), d.data(), {merge: true});
      pending++;
      if (pending === 400) {
        await batch.commit();
        batch = db.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
    logger.info(`migrateUserData: copied ${docs.size} ${sub}`, {fromUid, toUid});
  }

  await fromDoc.set({migrated_to: toUid}, {merge: true});
  return true;
}

export const signInWithQf = onCall(
  {secrets: [qfClientId], region: "us-central1"},
  async (request) => {
    const idToken = (request.data ?? {}).idToken;
    if (typeof idToken !== "string" || idToken.length === 0) {
      throw new HttpsError("invalid-argument", "idToken is required.");
    }

    let payload: JWTPayload;
    try {
      ({payload} = await jwtVerify(idToken, qfJwks, {
        issuer: qfIssuer,
        audience: qfClientId.value(),
      }));
    } catch (err) {
      logger.warn("signInWithQf: id_token failed verification", {
        error: String(err),
      });
      throw new HttpsError(
        "permission-denied",
        "Quran.com token failed verification."
      );
    }

    const sub = typeof payload.sub === "string" ? payload.sub : undefined;
    if (!sub) {
      throw new HttpsError("permission-denied", "Token carries no subject.");
    }

    const uid = qfUid(sub);
    await ensureQfUser(uid, {
      email: typeof payload.email === "string" && payload.email.length > 0
        ? payload.email
        : undefined,
      displayName: displayNameFrom(payload),
      photoURL: photoUrlFrom(payload),
    });

    // Carry the departing anonymous account's data across. Guarded on
    // the caller actually being that account so a client can't ask us
    // to move somebody else's documents.
    const previousUid = (request.data ?? {}).previousUid;
    let migrated = false;
    if (
      typeof previousUid === "string" &&
      previousUid.length > 0 &&
      previousUid !== uid &&
      request.auth?.uid === previousUid
    ) {
      try {
        migrated = await migrateUserData(previousUid, uid);
      } catch (err) {
        // Never block sign-in on migration — the client keeps local
        // storage as its source of truth and will re-sync upward.
        logger.error("signInWithQf: migration failed", {
          previousUid,
          uid,
          error: String(err),
        });
      }
    }

    const token = await getAuth().createCustomToken(uid);
    logger.info("signInWithQf: issued custom token", {uid, migrated});
    return {token, uid, migrated};
  }
);
