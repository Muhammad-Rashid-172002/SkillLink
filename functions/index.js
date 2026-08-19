/* eslint-disable max-len */
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {getAuth} = require("firebase-admin/auth");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const nodemailer = require("nodemailer");
const logger = require("firebase-functions/logger");
initializeApp();

const smtpAppPassword = defineSecret("SMTP_APP_PASSWORD");
const googleRoutesApiKey = defineSecret("GOOGLE_ROUTES_API_KEY");


/**
 * Sends a branded SkillNova verification email for the currently
 * signed-in user.
 * Firebase Admin generates the secure verification action link while Google
 * Workspace SMTP handles delivery.
 */
exports.sendCustomVerificationEmail = onCall(
    {
      secrets: [smtpAppPassword],
      region: "us-central1",
      timeoutSeconds: 60,
      memory: "256MiB",
    },
    async (request) => {
      const auth = getAuth();

      // Normally Firebase callable functions receive request.auth automatically.
      // Immediately after sign-up, however, the client auth token can briefly
      // lag behind the newly-created Firebase user. Support a tightly validated
      // fallback using the uid + email supplied by the newly-created client.
      let uid = request.auth ? request.auth.uid : "";
      let user;

      if (uid) {
        user = await auth.getUser(uid);
      } else {
        const fallbackUid = String(
            request.data && request.data.uid ? request.data.uid : "",
        ).trim();
        const fallbackEmail = String(
            request.data && request.data.email ? request.data.email : "",
        ).trim().toLowerCase();

        if (!fallbackUid || !isValidEmailAddress(fallbackEmail)) {
          throw new HttpsError(
              "unauthenticated",
              "Authentication is still initializing. Please try again.",
          );
        }

        user = await auth.getUser(fallbackUid);

        const accountEmail = String(user.email || "").trim().toLowerCase();

        if (!accountEmail || accountEmail !== fallbackEmail) {
          throw new HttpsError(
              "permission-denied",
              "The account details could not be verified.",
          );
        }

        uid = user.uid;

        logger.warn(
            "Verification email used post-signup auth fallback.",
            {uid},
        );
      }

      if (!user.email) {
        throw new HttpsError(
            "failed-precondition",
            "No email address is associated with this account.",
        );
      }

      if (user.emailVerified) {
        return {
          success: true,
          alreadyVerified: true,
          message: "Your email address is already verified.",
        };
      }

      const email = user.email.trim();
      const displayName = String(user.displayName || "").trim();
      const firstName = displayName ? displayName.split(/\s+/)[0] : "there";

      try {
        const verificationLink =
          await auth.generateEmailVerificationLink(email);

        const transporter = createSkillNovaMailTransport();

        await transporter.sendMail({
          from: "\"SkillNova\" <noreply@korvenzatech.com>",
          to: email,
          replyTo: "info@korvenzatech.com",
          subject: "Verify your email | SkillNova",
          text:
            `Hi ${firstName},\n\n` +
            "Welcome to SkillNova. Please verify your email address to " +
            "secure your account and continue.\n\n" +
            `${verificationLink}\n\n` +
            "If you did not create a SkillNova account, you can safely " +
            "ignore this email.\n\n" +
            "SkillNova\nPowered by KorvenzaTech",
          html: buildSkillNovaVerificationEmailHtml({
            firstName,
            verificationLink,
          }),
        });

        logger.info("SkillNova verification email sent successfully.", {uid});

        return {
          success: true,
          alreadyVerified: false,
          message: "Verification email sent successfully.",
        };
      } catch (error) {
        logger.error("SkillNova verification email failed.", {
          uid,
          error: safeMailError(error),
        });

        throw new HttpsError(
            "internal",
            "We could not send the verification email right now. Please try again.",
        );
      }
    },
);


/**
 * Sends a branded SkillNova password-reset email.
 * The callable works while signed out and intentionally returns a generic
 * response for unknown email addresses to reduce account enumeration.
 */
exports.sendCustomPasswordResetEmail = onCall(
    {
      secrets: [smtpAppPassword],
      region: "us-central1",
      timeoutSeconds: 60,
      memory: "256MiB",
    },
    async (request) => {
      const email = String(
          request.data && request.data.email ? request.data.email : "",
      ).trim().toLowerCase();

      if (!isValidEmailAddress(email)) {
        throw new HttpsError(
            "invalid-argument",
            "Please enter a valid email address.",
        );
      }

      const genericResponse = {
        success: true,
        message:
          "If a SkillNova account exists for this email, password reset " +
          "instructions have been sent.",
      };

      const auth = getAuth();

      try {
        const user = await auth.getUserByEmail(email);
        const resetLink = await auth.generatePasswordResetLink(email);

        const displayName = String(user.displayName || "").trim();
        const firstName = displayName ? displayName.split(/\s+/)[0] : "there";

        const transporter = createSkillNovaMailTransport();

        await transporter.sendMail({
          from: "\"SkillNova\" <noreply@korvenzatech.com>",
          to: email,
          replyTo: "info@korvenzatech.com",
          subject: "Reset your password | SkillNova",
          text:
            `Hi ${firstName},\n\n` +
            "We received a request to reset your SkillNova password.\n\n" +
            `${resetLink}\n\n` +
            "If you did not request this reset, you can safely ignore this " +
            "email. Your password will remain unchanged.\n\n" +
            "For your security, never share this reset link with anyone.\n\n" +
            "SkillNova\nPowered by KorvenzaTech",
          html: buildSkillNovaPasswordResetEmailHtml({
            firstName,
            resetLink,
          }),
        });

        logger.info("SkillNova password reset email sent successfully.", {
          uid: user.uid,
        });

        return genericResponse;
      } catch (error) {
        const code = String(
            error && error.code ? error.code : "",
        );

        if (code === "auth/user-not-found") {
          logger.info("SkillNova password reset requested for unknown email.");
          return genericResponse;
        }

        logger.error("SkillNova password reset email failed.", {
          error: safeMailError(error),
        });

        throw new HttpsError(
            "internal",
            "We could not process the password reset request right now. " +
            "Please try again.",
        );
      }
    },
);


