# Firebase Configuration

This directory contains Firebase security rules (gitignored for security).

## Files

- **`firestore.rules`** - Firestore security rules (gitignored)
- **`database.rules.json`** - Realtime Database security rules (gitignored)
- **`RULES.example.md`** - Generic documentation on setting up rules

## Security Notes

⚠️ **IMPORTANT**: These rule files are gitignored and should never be committed to public repositories.

## Deploying Rules

Use the Firebase Console to deploy rules:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to Firestore/Realtime Database → Rules
4. Copy and paste your rules from these files

## Resources

- [Firestore Security Rules Documentation](https://firebase.google.com/docs/firestore/security/get-started)
- [Realtime Database Rules Documentation](https://firebase.google.com/docs/database/security)

