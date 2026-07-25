# Play Store submission checklist

Everything below is either done, or something only you can do (keystore
password, Play Console access, hosting the privacy policy). I don't have
access to Play Console or your Google account, so the actual upload/publish
step is on you — this is meant to make that step fast.

## App identity (already configured, don't change unless you mean to)

- Package / application id: `com.syncosolve.bharathbiomedpharma`
- Firebase project: `bharathbiomedpharma-6c6c3`
- App name shown on device / store listing: **Bharath Biomed Pharma**
- Current version: `1.0.0+4` in [pubspec.yaml](../pubspec.yaml) (`versionName+versionCode`).
  Since this hasn't been published yet, feel free to reset to `1.0.0+1` if
  you'd rather start clean — just say so and I'll update it. Otherwise it's
  fine to submit as-is.

## 1. Generate your upload keystore (you run this — I don't handle passwords)

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

You'll be prompted for a store password, a key password, and some identity
fields (org name, etc. — these appear in the certificate, not the app UI).
Keep `~/upload-keystore.jks` **outside** this repo and back it up somewhere
safe (e.g. a password manager) — if you lose it, you can never publish an
update to this app again under the same listing.

Then:

```bash
cp android/key.properties.example android/key.properties
```

and fill in `storePassword`, `keyPassword`, and `storeFile` (the absolute
path to the `.jks` you just created) in `android/key.properties`. That file
is already gitignored.

## 2. Build the release bundle

Once `android/key.properties` exists:

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab` — this is the
file you upload to Play Console.

## 3. Data Safety form (Play Console → App content → Data safety)

This app collects, via Firebase:

| Data type | Collected? | Purpose | Shared with third parties? | Encrypted in transit? |
|---|---|---|---|---|
| Email address | Yes (sign-in only, not stored beyond Firebase Auth) | Account management / app functionality | No (Google/Firebase is the processor, not a separate third party under Play's definition) | Yes |
| Device / crash identifiers | Yes (via Firebase Crashlytics) | Crash reporting / analytics | No | Yes |
| App interactions | Yes (via Firebase Analytics) | Analytics | No | Yes |

- Data deletion: no user-facing account deletion flow exists in-app today —
  if Play Console requires a deletion mechanism/URL, you'll need to either
  add one or provide an email/process for deletion requests manually.
- No data is sold or shared with third parties beyond Google/Firebase as the
  service provider.

## 4. Store listing content (draft — edit freely)

- **Category suggestion:** Business, or Medical (pick whichever your Play
  Console developer account is verified for — Medical apps sometimes need
  extra verification).
- **Short description** (max 80 chars):
  `Browse and present Bharath Biomed's pharma product catalog, online or off.`
- **Full description** (draft, expand as you like):
  > The Bharath Biomed Pharma app is your convenient gateway to explore and
  > present a wide range of high-quality pharmaceutical products. Browse
  > products organized by department, select the ones you want to showcase,
  > and present them full-screen in a swipeable, zoomable slideshow — built
  > for field sales conversations with or without an internet connection.
  > Sign in once to sync the latest catalog, then use the app fully offline.
- **Content rating questionnaire:** no user-generated content, no ads, no
  violence/mature content — should land on "Everyone".
- **Screenshots / feature graphic:** I have no Android emulator available in
  this environment to capture these myself. Run the app on a real device or
  an Android emulator (`flutter run --release`) and capture a few screens:
  login, catalog with a couple of departments expanded, and the slideshow.

## 5. Privacy policy

Draft is at [PRIVACY_POLICY.md](PRIVACY_POLICY.md). Play Console requires a
**public URL**, not a file — host it on GitHub Pages, Firebase Hosting, or
your company site, then paste that URL into Play Console → App content →
Privacy policy.

## 6. Final upload (manual, in Play Console)

1. Create the app listing in Play Console (if not already created).
2. App content section: complete Data safety, Privacy policy URL, content
   rating questionnaire, target audience.
3. Production (or Internal testing track first, recommended) → upload the
   `.aab` from step 2.
4. Fill in store listing text/images from step 4.
5. Submit for review.

I'd recommend releasing to an **Internal testing** track first and installing
it on a real device before promoting to Production, since I can't verify
the signed Android build's actual on-device behavior from here (only its
compile success).
