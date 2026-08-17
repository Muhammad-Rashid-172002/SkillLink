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
        "SkillLink User";

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
