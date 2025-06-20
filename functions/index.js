// Cloud Function (Node.js) - Deploy to Firebase Functions
// This runs on Firebase servers and checks for expiring items daily

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// HTTP function to check expiring items (can be called manually or scheduler)
exports.checkExpiringItems = functions.https.onRequest(
    async (req, res) => {
      console.log("Checking for expiring items...");

      try {
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(),
            now.getDate());
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);

        // Get all items from all users
        const itemsSnapshot = await admin.firestore()
            .collection("items")
            .where("status", "==", "In-stock")
            .get();

        const notifications = new Map(); // Group notifications by user

        itemsSnapshot.forEach((doc) => {
          const item = doc.data();
          const userId = item.userId;

          if (item.expiryDate) {
            const expiryDate = new Date(item.expiryDate);
            const timeDiff = expiryDate - today;
            const daysLeft = Math.ceil(timeDiff / (1000 * 60 * 60 * 24));

            // Check if item expires today, tomorrow, or in 3 days
            if (daysLeft >= 0 && daysLeft <= 3) {
              if (!notifications.has(userId)) {
                notifications.set(userId, []);
              }

              notifications.get(userId).push({
                itemName: item.name || "Unknown Item",
                daysLeft: daysLeft,
                category: item.category,
                subcategory: item.subcategory,
              });
            }
          }
        });

        // Send notifications to each user
        for (const [userId, items] of notifications) {
          await sendNotificationToUser(userId, items);
        }

        const notificationCount = notifications.size;
        console.log(
            `Processed ${notificationCount} users with expiring items`,
        );

        res.status(200).json({
          success: true,
          message: `Processed ${notificationCount} users with expiring items`,
          usersNotified: notificationCount,
        });
      } catch (error) {
        console.error("Error checking expiring items:", error);
        res.status(500).json({
          success: false,
          error: error.message,
        });
      }
    });

/**
 * Sends expiration notifications to a specific user
 * @param {string} userId - The user ID to send notifications to
 * @param {Array} items - Array of expiring items for the user
 * @return {Promise} Promise representing the notification operation
 */
async function sendNotificationToUser(userId, items) {
  try {
    // Get user's FCM tokens
    const userDoc = await admin.firestore()
        .collection("users")
        .doc(userId)
        .get();

    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens || [];

    if (fcmTokens.length === 0) return;

    // Group items by urgency
    const todayItems = items.filter((item) => item.daysLeft === 0);
    const tomorrowItems = items.filter((item) => item.daysLeft === 1);
    const soonItems = items.filter((item) => item.daysLeft > 1);

    // Create notification messages
    const messages = [];

    if (todayItems.length > 0) {
      messages.push({
        title: todayItems.length === 1 ?
          "Item Expires Today!" :
          `${todayItems.length} Items Expire Today!`,
        body: todayItems.length === 1 ?
          `${todayItems[0].itemName} expires today. Use it now!` :
          `${todayItems.map((item) => item.itemName).join(", ")} ` +
          "expire today.",
        data: {
          type: "expiry_today",
          count: todayItems.length.toString(),
          items: JSON.stringify(todayItems),
        },
      });
    }

    if (tomorrowItems.length > 0) {
      messages.push({
        title: tomorrowItems.length === 1 ?
          "Item Expires Tomorrow" :
          `${tomorrowItems.length} Items Expire Tomorrow`,
        body: tomorrowItems.length === 1 ?
          `${tomorrowItems[0].itemName} expires tomorrow. ` +
          "Plan to use it!" :
          `${tomorrowItems.map((item) => item.itemName).join(", ")} ` +
          "expire tomorrow.",
        data: {
          type: "expiry_tomorrow",
          count: tomorrowItems.length.toString(),
          items: JSON.stringify(tomorrowItems),
        },
      });
    }

    if (soonItems.length > 0) {
      messages.push({
        title: soonItems.length === 1 ?
          "Item Expiring Soon" :
          `${soonItems.length} Items Expiring Soon`,
        body: soonItems.length === 1 ?
          `${soonItems[0].itemName} expires in ` +
          `${soonItems[0].daysLeft} days.` :
          `${soonItems.length} items expire in the next few days.`,
        data: {
          type: "expiry_soon",
          count: soonItems.length.toString(),
          items: JSON.stringify(soonItems),
        },
      });
    }

    // Send each message to all user's devices
    for (const message of messages) {
      const payload = {
        notification: {
          title: message.title,
          body: message.body,
          icon: "default",
          sound: "default",
        },
        data: message.data,
        tokens: fcmTokens,
      };

      const response = await admin.messaging().sendMulticast(payload);

      // Handle failed tokens (remove invalid ones)
      if (response.failureCount > 0) {
        const tokensToRemove = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            tokensToRemove.push(fcmTokens[idx]);
          }
        });

        // Remove invalid tokens from user document
        if (tokensToRemove.length > 0) {
          await admin.firestore()
              .collection("users")
              .doc(userId)
              .update({
                fcmTokens: admin.firestore.FieldValue
                    .arrayRemove(...tokensToRemove),
              });
        }
      }

      console.log(`Sent notification to user ${userId}: ${message.title}`);
    }
  } catch (error) {
    console.error(`Error sending notification to user ${userId}:`, error);
  }
}

// Also create a callable function for immediate testing
exports.testExpiryNotification = functions.https.onCall(
    async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Must be logged in",
        );
      }

      const userId = context.auth.uid;

      // Send a test notification
      const testItems = [{
        itemName: "Test Item",
        daysLeft: 0,
        category: "Test Category",
        subcategory: "Test Subcategory",
      }];

      await sendNotificationToUser(userId, testItems);

      return {success: true, message: "Test notification sent"};
    },
);