/**
 * Creates the Google Workspace SMTP transport used by SkillNova emails.
 *
 * @return {Object} Nodemailer transport instance.
 */
function createSkillNovaMailTransport() {
  return nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: {
      // The App Password belongs to this real Google Workspace mailbox.
      user: "ceo@korvenzatech.com",
      pass: smtpAppPassword.value(),
    },
  });
}


/**
 * Builds the SkillNova verification email HTML.
 *
 * @param {Object} params Email template parameters.
 * @param {string} params.firstName Recipient first name.
 * @param {string} params.verificationLink Secure Firebase verification link.
 * @return {string} Rendered HTML email.
 */
function buildSkillNovaVerificationEmailHtml({
  firstName,
  verificationLink,
}) {
  const safeName = escapeMailHtml(firstName);
  const safeLink = escapeMailHtml(verificationLink);
  const year = new Date().getUTCFullYear();

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="x-apple-disable-message-reformatting">
  <title>Verify your email</title>
</head>
<body style="margin:0;padding:0;background:#f5f7fb;font-family:Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;color:#101828;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">Verify your SkillNova email address to activate your account.</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#f5f7fb;padding:40px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:620px;">
        <tr><td style="padding:0 8px 22px;text-align:center;">
          <div style="font-size:26px;font-weight:900;letter-spacing:-0.7px;color:#101828;">Skill<span style="color:#4f46e5;">Nova</span></div>
          <div style="margin-top:6px;font-size:11px;letter-spacing:1.8px;text-transform:uppercase;color:#667085;">Connect · Grow · Get Things Done</div>
        </td></tr>
        <tr><td style="background:#ffffff;border:1px solid #e4e7ec;border-radius:24px;overflow:hidden;box-shadow:0 18px 50px rgba(16,24,40,.08);">
          <div style="height:6px;background:linear-gradient(90deg,#4f46e5,#7c3aed,#06b6d4);"></div>
          <div style="padding:46px 46px 40px;">
            <div style="width:58px;height:58px;line-height:58px;text-align:center;border-radius:17px;background:#eef2ff;color:#4f46e5;font-size:27px;font-weight:900;margin-bottom:28px;">✓</div>
            <h1 style="margin:0 0 14px;font-size:30px;line-height:1.2;letter-spacing:-.8px;color:#101828;">Verify your email address</h1>
            <p style="margin:0 0 18px;font-size:16px;line-height:1.75;color:#475467;">Hi ${safeName},</p>
            <p style="margin:0 0 28px;font-size:16px;line-height:1.75;color:#475467;">Welcome to <strong style="color:#101828;">SkillNova</strong>. Confirm your email address to secure your account and continue with confidence.</p>
            <table role="presentation" cellspacing="0" cellpadding="0" border="0">
              <tr><td style="border-radius:12px;background:#4f46e5;">
                <a href="${safeLink}" style="display:inline-block;padding:15px 28px;font-size:15px;font-weight:800;color:#ffffff;text-decoration:none;border-radius:12px;">Verify email address</a>
              </td></tr>
            </table>
            <div style="margin-top:30px;padding:18px 20px;border-radius:14px;background:#f8fafc;border:1px solid #eaecf0;">
              <p style="margin:0 0 6px;font-size:13px;font-weight:800;color:#344054;">Security notice</p>
              <p style="margin:0;font-size:13px;line-height:1.7;color:#667085;">Only use this link if you created the SkillNova account. If this was not you, no action is required.</p>
            </div>
            <div style="margin-top:30px;padding-top:26px;border-top:1px solid #eaecf0;">
              <p style="margin:0 0 8px;font-size:12px;font-weight:800;color:#667085;">Button not working?</p>
              <p style="margin:0;font-size:11px;line-height:1.6;color:#98a2b3;word-break:break-all;">${safeLink}</p>
            </div>
          </div>
        </td></tr>
        <tr><td style="padding:26px 20px 0;text-align:center;">
          <p style="margin:0 0 7px;font-size:12px;color:#667085;">SkillNova · Powered by KorvenzaTech</p>
          <p style="margin:0;font-size:11px;color:#98a2b3;">© ${year} KorvenzaTech. All rights reserved.</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}


/**
 * Builds the SkillNova password reset email HTML.
 *
 * @param {Object} params Email template parameters.
 * @param {string} params.firstName Recipient first name.
 * @param {string} params.resetLink Secure Firebase password reset link.
 * @return {string} Rendered HTML email.
 */
