# Backend Architecture

Details the serverless backend components on Firebase Cloud Functions.

## Service Architecture

### Serverless Architecture

Logic resides in Cloud Functions, primarily triggered by Firestore events.

### Function Organization

TypeScript functions organized by feature.

```
firebase-functions/
├── src/
│   ├── index.ts         # Entry point
│   ├── notifications.ts # Push notification logic
│   └── ...              # Other modules
├── tests/
├── package.json
└── tsconfig.json
```

### Function Template (TypeScript Example for Notification Trigger)

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
// admin.initializeApp(); // In index.ts

export const sendNewMessageNotification = functions.firestore
    .document('conversations/{conversationId}/messages/{messageId}')
    .onCreate(async (snapshot, context) => {
        const messageData = snapshot.data();
        const conversationId = context.params.conversationId;
        const senderId = messageData.senderId;

        try {
            // 1. Get participants
            const conversationDoc = await admin.firestore().collection('conversations').doc(conversationId).get();
            const participants: string[] = conversationDoc.data()?.participants || [];
            const recipients = participants.filter(userId => userId !== senderId);
            if (!recipients.length) return null;

            // 2. Get tokens (implement getFcmTokensForUsers)
            const tokens: string[] = await getFcmTokensForUsers(recipients);
            if (!tokens.length) return null;

            // 3. Construct payload
            const payload = { notification: { title: `New message`, body: messageData.text, sound: 'default' }, data: { conversationId } };

            // 4. Send notifications
            await admin.messaging().sendToDevice(tokens, payload);
            functions.logger.info("Notifications sent successfully");

        } catch (error) {
            functions.logger.error("Error sending notifications:", error);
        }
        return null;
    });

async function getFcmTokensForUsers(userIds: string[]): Promise<string[]> { /* Fetch tokens from user profiles */ return []; }
```

## Database Architecture

### Schema Design

Relies on Firebase Firestore schema defined in "Data Models" section. Indexes and Security Rules are critical.

### Data Access Layer

Cloud Functions use the Firebase Admin SDK directly for Firestore interactions.

```typescript
// Example Firestore access in Function
import * as admin from 'firebase-admin';
const db = admin.firestore();
// await db.collection('conversations').doc(id).get();
```
