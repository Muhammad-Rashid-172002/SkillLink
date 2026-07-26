const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");
initializeApp();

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