function buildSkillNovaPasswordResetEmailHtml({
  firstName,
  resetLink,
}) {
  const safeName = escapeMailHtml(firstName);
  const safeLink = escapeMailHtml(resetLink);
  const year = new Date().getUTCFullYear();

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="x-apple-disable-message-reformatting">
  <title>Reset your password</title>
</head>
<body style="margin:0;padding:0;background:#f5f7fb;font-family:Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;color:#101828;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">Securely reset your SkillNova password.</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#f5f7fb;padding:40px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:620px;">
        <tr><td style="padding:0 8px 22px;text-align:center;">
          <div style="font-size:26px;font-weight:900;letter-spacing:-0.7px;color:#101828;">Skill<span style="color:#4f46e5;">Nova</span></div>
          <div style="margin-top:6px;font-size:11px;letter-spacing:1.8px;text-transform:uppercase;color:#667085;">Connect · Grow · Get Things Done</div>
        </td></tr>
        <tr><td style="background:#ffffff;border:1px solid #e4e7ec;border-radius:24px;overflow:hidden;box-shadow:0 18px 50px rgba(16,24,40,.08);">
          <div style="height:6px;background:linear-gradient(90deg,#4f46e5,#7c3aed,#06b6d4);"></div>
          <div style="padding:46px 46px 40px;">
            <div style="width:58px;height:58px;line-height:58px;text-align:center;border-radius:17px;background:#eef2ff;color:#4f46e5;font-size:25px;font-weight:900;margin-bottom:28px;">↻</div>
            <h1 style="margin:0 0 14px;font-size:30px;line-height:1.2;letter-spacing:-.8px;color:#101828;">Reset your password</h1>
            <p style="margin:0 0 18px;font-size:16px;line-height:1.75;color:#475467;">Hi ${safeName},</p>
            <p style="margin:0 0 28px;font-size:16px;line-height:1.75;color:#475467;">We received a request to reset the password for your <strong style="color:#101828;">SkillNova</strong> account. Use the secure button below to choose a new password.</p>
            <table role="presentation" cellspacing="0" cellpadding="0" border="0">
              <tr><td style="border-radius:12px;background:#4f46e5;">
                <a href="${safeLink}" style="display:inline-block;padding:15px 28px;font-size:15px;font-weight:800;color:#ffffff;text-decoration:none;border-radius:12px;">Reset password</a>
              </td></tr>
            </table>
            <div style="margin-top:30px;padding:18px 20px;border-radius:14px;background:#f8fafc;border:1px solid #eaecf0;">
              <p style="margin:0 0 6px;font-size:13px;font-weight:800;color:#344054;">Security notice</p>
              <p style="margin:0;font-size:13px;line-height:1.7;color:#667085;">If you did not request this password reset, no action is required and your current password remains unchanged. Never share this reset link.</p>
            </div>
            <div style="margin-top:30px;padding-top:26px;border-top:1px solid #eaecf0;">
              <p style="margin:0 0 8px;font-size:12px;font-weight:800;color:#667085;">Button not working?</p>
              <p style="margin:0;font-size:11px;line-height:1.6;color:#98a2b3;word-break:break-all;">${safeLink}</p>
            </div>
          </div>
        </td></tr>
        <tr><td style="padding:26px 20px 0;text-align:center;">
          <p style="margin:0 0 7px;font-size:12px;color:#667085;">SkillNova · Powered by KorvenzaTech</p>
          <p style="margin:0;font-size:11px;color:#98a2b3;">© ${year} KorvenzaTech. All rights reserved.</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}


/**
 * Escapes text before inserting it into HTML email templates.
 *
 * @param {string} value Raw text.
 * @return {string} HTML-safe text.
 */
function escapeMailHtml(value) {
  return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
}


/**
 * Performs basic email-format validation.
 *
 * @param {string} value Email address.
 * @return {boolean} True when the email format is valid.
 */
function isValidEmailAddress(value) {
  if (!value || value.length > 254) return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}


/**
 * Converts an unknown error value into a safe log message.
 *
 * @param {*} error Error-like value.
 * @return {string} Safe error text.
 */
function safeMailError(error) {
  if (!error) return "Unknown error";
  if (error instanceof Error && error.message) return error.message;
  return String(error);
}


exports.sendChatNotification = onDocumentCreated(
    "chats/{chatId}/messages/{messageId}",
    async (event) => {
      const snapshot = event.data;

      if (!snapshot) {
        logger.info("Message snapshot not found.");
        return;
      }

      const messageData = snapshot.data();

      const senderId = messageData.senderId;
      const receiverId = messageData.receiverId;
      const messageText = messageData.text || "";
      const messageType = messageData.type || "text";

      if (!senderId || !receiverId) {
        logger.info("senderId or receiverId is missing.");
        return;
      }

      const firestore = getFirestore();

      const [senderSnapshot, receiverSnapshot] = await Promise.all([
        firestore.collection("users").doc(senderId).get(),
        firestore.collection("users").doc(receiverId).get(),
      ]);

      if (!receiverSnapshot.exists) {
        logger.info("Receiver user document does not exist.");
        return;
      }

      const senderData = senderSnapshot.data() || {};
      const receiverData = receiverSnapshot.data() || {};

      const receiverToken = receiverData.fcmToken;

      if (!receiverToken) {
        logger.info("Receiver FCM token is missing.");
        return;
      }

      const senderName =
        senderData.name ||
        senderData.fullName ||
        "SkillNova User";

      let notificationMessage = messageText;

      if (messageType === "image") {
        notificationMessage = "Sent you a photo";
      } else if (messageType === "audio") {
        notificationMessage = "Sent you a voice message";
      } else if (!notificationMessage.trim()) {
        notificationMessage = "Sent you a new message";
      }

      const payload = {
        token: receiverToken,

        notification: {
          title: senderName,
          body: notificationMessage,
        },

        data: {
          type: "chat",
          chatId: event.params.chatId,
          senderId: senderId,
          receiverId: receiverId,
          senderName: senderName,
        },

        android: {
          priority: "high",
          notification: {
            channelId: "chat_messages",
            sound: "default",
          },
        },

        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      };

      try {
        const response = await getMessaging().send(payload);

        logger.info("Chat notification sent successfully.", {
          response,
          chatId: event.params.chatId,
          receiverId,
        });
      } catch (error) {
        logger.error("Error sending chat notification.", error);
      }
    },
);

