# Make Your App Data Appear in Firebase

Follow these steps so when you add clients, staff, or sessions in the app, they show up in Firebase.

---

## 1. Create / use a Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/).
2. Open your project **mandb-maligaya** (or create one and re-run FlutterFire configure).
3. In the left sidebar, click **Build → Firestore Database**.

---

## 2. Create the Firestore database (if you haven’t)

1. Click **Create database**.
2. Choose **Start in production mode** (we’ll add rules next).
3. Pick a location (e.g. `us-central1`) and confirm.
4. Wait until the database is created.

---

## 3. Set Firestore security rules

Your app must be allowed to read/write. In Firestore:

1. Go to **Firestore Database → Rules**.
2. Replace the existing rules with the contents of the **`firestore.rules`** file in this project (or copy below).
3. Click **Publish**.

**Rules to use (allow signed-in users to read/write your collections):**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /login-accounts/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /clients/{docId} {
      allow read, write: if request.auth != null;
    }
    match /personnel/{docId} {
      allow read, write: if request.auth != null;
    }
    match /sessions/{docId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## 4. Enable Authentication (Email/Password)

1. In Firebase Console go to **Build → Authentication**.
2. Click **Get started** if needed.
3. Open the **Sign-in method** tab.
4. Enable **Email/Password** and save.

Your app only writes to Firestore when a user is **signed in**. So you must sign up / log in in the app first.

---

## 5. Use the app

1. **Run the app** (e.g. `flutter run -d chrome` for web).
2. **Sign up** or **Log in** with email and password.
3. Then:
   - **Add a client** (Clients page) → document in `clients`.
   - **Add staff** (Personnel page) → document in `personnel`.
   - **Add a session** (Dashboard → Add Session) → document in `sessions`.

---

## 6. Check that data appears in Firebase

1. In Firebase Console go to **Firestore Database**.
2. You should see collections: **clients**, **personnel**, **sessions**, **login-accounts**.
3. Click a collection and open a document to see the fields you added in the app.

---

## Quick checklist

| Step | Where | What to do |
|------|--------|------------|
| Firestore exists | Firebase Console → Firestore | Create database if missing |
| Rules allow writes | Firestore → Rules | Paste rules above and **Publish** |
| Auth enabled | Authentication → Sign-in method | Enable **Email/Password** |
| You are signed in | In the app | Sign up or log in before adding data |
| Add data | App (Clients / Personnel / Dashboard) | Add client, staff, or session |

---

## If data still doesn’t appear

- **Red error in app**  
  Check the browser/IDE console (F12 → Console). If you see “permission-denied”, the Firestore rules are blocking; re-publish the rules from step 3.

- **No error but no collections**  
  Make sure you clicked **Add** / **Save** in the app and saw a success message. Then refresh the Firestore Console and look at **clients**, **personnel**, or **sessions**.

- **Wrong project**  
  Your app uses project **mandb-maligaya** (see `lib/firebase_options.dart`). In Firebase Console, ensure you’re in that project.
