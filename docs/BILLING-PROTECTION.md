# Billing protection

Sharing needs Cloud Functions and Cloud Storage, which need the Blaze plan.
Blaze keeps the free quotas and only charges above them, so the goal here is
not to avoid Blaze but to make overspending structurally impossible.

## What the free quotas actually cover

| Resource | Free every month | 20 users, 3 photos a day |
|---|---|---|
| Firestore writes | 20,000/day | ~60/day |
| Firestore reads | 50,000/day | ~2,000/day |
| Cloud Storage | 5 GB stored | capped at 900 MB by `cleanupRelayPhotos` |
| Function invocations | 2,000,000/month | a few thousand |
| FCM | unlimited | unlimited |

Normal use will not produce a bill. The risk is a runaway trigger or abuse,
which is what the two layers below address.

## Layer 1: hard spending cap

A budget alert only tells you money was spent. `capSpending` in
`functions/src/index.ts` detaches the billing account instead, which stops
every billable service. Setup is one-time.

1. Re-attach a billing account to the project.

2. Create the Pub/Sub topic the budget publishes to:

   ```
   gcloud pubsub topics create billing-alerts --project rituals-b3bed
   ```

3. Create the budget: console.cloud.google.com > Billing > Budgets & alerts >
   Create budget.
   - Scope: project `rituals-b3bed`
   - Amount: a small fixed number, for example 1
   - Thresholds: 50%, 90%, 100% of actual spend
   - Under **Manage notifications**, tick *Connect a Pub/Sub topic to this
     budget* and select `billing-alerts`

4. Deploy:

   ```
   firebase deploy --only functions:capSpending
   ```

5. Grant the function's service account permission to change billing. Without
   this it cannot disable anything.

   ```
   gcloud beta billing accounts add-iam-policy-binding BILLING_ACCOUNT_ID \
     --member="serviceAccount:rituals-b3bed@appspot.gserviceaccount.com" \
     --role="roles/billing.projectManager"
   ```

   Find `BILLING_ACCOUNT_ID` with `gcloud beta billing accounts list`.

**What happens when it fires:** billing detaches, Functions and Storage stop,
and the app loses photo sharing and push. Firestore and Auth keep working on
free quota. Re-attach billing in the console to restore service.

To test without spending anything, publish a fake budget message:

```
gcloud pubsub topics publish billing-alerts \
  --message '{"costAmount":2,"budgetAmount":1}' --project rituals-b3bed
```

Expect billing to detach. Re-attach it afterwards.

## Layer 2: App Check

App Check rejects traffic that does not come from a genuine build of this app,
so a scraped API key cannot be used to run up usage. It is activated in
`lib/main.dart` and is skipped in debug builds and against the emulator.

1. Firebase Console > App Check.
2. Register the Android app with **Play Integrity**.
3. Register the web app with **reCAPTCHA v3** and copy the site key.
4. Build web with the key:

   ```
   flutter build web --release --dart-define=RECAPTCHA_SITE_KEY=your_key
   ```

   Without the key App Check is skipped on web, so the app still runs locally.

5. Watch the App Check metrics for a few days. Only once traffic looks correct,
   switch Firestore, Storage and Functions to **Enforced**. Enforcing early
   locks out your own builds.

For local Android debugging, register the debug token the app prints on first
run under App Check > Apps > Manage debug tokens.

## Layer 3: rules

Already in place, and worth keeping that way:

- `firestore.rules` allows an entry to be written only by its author, and
  joining only a non-full shared space.
- `storage.rules` caps uploads at 5 MB and image content types only.

## If you would rather not attach a card at all

The alternative that keeps sharing is Cloudflare R2 plus Workers: 10 GB of
storage free, no egress charges, and 100,000 Worker requests a day, enough to
send FCM messages. It means rewriting `PhotoService` and porting the three
functions, and R2 still asks for a card at signup. The cap above is far less
work for the same guarantee.