exports.sendJobNotification = onDocumentCreated(
    "requests/{requestId}",
    async (event) => {
      const snapshot = event.data;

      if (!snapshot) {
        logger.info("Request snapshot not found.");
        return;
      }

      const requestData = snapshot.data();
      const firestore = getFirestore();

      const category = requestData.category || "Service";
      const location = requestData.location || "Location not provided";
      const budget = requestData.budget || "Not specified";
      const customerId = requestData.customerId || "";
      const workerId = requestData.workerId || "";
      const isDirectRequest = requestData.isDirectRequest === true;

      let workerSnapshots;

      if (isDirectRequest && workerId) {
        const workerSnapshot = await firestore
            .collection("users")
            .doc(workerId)
            .get();

        workerSnapshots = workerSnapshot.exists ? [workerSnapshot] : [];
      } else {
        const workersQuery = await firestore
            .collection("users")
            .where("role", "==", "worker")
            .get();

        workerSnapshots = workersQuery.docs;
      }

      const messages = [];

      for (const workerSnapshot of workerSnapshots) {
        const workerData = workerSnapshot.data() || {};
        const token = workerData.fcmToken;

        if (!token) {
          continue;
        }

        messages.push({
          token: token,

          notification: {
            title: isDirectRequest ?
              "Direct Job Request" :
              `New ${category} Job`,
            body: `Budget: Rs. ${budget} • ${location}`,
          },

          data: {
            type: isDirectRequest ? "direct_job" : "job",
            requestId: event.params.requestId,
            customerId: customerId,
            workerId: workerSnapshot.id,
            category: category,
            location: location,
            budget: budget.toString(),
            urgency: (requestData.urgency || "Normal").toString(),
            title: (requestData.title || category).toString(),
          },

          android: {
            priority: "high",
            notification: {
              channelId: "job_alerts",
              sound: "default",
            },
          },

          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        });
      }

      if (messages.length === 0) {
        logger.info("No workers with FCM tokens found.");
        return;
      }

      try {
        const response = await getMessaging().sendEach(messages);

        logger.info("Job notifications processed.", {
          successCount: response.successCount,
          failureCount: response.failureCount,
          requestId: event.params.requestId,
        });

        response.responses.forEach((result, index) => {
          if (!result.success) {
            const failedWorker = workerSnapshots[index];

            logger.error("Job notification failed.", {
              workerId: failedWorker ? failedWorker.id : "unknown",
              error: result.error,
            });
          }
        });
      } catch (error) {
        logger.error("Error sending job notifications.", error);
      }
    },
);

exports.sendJobStatusNotification = onDocumentUpdated(
    "requests/{requestId}",
    async (event) => {
      const beforeSnapshot = event.data.before;
      const afterSnapshot = event.data.after;

      if (!beforeSnapshot.exists || !afterSnapshot.exists) {
        logger.info("Request before or after snapshot is missing.");
        return;
      }

      const beforeData = beforeSnapshot.data() || {};
      const afterData = afterSnapshot.data() || {};

      const previousStatus = (
        beforeData.status || ""
      ).toString().trim().toLowerCase();

      const currentStatus = (
        afterData.status || ""
      ).toString().trim().toLowerCase();

      // Do not send notification when status has not changed.
      if (!currentStatus || previousStatus === currentStatus) {
        return;
      }

      const supportedStatuses = [
        "accepted",
        "on_the_way",
        "on the way",
        "ontheway",
        "started",
        "in_progress",
        "in progress",
        "completed",
      ];

      if (!supportedStatuses.includes(currentStatus)) {
        logger.info("Unsupported job status.", {
          requestId: event.params.requestId,
          previousStatus,
          currentStatus,
        });
        return;
      }

      const customerId = (
        afterData.customerId || ""
      ).toString().trim();

      const workerId = (
        afterData.workerId || ""
      ).toString().trim();

      if (!customerId) {
        logger.info("Customer ID is missing from request.", {
          requestId: event.params.requestId,
        });
        return;
      }

      const firestore = getFirestore();

      const [customerSnapshot, workerSnapshot] = await Promise.all([
        firestore.collection("users").doc(customerId).get(),
        workerId ?
          firestore.collection("users").doc(workerId).get() :
          Promise.resolve(null),
      ]);

      if (!customerSnapshot.exists) {
        logger.info("Customer document does not exist.", {
          customerId,
        });
        return;
      }

      const customerData = customerSnapshot.data() || {};
      const workerData = workerSnapshot && workerSnapshot.exists ?
        workerSnapshot.data() || {} :
        {};

      const customerToken = customerData.fcmToken;

      const workerName =
        workerData.name ||
        workerData.fullName ||
        "Your worker";

      const category =
        afterData.category ||
        afterData.title ||
        "service";

      let notificationTitle = "Job updated";
      let notificationBody =
        `${workerName} updated your ${category} job.`;
      let normalizedStatus = currentStatus;

      if (currentStatus === "accepted") {
        notificationTitle = "Job Accepted";
        notificationBody =
          `${workerName} has accepted your ${category} request.`;
      } else if (
        currentStatus === "on_the_way" ||
        currentStatus === "on the way" ||
        currentStatus === "ontheway"
      ) {
        normalizedStatus = "on_the_way";
        notificationTitle = "Worker Is On the Way";
        notificationBody =
          `${workerName} is now on the way to your location.`;
      } else if (
        currentStatus === "started" ||
        currentStatus === "in_progress" ||
        currentStatus === "in progress"
      ) {
        normalizedStatus = "started";
        notificationTitle = "Job Started";
        notificationBody =
          `${workerName} has started your ${category} job.`;
      } else if (currentStatus === "completed") {
        notificationTitle = "Job Completed";
        notificationBody =
          `${workerName} marked your ${category} job as completed.`;
      }

      // Save notification inside Firestore notification screen.
      try {
        await firestore.collection("notifications").add({
          userId: customerId,
          role: "customer",
          type: "job_status",
          title: notificationTitle,
          message: notificationBody,
          requestId: event.params.requestId,
          workerId: workerId,
          status: normalizedStatus,
          isRead: false,
          createdAt: new Date(),
        });
      } catch (error) {
        logger.error(
            "Error saving job status notification in Firestore.",
            error,
        );
      }

      if (!customerToken) {
        logger.info("Customer FCM token is missing.", {
          customerId,
          requestId: event.params.requestId,
        });
        return;
      }

      const payload = {
        token: customerToken,

        notification: {
          title: notificationTitle,
          body: notificationBody,
        },

        data: {
          type: "job_status",
          requestId: event.params.requestId,
          customerId: customerId,
          workerId: workerId,
          status: normalizedStatus,
          category: category.toString(),
          title: (
            afterData.title || category
          ).toString(),
        },

        android: {
          priority: "high",
          notification: {
            channelId: "job_alerts",
            sound: "default",
          },
        },

        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      };

      try {
        const response = await getMessaging().send(payload);

        logger.info("Job status notification sent successfully.", {
          response,
          requestId: event.params.requestId,
          customerId,
          status: normalizedStatus,
        });
      } catch (error) {
        logger.error(
            "Error sending job status notification.",
            error,
        );
      }
    },
);

