# Firebase Security Rules Setup Guide

This is a generic guide for setting up Firebase security rules. The actual rules are kept in the `firebase/` directory and gitignored.

## Firestore Rules Template

Create a `firestore.rules` file with the following structure:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Define your rules here based on:
    // - User authentication requirements
    // - Data access permissions
    // - Read/write restrictions per collection
    
    // Example structure (customize for your needs):
    // match /collection/{docId} {
    //   allow read, write: if <your_conditions>;
    // }
  }
}
```

## Realtime Database Rules Template

Create a `database.rules.json` file with the following structure:

```json
{
  "rules": {
    // Define your RTDB rules here
    // Example structure (customize for your needs):
    // "path": {
    //   ".read": "auth != null",
    //   ".write": "auth != null"
    // }
  }
}
```

## Best Practices

1. **Never allow open access** in production
2. **Test rules thoroughly** using Firebase Console simulator
3. **Use authentication** checks (`auth != null`)
4. **Validate data** on write operations
5. **Follow principle of least privilege**

## Resources

- [Firestore Security Rules Docs](https://firebase.google.com/docs/firestore/security/get-started)
- [RTDB Security Rules Docs](https://firebase.google.com/docs/database/security)
- [Rules Testing Guide](https://firebase.google.com/docs/rules/unit-tests)