exports.sendReviewNotification = onDocumentCreated(
    "reviews/{reviewId}",
    async (event) => {
      const snapshot = event.data;

      if (!snapshot) {
        logger.info("Review snapshot not found.");
        return;
      }

      const reviewData = snapshot.data() || {};

      const workerId = (
        reviewData.workerId || ""
      ).toString().trim();

      const customerId = (
        reviewData.customerId || ""
      ).toString().trim();

      const requestId = (
        reviewData.requestId || event.params.reviewId
      ).toString().trim();

      const rating = Number(reviewData.rating || 0);

      const reviewText = (
        reviewData.review || ""
      ).toString().trim();

      if (!workerId) {
        logger.info("Worker ID is missing from review.", {
          reviewId: event.params.reviewId,
        });
        return;
      }

      const firestore = getFirestore();

      const [workerSnapshot, customerSnapshot] = await Promise.all([
        firestore.collection("users").doc(workerId).get(),
        customerId ?
          firestore.collection("users").doc(customerId).get() :
          Promise.resolve(null),
      ]);

      if (!workerSnapshot.exists) {
        logger.info("Worker document does not exist.", {
          workerId,
        });
        return;
      }

      const workerData = workerSnapshot.data() || {};

      const customerData =
        customerSnapshot && customerSnapshot.exists ?
          customerSnapshot.data() || {} :
          {};

      const workerToken = workerData.fcmToken;

      const customerName =
        customerData.name ||
        customerData.fullName ||
        "A customer";

      const safeRating =
        rating >= 1 && rating <= 5 ? rating : 0;

      const starsText =
        safeRating > 0 ? `${safeRating}★` : "a rating";

      const notificationTitle = "New Review Received";

      let notificationBody =
        `${customerName} gave you ${starsText}.`;

      if (reviewText) {
        notificationBody =
          `${customerName} rated you ${starsText} and left a review.`;
      }

      // Save review notification inside Firestore.
      try {
        await firestore.collection("notifications").add({
          userId: workerId,
          role: "worker",
          type: "review",
          title: notificationTitle,
          message: notificationBody,
          requestId: requestId,
          customerId: customerId,
          workerId: workerId,
          reviewId: event.params.reviewId,
          rating: safeRating,
          isRead: false,
          createdAt: new Date(),
        });
      } catch (error) {
        logger.error(
            "Error saving review notification in Firestore.",
            error,
        );
      }

      if (!workerToken) {
        logger.info("Worker FCM token is missing.", {
          workerId,
          reviewId: event.params.reviewId,
        });
        return;
      }

      const payload = {
        token: workerToken,

        notification: {
          title: notificationTitle,
          body: notificationBody,
        },

        data: {
          type: "review",
          reviewId: event.params.reviewId,
          requestId: requestId,
          workerId: workerId,
          customerId: customerId,
          customerName: customerName.toString(),
          rating: safeRating.toString(),
        },

        android: {
          priority: "high",
          notification: {
            channelId: "job_alerts",
            sound: "default",
          },
        },

        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      };

      try {
        const response = await getMessaging().send(payload);

        logger.info("Review notification sent successfully.", {
          response,
          workerId,
          reviewId: event.params.reviewId,
          rating: safeRating,
        });
      } catch (error) {
        logger.error(
            "Error sending review notification.",
            error,
        );
      }
    },
);
/**
 * ---------------------------------------------------------------------------
 * SkillNova live job tracking + Google Routes
 * ---------------------------------------------------------------------------
 * Data flow:
 * Flutter GPS -> updateLiveLocation -> live_tracking/{requestId}
 * Firestore realtime listener -> customer/worker tracking UI
 * computeJobRoute -> Google Routes API -> route/ETA/distance/polyline
 *
 * Important:
 * - GOOGLE_ROUTES_API_KEY is stored in Firebase Secret Manager.
 * - The mobile app never receives the Routes API key.
 * - Only the assigned customer and worker may access a job's tracking data.
 * - A route refresh is rate-limited server-side to reduce unnecessary API cost.
 */

const LIVE_TRACKING_COLLECTION = "live_tracking";
const TRACKABLE_JOB_STATUSES = new Set([
  "accepted",
  "on_the_way",
  "on the way",
  "ontheway",
  "started",
  "in_progress",
  "in progress",
]);
const FINISHED_JOB_STATUSES = new Set([
  "completed",
  "cancelled",
  "canceled",
  "rejected",
]);
const MIN_ROUTE_REFRESH_MS = 15000;


/**
 * Normalizes request status values used by different SkillNova screens.
 *
 * @param {*} value Raw status value.
 * @return {string} Normalized status.
 */
function normalizeJobStatus(value) {
  const status = String(value || "").trim().toLowerCase();

  if (
    status === "on_the_way" ||
    status === "on the way" ||
    status === "ontheway"
  ) {
    return "on_the_way";
  }

  if (
    status === "started" ||
    status === "in_progress" ||
    status === "in progress"
  ) {
    return "started";
  }

  if (status === "canceled") {
    return "cancelled";
  }

  return status;
}


/**
 * Validates a latitude.
 *
 * @param {*} value Latitude candidate.
 * @return {boolean} True when valid.
 */
function isValidLatitude(value) {
  return Number.isFinite(Number(value)) &&
    Number(value) >= -90 &&
    Number(value) <= 90;
}


/**
 * Validates a longitude.
 *
 * @param {*} value Longitude candidate.
 * @return {boolean} True when valid.
 */
function isValidLongitude(value) {
  return Number.isFinite(Number(value)) &&
    Number(value) >= -180 &&
    Number(value) <= 180;
}


/**
 * Converts an optional numeric value to a finite number or null.
 *
 * @param {*} value Candidate value.
 * @return {?number} Finite number or null.
 */
function optionalFiniteNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}


/**
 * Returns a safe millisecond timestamp from a Firestore/date-like value.
 *
 * @param {*} value Timestamp/date-like value.
 * @return {number} Milliseconds since epoch, or zero.
 */
function timestampToMillis(value) {
  if (!value) return 0;

  if (typeof value.toMillis === "function") {
    return value.toMillis();
  }

  if (value instanceof Date) {
    return value.getTime();
  }

  const parsed = new Date(value).getTime();
  return Number.isFinite(parsed) ? parsed : 0;
}


/**
 * Reads a SkillNova job and verifies the caller is its assigned participant.
 *
 * @param {string} requestId SkillNova request document ID.
 * @param {string} uid Authenticated Firebase UID.
 * @return {Promise<Object>} Job context.
 */
async function getAuthorizedTrackingJob(requestId, uid) {
  if (!requestId) {
    throw new HttpsError(
        "invalid-argument",
        "A valid job request ID is required.",
    );
  }

  const firestore = getFirestore();
  const requestRef = firestore.collection("requests").doc(requestId);
  const requestSnapshot = await requestRef.get();

  if (!requestSnapshot.exists) {
    throw new HttpsError(
        "not-found",
        "This SkillNova job could not be found.",
    );
  }

  const requestData = requestSnapshot.data() || {};
  const customerId = String(requestData.customerId || "").trim();
  const workerId = String(requestData.workerId || "").trim();

  if (!customerId) {
    throw new HttpsError(
        "failed-precondition",
        "This job does not have a customer assigned.",
    );
  }

  if (uid !== customerId && uid !== workerId) {
    throw new HttpsError(
        "permission-denied",
        "You are not allowed to access this job's live tracking.",
    );
  }

  return {
    firestore,
    requestRef,
    requestData,
    customerId,
    workerId,
    callerRole: uid === workerId ? "worker" : "customer",
    status: normalizeJobStatus(requestData.status),
  };
}


/**
 * Creates/updates the server-side live tracking document for a job.
 *
 * Flutter should call this while a participant is actively sharing location.
 */
exports.updateLiveLocation = onCall(
    {
      region: "us-central1",
      timeoutSeconds: 30,
      memory: "256MiB",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "You must be signed in to share live location.",
        );
      }

      const data = request.data || {};
      const requestId = String(data.requestId || "").trim();
      const latitude = Number(data.latitude);
      const longitude = Number(data.longitude);

      if (
        !isValidLatitude(latitude) ||
        !isValidLongitude(longitude)
      ) {
        throw new HttpsError(
            "invalid-argument",
            "Valid latitude and longitude are required.",
        );
      }

      const job = await getAuthorizedTrackingJob(
          requestId,
          request.auth.uid,
      );

      if (!TRACKABLE_JOB_STATUSES.has(job.status)) {
        throw new HttpsError(
            "failed-precondition",
            "Live tracking is available only for an active assigned job.",
        );
      }

      if (job.callerRole === "worker" && !job.workerId) {
        throw new HttpsError(
            "failed-precondition",
            "No worker is assigned to this job.",
        );
      }

      const now = new Date();
      const heading = optionalFiniteNumber(data.heading);
      const speed = optionalFiniteNumber(data.speed);
      const accuracy = optionalFiniteNumber(data.accuracy);

      const locationPayload = {
        latitude,
        longitude,
        heading,
        speed,
        accuracy,
        updatedAt: now,
      };

      const trackingRef = job.firestore
          .collection(LIVE_TRACKING_COLLECTION)
          .doc(requestId);

      const update = {
        requestId,
        customerId: job.customerId,
        workerId: job.workerId,
        status: job.status,
        isActive: true,
        updatedAt: now,
      };

      if (job.callerRole === "worker") {
        update.workerLocation = locationPayload;
        update.workerLocationUpdatedAt = now;
      } else {
        update.customerLocation = locationPayload;
        update.customerLocationUpdatedAt = now;
      }

      await trackingRef.set(update, {merge: true});

      return {
        success: true,
        requestId,
        role: job.callerRole,
        isActive: true,
        location: {
          latitude,
          longitude,
          heading,
          speed,
          accuracy,
        },
        updatedAt: now.toISOString(),
      };
    },
);


/**
 * Calculates the assigned worker -> customer road route for a SkillNova job.
 *
 * Route data is stored in live_tracking/{requestId} so both apps can receive
 * the same ETA, distance and polyline through a Firestore realtime listener.
 */
exports.computeJobRoute = onCall(
    {
      secrets: [googleRoutesApiKey],
      region: "us-central1",
      timeoutSeconds: 30,
      memory: "256MiB",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "You must be signed in to calculate a job route.",
        );
      }

      const requestId = String(
          request.data && request.data.requestId ?
            request.data.requestId :
            "",
      ).trim();

      const forceRefresh =
        request.data && request.data.forceRefresh === true;

      const job = await getAuthorizedTrackingJob(
          requestId,
          request.auth.uid,
      );

      if (!TRACKABLE_JOB_STATUSES.has(job.status)) {
        throw new HttpsError(
            "failed-precondition",
            "Route tracking is not active for this job.",
        );
      }

      if (!job.workerId) {
        throw new HttpsError(
            "failed-precondition",
            "A worker must accept the job before routing can start.",
        );
      }

      const trackingRef = job.firestore
          .collection(LIVE_TRACKING_COLLECTION)
          .doc(requestId);

      const trackingSnapshot = await trackingRef.get();
      const trackingData = trackingSnapshot.exists ?
        trackingSnapshot.data() || {} :
        {};

      const workerLocation = trackingData.workerLocation || {};
      const customerLocation = trackingData.customerLocation || {};

      if (
        !isValidLatitude(workerLocation.latitude) ||
        !isValidLongitude(workerLocation.longitude)
      ) {
        throw new HttpsError(
            "failed-precondition",
            "The worker's live location is not available yet.",
        );
      }

      if (
        !isValidLatitude(customerLocation.latitude) ||
        !isValidLongitude(customerLocation.longitude)
      ) {
        throw new HttpsError(
            "failed-precondition",
            "The customer's live location is not available yet.",
        );
      }

      const previousRoute = trackingData.route || {};
      const previousCalculatedAt =
        timestampToMillis(previousRoute.calculatedAt);
      const nowMs = Date.now();

      if (
        !forceRefresh &&
        previousRoute.encodedPolyline &&
        previousCalculatedAt > 0 &&
        nowMs - previousCalculatedAt < MIN_ROUTE_REFRESH_MS
      ) {
        return {
          success: true,
          cached: true,
          requestId,
          route: previousRoute,
        };
      }

      try {
        const routesResponse = await fetch(
            "https://routes.googleapis.com/directions/v2:computeRoutes",
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                "X-Goog-Api-Key": googleRoutesApiKey.value(),
                "X-Goog-FieldMask":
                  "routes.distanceMeters," +
                  "routes.duration," +
                  "routes.staticDuration," +
                  "routes.polyline.encodedPolyline",
              },
              body: JSON.stringify({
                origin: {
                  location: {
                    latLng: {
                      latitude: Number(workerLocation.latitude),
                      longitude: Number(workerLocation.longitude),
                    },
                  },
                },
                destination: {
                  location: {
                    latLng: {
                      latitude: Number(customerLocation.latitude),
                      longitude: Number(customerLocation.longitude),
                    },
                  },
                },
                travelMode: "DRIVE",
                routingPreference: "TRAFFIC_AWARE",
                computeAlternativeRoutes: false,
                languageCode: "en-US",
                units: "METRIC",
              }),
            },
        );

        const routesResult = await routesResponse.json();

        if (!routesResponse.ok) {
          logger.error("Google Routes API request failed.", {
            requestId,
            status: routesResponse.status,
            error: routesResult,
          });

          throw new HttpsError(
              "internal",
              "SkillNova could not calculate the live route right now.",
          );
        }

        const routes = Array.isArray(routesResult.routes) ?
          routesResult.routes :
          [];

        if (routes.length === 0) {
          throw new HttpsError(
              "not-found",
              "No drivable route was found between the worker and customer.",
          );
        }

        const route = routes[0] || {};
        const distanceMeters = Number(route.distanceMeters || 0);

        const durationString = String(route.duration || "0s");
        const durationSeconds =
          Number.parseFloat(durationString.replace("s", "")) || 0;

        const staticDurationString =
          String(route.staticDuration || route.duration || "0s");
        const staticDurationSeconds =
          Number.parseFloat(staticDurationString.replace("s", "")) || 0;

        const calculatedAt = new Date();

        const routePayload = {
          distanceMeters,
          distanceKm: Number((distanceMeters / 1000).toFixed(2)),
          durationSeconds: Math.round(durationSeconds),
          durationMinutes: Math.max(
              1,
              Math.ceil(durationSeconds / 60),
          ),
          staticDurationSeconds: Math.round(staticDurationSeconds),
          encodedPolyline:
            route.polyline && route.polyline.encodedPolyline ?
              route.polyline.encodedPolyline :
              "",
          trafficAware: true,
          calculatedAt,
          origin: {
            latitude: Number(workerLocation.latitude),
            longitude: Number(workerLocation.longitude),
          },
          destination: {
            latitude: Number(customerLocation.latitude),
            longitude: Number(customerLocation.longitude),
          },
        };

        await trackingRef.set(
            {
              requestId,
              customerId: job.customerId,
              workerId: job.workerId,
              status: job.status,
              isActive: true,
              route: routePayload,
              updatedAt: calculatedAt,
            },
            {merge: true},
        );

        return {
          success: true,
          cached: false,
          requestId,
          route: {
            ...routePayload,
            calculatedAt: calculatedAt.toISOString(),
          },
        };
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }

        logger.error("computeJobRoute failed.", {
          requestId,
          uid: request.auth.uid,
          error: error instanceof Error ? error.message : String(error),
        });

        throw new HttpsError(
            "internal",
            "SkillNova could not calculate the live route right now.",
        );
      }
    },
);


/**
 * Returns a one-time authorized tracking snapshot.
 *
 * For the full "live" experience, Flutter should listen directly to
 * live_tracking/{requestId} after Firestore security rules are configured.
 */
exports.getLiveTrackingSnapshot = onCall(
    {
      region: "us-central1",
      timeoutSeconds: 30,
      memory: "256MiB",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "You must be signed in to view live tracking.",
        );
      }

      const requestId = String(
          request.data && request.data.requestId ?
            request.data.requestId :
            "",
      ).trim();

      const job = await getAuthorizedTrackingJob(
          requestId,
          request.auth.uid,
      );

      const trackingSnapshot = await job.firestore
          .collection(LIVE_TRACKING_COLLECTION)
          .doc(requestId)
          .get();

      if (!trackingSnapshot.exists) {
        return {
          success: true,
          exists: false,
          requestId,
          isActive: false,
        };
      }

      const trackingData = trackingSnapshot.data() || {};

      return {
        success: true,
        exists: true,
        requestId,
        isActive: trackingData.isActive === true,
        status: trackingData.status || job.status,
        customerId: job.customerId,
        workerId: job.workerId,
        customerLocation: trackingData.customerLocation || null,
        workerLocation: trackingData.workerLocation || null,
        route: trackingData.route || null,
        updatedAt: trackingData.updatedAt || null,
      };
    },
);


/**
 * Keeps the live_tracking document lifecycle aligned with the job status.
 *
 * accepted/on_the_way/started -> activate tracking
 * completed/cancelled/rejected -> stop tracking and preserve last location
 */
exports.syncLiveTrackingWithJobStatus = onDocumentUpdated(
    "requests/{requestId}",
    async (event) => {
      const beforeSnapshot = event.data.before;
      const afterSnapshot = event.data.after;

      if (!beforeSnapshot.exists || !afterSnapshot.exists) {
        return;
      }

      const beforeData = beforeSnapshot.data() || {};
      const afterData = afterSnapshot.data() || {};

      const previousStatus = normalizeJobStatus(beforeData.status);
      const currentStatus = normalizeJobStatus(afterData.status);

      const previousWorkerId = String(beforeData.workerId || "").trim();
      const currentWorkerId = String(afterData.workerId || "").trim();

      if (
        previousStatus === currentStatus &&
        previousWorkerId === currentWorkerId
      ) {
        return;
      }

      const customerId = String(afterData.customerId || "").trim();
      const workerId = String(afterData.workerId || "").trim();

      if (!customerId) {
        return;
      }

      const requestId = event.params.requestId;
      const firestore = getFirestore();
      const trackingRef = firestore
          .collection(LIVE_TRACKING_COLLECTION)
          .doc(requestId);

      const now = new Date();

      if (TRACKABLE_JOB_STATUSES.has(currentStatus) && workerId) {
        await trackingRef.set(
            {
              requestId,
              customerId,
              workerId,
              status: currentStatus,
              isActive: true,
              startedAt: now,
              endedAt: null,
              updatedAt: now,
            },
            {merge: true},
        );

        logger.info("SkillNova live tracking activated.", {
          requestId,
          customerId,
          workerId,
          status: currentStatus,
        });

        return;
      }

      if (FINISHED_JOB_STATUSES.has(currentStatus)) {
        const existingSnapshot = await trackingRef.get();

        if (!existingSnapshot.exists) {
          return;
        }

        await trackingRef.set(
            {
              status: currentStatus,
              isActive: false,
              endedAt: now,
              updatedAt: now,
            },
            {merge: true},
        );

        logger.info("SkillNova live tracking stopped.", {
          requestId,
          status: currentStatus,
        });
      }
    },
);
