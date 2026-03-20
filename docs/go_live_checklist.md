# DearDays — Go-Live Checklist
## Target countries: US · UK · Canada · India · Netherlands
> Every item has a "How to do it" section. Work through phases in order — later phases depend on earlier ones.

---

## PHASE 0 — FOUNDATION

---

### Legal entity

- [ ] **Decide which legal entity publishes the app**
  > **How:** Choose based on your country of residence:
  > - **UK**: Register a Limited Company (Ltd) via Companies House (companieshouse.gov.uk) — £12 online, takes 24 hours. Alternatively operate as a Sole Trader (no registration needed, just self-assessment tax).
  > - **India**: Register a Private Limited Company via MCA portal (mca.gov.in) or operate as a Sole Proprietor for early stage.
  > - **Other**: Sole trader / freelancer is fine for launch. Upgrade to Ltd/LLC once revenue justifies it.
  > - **Why it matters**: App stores pay out to a legal entity. Apple requires a D-U-N-S number (free, takes ~5 days to get at dnb.com/duns-number.html).

- [ ] **Register business in your country of residence**
  > **How:**
  > - **UK**: companieshouse.gov.uk → "Incorporate a company" → £12 online. You get a Company Registration Number (CRN) in 24–48 hours.
  > - **India**: mca.gov.in → SPICe+ form for Private Ltd. Or skip and use sole proprietorship with a current bank account.
  > - Get a D-U-N-S number (required for Apple): go to dnb.com → "Get a D-U-N-S Number" → select "Apple Developer" → free, takes 3–5 business days.

- [ ] **Open a business bank account**
  > **How:**
  > - **UK**: Monzo Business, Starling, or HSBC Business. Monzo/Starling open in ~1 day online.
  > - **India**: ICICI, HDFC, or SBI current account. Requires GST registration if turnover > ₹20L.
  > - You need this to receive payouts from Apple and Google. Both pay in local currency.
  > - Apple pays monthly, ~45 days after the month ends. Google pays monthly when balance > $1.

---

### App Store accounts

- [ ] **Create Apple Developer account ($99/year)**
  > **How:**
  > 1. Go to developer.apple.com/programs/enroll
  > 2. Sign in with your Apple ID (or create one)
  > 3. Select "Company/Organization" (not Individual — gives more flexibility)
  > 4. Enter your D-U-N-S number (must be already approved)
  > 5. Pay $99/year by card
  > 6. Apple verifies your business — takes 2–7 days
  > 7. Once approved, go to appstoreconnect.apple.com to create your app record

- [ ] **Create Google Play Developer account ($25 one-time)**
  > **How:**
  > 1. Go to play.google.com/console
  > 2. Sign in with a Google account (use your business email)
  > 3. Pay $25 one-time registration fee
  > 4. Complete the developer profile form (name, address, phone)
  > 5. Verify your phone number
  > 6. Account is usually approved within 48 hours
  > 7. Then create your first app via "Create app" button

- [ ] **Set up banking and tax info in both consoles**
  > **How (Apple)**:
  > 1. appstoreconnect.apple.com → Agreements, Tax, and Banking
  > 2. Accept the "Paid Apps" agreement
  > 3. Add bank account (SWIFT/IBAN for UK/NL/India, routing+account for US)
  > 4. Complete tax forms — for India use your PAN card details; for UK use your UTR number
  >
  > **How (Google)**:
  > 1. play.google.com/console → Payments profile
  > 2. Add bank account under "Payment settings"
  > 3. Google will make a small test deposit (~$0.10) to verify — confirm it within 7 days
  > 4. Complete tax info under "Tax information"

---

## PHASE 1 — LEGAL DOCUMENTS

> **Practical tip**: Use a lawyer for a full review eventually, but for launch you can write these yourself using templates and then get them reviewed. Tools like iubenda.com or termly.io can generate a base that you customize. Budget £300–£600 for a lawyer to review before you hit 1,000 users.

---

### Privacy Policy

- [ ] **Write Privacy Policy covering all 5 jurisdictions**
  > **How:**
  > 1. Use iubenda.com or termly.io to generate a base privacy policy — costs ~$10/month
  > 2. OR copy an open-source template (e.g. github.com/nicowillis/privacy-policy-template) and customize
  > 3. The policy must cover: what data you collect, why, who you share it with, how long you keep it, user rights, and contact details
  > 4. Structure it with a General section first, then jurisdiction-specific appendices
  > 5. Write in plain English — GDPR explicitly requires "clear and plain language"

- [ ] **Host Privacy Policy at a public URL**
  > **How:**
  > 1. Simplest: create a GitHub Pages site (free) at yourname.github.io/deardays-privacy
  > 2. Or add a `/privacy` route to a simple website (even a Carrd.co or Notion page works)
  > 3. The URL must work without login — Apple and Google verify it during review
  > 4. Use HTTPS (required by both stores)
  > 5. Keep the URL stable — changing it requires an app update

- [ ] **CCPA section — "Do Not Sell or Share My Personal Information" (US)**
  > **How:** Add a section titled "Your California Privacy Rights" that says:
  > - What categories of personal data you collect (identifiers, usage data, commercial info)
  > - That you do NOT sell personal data to third parties for advertising
  > - How to exercise the right: "Tap Settings → Privacy → Do Not Sell My Data in the DearDays app"
  > - Response time: 45 days
  > - That submitting the request is free and you won't discriminate against users who opt out

- [ ] **UK GDPR section**
  > **How:** Add a section titled "UK Users — Your Rights Under UK GDPR" covering:
  > - **Legal basis**: Journal storage = contract performance. AI features = consent. Analytics = legitimate interest.
  > - **Rights**: Right to access (respond in 30 days), right to rectify, right to erase, right to data portability (export as JSON/PDF), right to restrict processing, right to object
  > - **Supervisory authority**: "You may lodge a complaint with the Information Commissioner's Office (ICO) at ico.org.uk"
  > - **Contact**: your email address for data requests (e.g. privacy@deardays.app)

- [ ] **EU GDPR section (Netherlands)**
  > **How:** Nearly identical to UK GDPR section but:
  > - Replace ICO with: "Autoriteit Persoonsgegevens (AP), autoriteitpersoonsgegevens.nl"
  > - Add: "Data transfers to the United States (Supabase, OpenAI, RevenueCat) are protected by Standard Contractual Clauses approved by the European Commission."
  > - Mention your legal basis for each type of processing explicitly

- [ ] **PIPEDA + Quebec Law 25 section (Canada)**
  > **How:** Add a section titled "Canadian Users — Privacy Rights" covering:
  > - The 10 PIPEDA fair information principles (just reference them: "We comply with Canada's Personal Information Protection and Electronic Documents Act")
  > - Quebec users: "Residents of Quebec have additional rights under Law 25, including the right to data portability and the right to be informed of automated decision-making"
  > - List all third-party processors with their country: "Supabase (USA), OpenAI (USA), RevenueCat (USA)"
  > - **French translation**: The entire privacy policy must be available in French for Quebec users. Use DeepL or a professional translator. Cost: ~£100–£200.

- [ ] **DPDPA section (India)**
  > **How:** Add a section titled "Indian Users — Digital Personal Data Protection Act 2023" covering:
  > - Your role as a "Data Fiduciary" (you decide why and how data is processed)
  > - Data principal rights: access, correction, erasure, grievance
  > - **Grievance Officer**: "Our Grievance Officer is [Your Name], reachable at grievance@deardays.app. All grievances will be acknowledged within 48 hours and resolved within 30 days."
  > - Parental consent: "Users under 18 require verifiable parental consent before creating an account"
  > - Cross-border transfer: "Your data is stored and processed on servers in the United States. We take reasonable precautions to protect it during transfer."

- [ ] **AI sub-processors section**
  > **How:** Add a table titled "Our Technology Partners" listing:
  > ```
  > | Service      | Company          | Country | Purpose                              |
  > | Supabase     | Supabase Inc.    | USA     | Database, auth, file storage         |
  > | OpenAI       | OpenAI LLC       | USA     | Voice transcription (optional), AI   |
  > | RevenueCat   | RevenueCat Inc.  | USA     | Subscription management              |
  > | [Anthropic]  | Anthropic PBC    | USA     | AI features (if active)              |
  > ```
  > Then add: "Voice transcription via OpenAI only occurs when you explicitly choose 'Use AI Transcription'. Your voice is never sent to any server without your consent."

---

### Terms of Service

- [ ] **Write Terms of Service**
  > **How:**
  > 1. Use termsfeed.com or Docracy to generate a base
  > 2. Key sections needed: Acceptance of Terms, Account Registration, Subscription and Payments, User Content, Acceptable Use, Intellectual Property, Disclaimers, Limitation of Liability, Termination, Governing Law
  > 3. Keep it under 2,000 words — no one reads 10-page terms

- [ ] **Host at public URL**
  > **How:** Same approach as Privacy Policy. Use a separate URL like `/terms`. Both documents must be linked from your app's Settings screen and the App Store/Play Store listing.

- [ ] **Minimum age clauses**
  > **How:** Add to your Terms: "You must be at least 13 years old (16 in the Netherlands, 18 in India) to use DearDays. By creating an account you confirm you meet the minimum age requirement for your country."

- [ ] **Subscription auto-renewal disclosure**
  > **How:** Add a section "Subscriptions" stating:
  > - Subscription automatically renews unless cancelled at least 24 hours before the renewal date
  > - How to cancel: iOS → Settings → [Your Name] → Subscriptions. Android → Google Play → Subscriptions.
  > - No refunds for the current billing period (except where required by law)
  > - Price may change with 30 days' notice

- [ ] **EU 14-day right of withdrawal**
  > **How:** Add: "EU and UK customers have a statutory right to cancel within 14 days of purchase. By starting to use DearDays AI features immediately upon subscription, you agree to waive this right." — this waiver is legal under EU Consumer Rights Directive if the user explicitly consents, which they do by ticking a box at purchase.

- [ ] **French translation (Quebec)**
  > **How:** Same as Privacy Policy. Translate using DeepL first, then have a French speaker review it. The legal standard in Quebec is "substantially equivalent" — a good machine translation reviewed by a bilingual person is sufficient for launch.

---

### Cookie / Tracking Policy

- [ ] **Write Cookie Policy**
  > **How:** For a mobile app you don't use browser cookies, but you do use device identifiers and SDKs. Write a short "Tracking and Analytics" section in your Privacy Policy covering:
  > - RevenueCat uses a device identifier to track subscriptions — this is essential (no consent needed)
  > - Crash reporting (if you add Sentry/Firebase Crashlytics) — essential, no consent needed
  > - No advertising identifiers or cross-app tracking used
  > This is simpler than a full cookie policy since it's a mobile app, not a website.

- [ ] **Confirm no advertising/tracking SDKs**
  > **How:** Run `flutter pub deps | grep -i analytics` and check your `pubspec.yaml` for any ad or analytics packages (Firebase Analytics, Facebook SDK, AppFlyer, etc.). If none are present, your tracking policy is simple. If you add any later, you'll need to update the policy and App Store labels.

---

## PHASE 2 — DATA PROCESSING AGREEMENTS

---

- [ ] **Sign Supabase DPA**
  > **How:**
  > 1. Log into your Supabase dashboard at app.supabase.com
  > 2. Go to Settings (bottom left gear icon) → Legal
  > 3. Find "Data Processing Agreement" and click "Sign DPA"
  > 4. Fill in your company name and address
  > 5. Download and save the signed PDF — keep it on file
  > 6. Takes 5 minutes. No cost.

- [ ] **Sign OpenAI DPA**
  > **How:**
  > 1. Log into platform.openai.com
  > 2. Go to Settings (top right) → Organization → Privacy
  > 3. Find "Data Processing Addendum" and click to sign
  > 4. Confirm: under the API DPA, OpenAI does NOT train on your users' data
  > 5. Download and save the signed copy
  > 6. Takes 5 minutes. No cost.

- [ ] **Request OpenAI SCCs (Netherlands + UK)**
  > **How:**
  > 1. After signing the OpenAI DPA, email privacy@openai.com
  > 2. Subject: "Request for Standard Contractual Clauses — API customers"
  > 3. Body: "We are an API customer processing personal data of EU and UK residents. Please provide the applicable Standard Contractual Clauses and UK IDTA."
  > 4. OpenAI typically responds within 5 business days with a PDF
  > 5. Store this with your other DPAs
  > 6. Alternative: check openai.com/policies — SCCs may be available for self-service download

- [ ] **Sign RevenueCat DPA**
  > **How:**
  > 1. Log into app.revenuecat.com
  > 2. Go to Account → Settings → Privacy
  > 3. Look for "Data Processing Agreement" — if not visible, email support@revenuecat.com requesting it
  > 4. Sign electronically and save a copy

- [ ] **Sign Anthropic DPA (if using Claude)**
  > **How:**
  > 1. Go to anthropic.com/legal and look for the DPA link
  > 2. If not self-service, email privacy@anthropic.com requesting a DPA
  > 3. Mention you are an API customer processing EU personal data
  > 4. Their API Terms of Service already include a no-training clause — the DPA formalizes the rest

- [ ] **Sign Google Cloud DPA (if using Gemini)**
  > **How:**
  > 1. Log into console.cloud.google.com
  > 2. Go to IAM & Admin → Data Processing Addendum
  > 3. Click "Review and Accept" next to the Cloud Data Processing Addendum (CDPA)
  > 4. This covers Gemini API calls made through Google Cloud
  > 5. Takes 5 minutes. Automatically logged to your account.

- [ ] **UK ICO Registration**
  > **How:**
  > 1. Go to ico.org.uk/registration
  > 2. Click "Register now"
  > 3. Answer the questionnaire about your processing activities (journaling app, ~Tier 1)
  > 4. Fee: £40/year for micro-organisations (less than 10 staff, turnover < £632k)
  > 5. Pay by card
  > 6. You'll receive an ICO registration number — add it to your Privacy Policy
  > 7. Set a calendar reminder to renew annually — ICO sends reminders by email

- [ ] **India Grievance Officer**
  > **How:**
  > 1. Appoint a named individual (can be yourself) as Grievance Officer
  > 2. This person must be reachable from India — an email address is sufficient for launch
  > 3. Create a dedicated email: grievance@deardays.app (or use your existing business email)
  > 4. Add to Privacy Policy: full name, email, and "Grievances will be acknowledged within 48 hours and resolved within 30 days"
  > 5. Add a "Raise a Grievance" option in the app Settings screen (see Phase 4)
  > 6. Set up email monitoring — you're legally required to respond within 30 days

---

## PHASE 3 — DATABASE MIGRATION

- [ ] **Run migration 028 on production Supabase**
  > **How:**
  > 1. Make sure you have the Supabase CLI installed: `npm install -g supabase`
  > 2. Link your local project to production: `supabase link --project-ref YOUR_PROJECT_REF`
  > 3. Preview what will be applied: `supabase db diff`
  > 4. Apply to production: `supabase db push`
  > 5. Verify in Supabase dashboard → Table Editor that new tables appear:
  >    - `grievance_requests`
  >    - `consent_audit_log`
  > 6. Verify new columns on `profiles` table:
  >    - `country_code`, `marketing_consent_given_at`, `casl_channels`,
  >      `parental_consent_token`, `age_verified_at`, `consent_version`,
  >      `data_export_requested_at`
  > 7. **Test on staging first** — run `supabase db push --db-url YOUR_STAGING_URL` on a staging project before touching production

- [ ] **Verify migration 006 fields are populated**
  > **How:** Run this query in Supabase SQL Editor:
  > ```sql
  > SELECT
  >   COUNT(*) AS total_users,
  >   COUNT(consent_given_at) AS has_consent,
  >   COUNT(date_of_birth) AS has_dob,
  >   COUNT(CASE WHEN do_not_sell = true THEN 1 END) AS do_not_sell_count
  > FROM profiles;
  > ```
  > If `has_consent` is much lower than `total_users`, you may need to backfill for existing users — or accept that pre-launch users will be re-prompted on next launch.

---

## PHASE 4 — IN-APP COMPLIANCE FEATURES

---

### Age gate

- [ ] **Show DOB screen before account creation**
  > **How:** Add a new screen before your existing sign-up/onboarding screen. Show a date picker asking for date of birth. Store the result temporarily in memory (not DB yet — they haven't signed up). After they pass the age check, proceed to sign-up. Never ask age after sign-up.

- [ ] **Block underage users with a dead-end screen**
  > **How:** After DOB entry, calculate age server-side (don't trust client). Determine minimum age from country:
  > - Detect country via the device locale (`Platform.localeName`) or IP geolocation (Supabase Edge Function with `request.headers['x-forwarded-for']`)
  > - US/UK/Canada: block if under 13
  > - Netherlands: block if under 16
  > - India: block if under 18 (or show parental consent flow)
  >
  > **Dead-end screen** must say something like "DearDays is not available for users under [age]" with no bypass option. COPPA specifically says you cannot redirect underage US users to another service.

- [ ] **Record `age_verified_at` in consent_audit_log**
  > **How:** After the user passes the age check and creates their account, insert a row:
  > ```dart
  > await supabase.from('consent_audit_log').insert({
  >   'user_id': userId,
  >   'event': 'age_verified',
  >   'country_code': detectedCountry,
  >   'consent_version': currentConsentVersion,
  > });
  > ```

---

### Consent flow

- [ ] **Show consent on first launch before any data is collected**
  > **How:** In your app router, add a check: if `profiles.consent_given_at` is null → redirect to a ConsentScreen before allowing the user anywhere in the app. This screen should show scrollable Terms + Privacy Policy text with links, followed by the tick boxes below.

- [ ] **Separate consent ticks (never pre-ticked)**
  > **How:** Build a consent screen with 4 `Checkbox` widgets, all defaulting to `false`:
  > ```
  > [ ] I have read and agree to the Terms of Service and Privacy Policy [links]
  > [ ] I consent to DearDays processing my mood and wellbeing data to personalise my journal experience
  > [ ] I'd like to receive tips and updates by push notification (optional)
  > [ ] I'd like to receive occasional emails about DearDays (optional)
  > ```
  > The first two are required to proceed. The last two are optional (marketing). "Confirm" button is disabled until first two are ticked.

- [ ] **Record each consent event in consent_audit_log**
  > **How:** On tapping "Confirm", insert one row per consent event:
  > ```dart
  > final events = [
  >   {'event': 'consent_given', 'consent_version': 'v1.0'},
  >   {'event': 'health_consent_given', 'consent_version': 'v1.0'},
  >   if (pushTicked) {'event': 'marketing_opt_in', 'consent_version': 'v1.0'},
  >   if (emailTicked) {'event': 'marketing_opt_in', 'consent_version': 'v1.0'},
  > ];
  > for (final e in events) {
  >   await supabase.from('consent_audit_log').insert({
  >     ...e, 'user_id': userId, 'country_code': detectedCountry,
  >   });
  > }
  > ```
  > Also update `profiles` with `consent_given_at`, `health_consent_given_at`, `consent_version`.

---

### AI transcription consent

- [ ] **Add disclosure text near voice record button**
  > **How:** In `RecordingScreen._buildPromptSection()` or just below the mic button, add a small subtitle text:
  > ```dart
  > Text(
  >   'Transcribed on your device · AI optional',
  >   style: GoogleFonts.manrope(fontSize: 11, color: colors.textMuted),
  > )
  > ```
  > This is already compliant after the code changes in Phase 0. This text makes it visible to users.

- [ ] **Verify no network call when on-device STT works**
  > **How:** In debug mode, check the Dio interceptor logs in `AiService`. When a voice entry is processed with a non-empty on-device transcript, you should see NO `POST /ai-transcribe` request in the logs. Test this by recording 5–10 seconds of speech and confirming only `/ai-polish` and `/ai-chat` calls are made (no `/ai-transcribe`).

---

### Settings screen additions

- [ ] **Download My Data button**
  > **How:**
  > 1. Add a "Privacy" section to your Settings screen
  > 2. Add a button "Download My Data"
  > 3. On tap: set `profiles.data_export_requested_at = now()`, insert a `consent_audit_log` row with `event: 'data_export_requested'`
  > 4. Trigger a Supabase Edge Function that queries all the user's data (journal_entries, profiles, chapters) and emails them a JSON file
  > 5. The export must arrive within 30 days (GDPR). Aim for same-day for good UX.
  > 6. Example edge function endpoint: `POST /export-user-data` — auth-gated, builds JSON, sends via Resend/SendGrid

- [ ] **Delete My Account button**
  > **How:**
  > 1. Add "Delete My Account" button in Settings → Privacy section
  > 2. Show a confirmation dialog: "This will permanently delete all your data after 30 days. Are you sure?"
  > 3. On confirm: set `profiles.account_deleted_at = now()`, insert `consent_audit_log` row
  > 4. Log the user out immediately
  > 5. The existing `run_data_retention()` cron job will purge the data after 30 days (already implemented in migration 006)
  > 6. Send a confirmation email: "Your deletion request has been received. Your data will be permanently deleted on [date]."

- [ ] **Do Not Sell My Data toggle (US)**
  > **How:**
  > 1. Add a toggle in Settings → Privacy labelled "Do Not Sell My Personal Data"
  > 2. Show it to all users but note it's a US legal right
  > 3. On toggle: `UPDATE profiles SET do_not_sell = true WHERE id = auth.uid()`
  > 4. Insert `consent_audit_log` row: `event: 'do_not_sell_enabled'`
  > 5. In practice, DearDays doesn't sell data anyway — but you must offer the toggle for CCPA compliance

- [ ] **Marketing Preferences**
  > **How:**
  > 1. Add "Notification Preferences" in Settings
  > 2. Two toggles: "Tips and product updates (push)" and "Emails from DearDays"
  > 3. On toggle off: `UPDATE profiles SET marketing_consent_withdrawn_at = now()`
  > 4. Insert `consent_audit_log` row: `event: 'marketing_opt_out'`
  > 5. Honour this in your push notification service — don't send marketing pushes to opted-out users

- [ ] **Raise a Grievance (India)**
  > **How:**
  > 1. In Settings → Privacy, add "Raise a Grievance" — show this to all users, not just India
  > 2. Screen shows a form: Type (dropdown: Data Access / Correction / Erasure / Other), Description (text field), Submit button
  > 3. On submit: insert into `grievance_requests` table with `user_id`, `type`, `description`, `country_code`
  > 4. Send an email to your Grievance Officer email address
  > 5. Show the user: "Your grievance has been received. We will respond within 30 days."
  > 6. Set up an email alert or daily Supabase query to check for open grievances approaching their 30-day `due_at`

- [ ] **Privacy Policy and Terms links**
  > **How:**
  > 1. In Settings, add two tappable rows: "Privacy Policy" and "Terms of Service"
  > 2. Use `url_launcher` package to open the hosted URLs in the system browser:
  >    ```dart
  >    await launchUrl(Uri.parse('https://deardays.app/privacy'));
  >    ```
  > 3. Alternatively use an in-app WebView with `webview_flutter` package

- [ ] **Show consent version + Review consents**
  > **How:**
  > 1. In Settings → Privacy, show: "Consents accepted: v1.0 on [date]"
  > 2. Add a "Review & update consents" option that re-opens the consent screen
  > 3. When your Privacy Policy changes significantly, bump the version string (e.g. "v1.1"), detect that `profiles.consent_version != currentVersion`, and re-prompt affected users on next launch

---

### French language support

- [ ] **Set up Flutter localisation**
  > **How:**
  > 1. Add to `pubspec.yaml`:
  >    ```yaml
  >    dependencies:
  >      flutter_localizations:
  >        sdk: flutter
  >      intl: ^0.19.0
  >    flutter:
  >      generate: true
  >    ```
  > 2. Create `lib/l10n/app_en.arb` and `lib/l10n/app_fr.arb` with all UI strings
  > 3. Run `flutter gen-l10n` to generate the Dart localization classes
  > 4. Wrap `MaterialApp` with `localizationsDelegates` and `supportedLocales`
  > 5. Start with the highest-priority strings: onboarding, consent flow, settings labels, error messages

- [ ] **Detect French/Quebec users**
  > **How:**
  > ```dart
  > final locale = WidgetsBinding.instance.platformDispatcher.locale;
  > final isQuebec = locale.languageCode == 'fr' ||
  >     (locale.countryCode == 'CA' && locale.languageCode == 'fr');
  > ```
  > Set the app locale accordingly. Flutter will automatically use `app_fr.arb` strings.

---

## PHASE 5 — APP STORE SETUP

---

### Apple App Store Connect

- [ ] **Create app record**
  > **How:**
  > 1. Go to appstoreconnect.apple.com
  > 2. Click "+" → "New App"
  > 3. Select platform: iOS (and optionally macOS if you want Mac support)
  > 4. Enter App Name: "DearDays", Primary Language: English, Bundle ID: com.yourname.deardays
  > 5. SKU: a unique identifier for your records (e.g. "DEARDAYS001")
  > 6. User Access: Full Access

- [ ] **Privacy Nutrition Labels**
  > **How:**
  > 1. In App Store Connect → Your App → App Privacy
  > 2. Click "Get Started"
  > 3. Answer each data category:
  >    - **Contact Info → Email address**: Collected, Used for account management, Linked to identity, Not used for tracking
  >    - **Usage Data → App interactions**: Collected, Used to improve the app, Linked to identity, Not used for tracking
  >    - **Audio → Voice recordings**: Collected only when user explicitly consents to AI transcription, Not linked to identity after transcription, Deleted after processing
  >    - **Health & Fitness → Other health data (mood)**: Collected, Used to personalise app, Linked to identity
  >    - **User Content → Other user content (journal entries)**: Select "Not collected" — entries are encrypted on device, server only sees ciphertext
  > 4. Click Save — this shows on your App Store product page

- [ ] **Age Rating**
  > **How:**
  > 1. App Store Connect → Your App → App Information → Rating
  > 2. Click "Edit" and complete the questionnaire
  > 3. Answer "None" to violence, sexual content, profanity, gambling, etc.
  > 4. Expected result: **4+** (suitable for all ages — age gate is handled in-app)
  > 5. Note: the in-app age gate is your legal responsibility — the 4+ rating just means the app itself has no objectionable content

- [ ] **Export Compliance**
  > **How:**
  > 1. When submitting a build, Xcode will ask about encryption
  > 2. Select **"Yes"** — the app does use encryption (AES-256 for journal content)
  > 3. Select **"Yes, it qualifies for exemption"** — standard AES encryption is exempt from US export regulations (EAR 740.17)
  > 4. You do NOT need a CCATS (Commodity Classification Automated Tracking System) number
  > 5. To avoid answering this every build: add to your `Info.plist`:
  >    ```xml
  >    <key>ITSAppUsesNonExemptEncryption</key>
  >    <false/>
  >    ```

- [ ] **Territory Availability**
  > **How:**
  > 1. App Store Connect → Your App → Pricing and Availability
  > 2. Under "Availability", click "Edit"
  > 3. Select specific territories: United States, United Kingdom, Canada, India, Netherlands
  > 4. Deselect all others if you want a controlled launch
  > 5. You can add more territories later without a new app review

- [ ] **Pricing per territory**
  > **How:**
  > 1. App Store Connect → Your App → Subscriptions → [Your subscription group]
  > 2. For each subscription tier (monthly, yearly), click to edit pricing
  > 3. Set a base price in USD, then Apple auto-generates prices for other currencies
  > 4. For India: manually override the INR price. Suggested: ₹249–₹299/month, ₹1,999–₹2,499/year
  > 5. Apple's lowest price tier in India starts at ₹99 — price sensitivity is high, stay competitive

- [ ] **App Review notes**
  > **How:** When submitting for review, in the "Notes for App Review" field write:
  > ```
  > Test account: test@deardays.app / TestPass123!
  > - The app requires microphone permission for voice journaling
  > - Journal content is encrypted on-device using AES-256 before transmission
  > - The app uses standard encryption and qualifies for EAR exemption
  > - Voice AI transcription is optional and only activated with explicit user consent
  > ```

---

### Google Play Console

- [ ] **Create app**
  > **How:**
  > 1. play.google.com/console → "Create app"
  > 2. App name: DearDays, Default language: English, App or Game: App, Free or Paid: Free (with in-app subscriptions)
  > 3. Accept the developer policies
  > 4. You'll be taken to the app dashboard — complete the "Set up your app" tasks list before you can publish

- [ ] **Data Safety section**
  > **How:**
  > 1. Play Console → Your App → Policy → Data Safety
  > 2. Click "Start" to begin the questionnaire
  > 3. **Does your app collect or share any of the required user data types?** → Yes
  > 4. Declare each data type:
  >    - Email → Collected, Required for account, Not shared, Encrypted, User can delete
  >    - User ID → Collected, Required for account, Not shared, Encrypted
  >    - Audio files → Collected only with explicit consent for AI transcription, Processed but not stored, User can delete
  >    - App interactions → Collected, App functionality, Not shared
  >    - Crash logs → Collected, App functionality (if you add crash reporting)
  > 5. **Does your app use encryption?** → Yes
  > 6. **Can users request data deletion?** → Yes — describe where in app (Settings → Delete Account)
  > 7. Submit — Google may ask for clarification via email

- [ ] **Content Rating**
  > **How:**
  > 1. Play Console → Policy → App Content → Content Rating
  > 2. Click "Start questionnaire" → select "Utility" as the category
  > 3. Answer all questions — expected rating: **Everyone** or **Everyone 10+**
  > 4. Submit — rating is applied automatically

- [ ] **Country targeting**
  > **How:**
  > 1. Play Console → Your App → Production → Countries/Regions
  > 2. Click "Add countries/regions"
  > 3. Select: United States, United Kingdom, Canada, India, Netherlands
  > 4. Save — this takes effect immediately once the app is published

- [ ] **Pricing per country**
  > **How:**
  > 1. Play Console → Monetize → Subscriptions → [Your subscription]
  > 2. Under "Countries", each country shows a price
  > 3. Click on India to override the auto-converted price — set INR manually (e.g. ₹249/month)
  > 4. For Netherlands, the EUR price is auto-set — verify it looks reasonable (~€3.99/month)

---

## PHASE 6 — SUBSCRIPTIONS & PAYMENTS

- [ ] **Configure subscription products in App Store Connect**
  > **How:**
  > 1. App Store Connect → Your App → Subscriptions
  > 2. Create a Subscription Group (e.g. "DearDays Premium")
  > 3. Add subscription: Reference Name "Monthly", Product ID "com.deardays.premium.monthly", Duration: 1 Month
  > 4. Add subscription: Reference Name "Yearly", Product ID "com.deardays.premium.yearly", Duration: 1 Year
  > 5. Set pricing for each (monthly: ~$3.99 USD, yearly: ~$29.99 USD)
  > 6. Add localised descriptions in English (and French for Canada)
  > 7. Submit for review — subscription products are reviewed alongside the app

- [ ] **Configure subscription products in Google Play Console**
  > **How:**
  > 1. Play Console → Monetize → Subscriptions → Create subscription
  > 2. Product ID: "premium_monthly", Name: "DearDays Premium Monthly"
  > 3. Add base plan: Monthly, auto-renewing, set price per country
  > 4. Repeat for yearly subscription
  > 5. These don't require separate review — they go live when the app is published
  > 6. Make sure RevenueCat product IDs match exactly what you enter here

- [ ] **RevenueCat webhook setup**
  > **How:**
  > 1. app.revenuecat.com → Your Project → Integrations → Webhooks
  > 2. Add endpoint: your Supabase Edge Function URL (`/revenuecat-webhook`)
  > 3. This already exists in your codebase at `supabase/functions/revenuecat-webhook/index.ts`
  > 4. Test in sandbox: make a test purchase in Xcode simulator → check Supabase `profiles.is_subscribed` updates to `true`
  > 5. Repeat test with Android emulator using Google Play test account

- [ ] **Write refund policy**
  > **How:** Add to your Terms of Service:
  > "Subscriptions are non-refundable except where required by law. EU and UK customers have a 14-day right of withdrawal, which is waived upon first use of premium features. To request a refund, contact support@deardays.app within 14 days of purchase."

---

## PHASE 7 — SECURITY & INFRASTRUCTURE

- [ ] **Verify Supabase backups**
  > **How:**
  > 1. Supabase dashboard → Settings → Database → Backups
  > 2. Confirm "Daily backups" is enabled (available on Pro plan and above)
  > 3. Free plan has Point-in-Time Recovery disabled — if on free plan, consider upgrading to Pro (~$25/month) before launch
  > 4. Do a test restore in a staging environment at least once before launch

- [ ] **Set up error monitoring**
  > **How:**
  > 1. Add Sentry to the Flutter app: `flutter pub add sentry_flutter`
  > 2. Initialise in `main.dart`:
  >    ```dart
  >    await SentryFlutter.init((options) {
  >      options.dsn = 'YOUR_SENTRY_DSN';
  >      options.beforeSend = (event, hint) {
  >        // Strip any PII from error messages before sending to Sentry
  >        return event.copyWith(message: SentryMessage(
  >          event.message?.formatted?.replaceAll(RegExp(r'\S+@\S+\.\S+'), '[email]') ?? '',
  >        ));
  >      };
  >    }, appRunner: () => runApp(const DearDaysApp()));
  >    ```
  > 3. Create a Sentry account at sentry.io (free tier is fine for launch)
  > 4. PII scrubbing is important — journal content must never appear in error logs

- [ ] **Set up breach notification process**
  > **How:** Write a simple internal document (even a Notion page) that covers:
  > 1. **What constitutes a breach**: unauthorised access to user data, Supabase credentials leaked, RLS misconfiguration exposing other users' data
  > 2. **Detection**: check Sentry alerts daily; set up Supabase log alerts for unusual query patterns
  > 3. **Response steps**: isolate → assess scope → notify users → notify regulators
  > 4. **Regulator contact for 72-hour notification**:
  >    - UK ICO: ico.org.uk/for-organisations/report-a-breach → online form
  >    - Dutch AP: autoriteitpersoonsgegevens.nl → "Meld een datalek" form
  >    - India: Currently notify MeitY (Ministry of Electronics) — formal DPDPA breach notification rules still being finalised
  > 5. Store this document somewhere you can find it at 2am

- [ ] **Verify all cron jobs are running**
  > **How:**
  > 1. Supabase dashboard → Database → Extensions → enable `pg_cron` if not already enabled
  > 2. Go to SQL Editor and run:
  >    ```sql
  >    SELECT * FROM cron.job;
  >    ```
  > 3. Verify these jobs exist and are scheduled:
  >    - `run_data_retention()` — should run daily (e.g. `0 3 * * *`)
  >    - `expire_stale_share_requests()` — nightly
  >    - `expire_stale_book_invites()` — nightly
  >    - `prune_old_book_activity()` — nightly
  > 4. If missing, add them:
  >    ```sql
  >    SELECT cron.schedule('daily-retention', '0 3 * * *', 'SELECT public.run_data_retention()');
  >    SELECT cron.schedule('expire-invites', '0 2 * * *', 'SELECT public.expire_stale_book_invites()');
  >    ```

- [ ] **Verify RLS on all tables**
  > **How:** Run in Supabase SQL Editor:
  >    ```sql
  >    SELECT tablename, rowsecurity
  >    FROM pg_tables
  >    WHERE schemaname = 'public'
  >    ORDER BY tablename;
  >    ```
  > Every row in the `rowsecurity` column should show `true`. If any show `false`, immediately run `ALTER TABLE public.tablename ENABLE ROW LEVEL SECURITY;`

- [ ] **Security review before India launch**
  > **How:**
  > 1. Run OWASP Mobile Security checklist against the app (owasp.org/www-project-mobile-app-security)
  > 2. Use a tool like MobSF (Mobile Security Framework) for automated scanning — free, open source
  > 3. At minimum, verify: no API keys hardcoded in Dart code, certificate pinning is active (it is — `recording_screen.dart` line 66), RLS policies are correct, no SQL injection possible in any RPC
  > 4. For a formal pentest: firms like Cobalt.io or Synack offer crowdsourced pentests starting ~$2,000. Not required for launch but recommended before 10,000 users.

---

## PHASE 8 — PRE-SUBMISSION TESTING

- [ ] **Test age gate in each country locale**
  > **How:**
  > - iOS: Settings → General → Language & Region → Region → change to Netherlands. Launch app. Enter DOB as 15 years old. Confirm dead-end screen appears.
  > - Android: Settings → General Management → Language → change region to India. Enter DOB as 17. Confirm blocked.
  > - Test each country: US (block at 12), UK (block at 12), Canada (block at 12), NL (block at 15), India (block at 17)

- [ ] **Test consent flow and audit log**
  > **How:**
  > 1. Create a new test account
  > 2. Complete consent flow — tick all boxes
  > 3. In Supabase SQL Editor run:
  >    ```sql
  >    SELECT * FROM consent_audit_log WHERE user_id = 'YOUR_TEST_USER_ID' ORDER BY created_at;
  >    ```
  > 4. Verify you see rows for: `consent_given`, `health_consent_given`, optionally `marketing_opt_in`
  > 5. Verify `profiles.consent_given_at` is set and `consent_version` matches your current version string

- [ ] **Test voice recording — confirm no Whisper call by default**
  > **How:**
  > 1. Enable debug logging in `AiService` (it's already in `kDebugMode`)
  > 2. Record a 10-second voice entry speaking clearly
  > 3. Watch the Flutter debug console — you should see POST calls to `/ai-polish` and `/ai-chat` but NOT to `/ai-transcribe`
  > 4. If you see `/ai-transcribe` — check `widget.data.useWhisper` is `false` in ProcessingScreen

- [ ] **Test "Use AI Transcription" consent dialog**
  > **How:**
  > 1. Temporarily mute your microphone OR set device to a language the on-device STT doesn't support
  > 2. Record for 5+ seconds
  > 3. Tap Finish — confirm the "Voice not captured" dialog appears
  > 4. Tap "Use AI Transcription" — confirm `/ai-transcribe` is called
  > 5. Tap "Type instead" — confirm you're navigated to the text entry screen with no network call

- [ ] **Test account deletion flow**
  > **How:**
  > 1. Create a test account and add some journal entries
  > 2. Go to Settings → Delete My Account → Confirm
  > 3. Verify in Supabase: `profiles.account_deleted_at` is set to now
  > 4. Verify user is logged out
  > 5. To test the 30-day purge: manually set `account_deleted_at = now() - INTERVAL '31 days'` in SQL Editor, then run `SELECT public.run_data_retention()`. Verify the profile and all entries are deleted.

- [ ] **Test subscription purchase in sandbox**
  > **How (iOS)**:
  > 1. Xcode → Product → Scheme → Edit Scheme → set StoreKit Configuration
  > 2. Or create a Sandbox test account in App Store Connect → Users → Sandbox Testers
  > 3. On device: log out of App Store, log in with sandbox tester account
  > 4. Make a test purchase in the app — RevenueCat will receive a webhook → check `profiles.is_subscribed = true`
  >
  > **How (Android)**:
  > 1. Add your Google account as a License Test account in Play Console → Setup → License Testing
  > 2. Make a purchase — it will succeed without charging real money
  > 3. Verify RevenueCat webhook fires and subscription is activated

- [ ] **Test French locale**
  > **How:**
  > 1. Change device language to French (Canada): iOS → Settings → General → Language → add Français (Canada)
  > 2. Launch DearDays — all UI strings should be in French
  > 3. Specifically verify: consent screen is in French, settings labels are in French, error messages are in French

---

## PHASE 9 — SUBMISSION

### iOS

- [ ] **Build and archive in Xcode**
  > **How:**
  > 1. Open `ios/Runner.xcworkspace` in Xcode (not `.xcodeproj`)
  > 2. Select "Any iOS Device (arm64)" as the target (not a simulator)
  > 3. Update version number in `pubspec.yaml` (e.g. `version: 1.0.0+1`) — the `+1` is the build number
  > 4. Run `flutter build ios --release` first to make sure it compiles
  > 5. In Xcode: Product → Archive
  > 6. Wait for archiving to complete (5–15 minutes)
  > 7. Xcode Organizer will open automatically

- [ ] **Upload to App Store Connect**
  > **How:**
  > 1. In Xcode Organizer, select your archive and click "Distribute App"
  > 2. Select "App Store Connect" → "Upload"
  > 3. Leave all options default → click "Upload"
  > 4. Wait for the build to process in App Store Connect (10–30 minutes)
  > 5. Go to appstoreconnect.apple.com → Your App → TestFlight to see the build appear

- [ ] **Complete store metadata**
  > **How:**
  > 1. App Store Connect → Your App → App Store → [your version]
  > 2. Fill in:
  >    - **Name**: DearDays (max 30 chars)
  >    - **Subtitle**: Your Personal Life Journal (max 30 chars)
  >    - **Description**: ~170 words, clear and benefit-focused. Mention privacy and on-device encryption.
  >    - **Keywords**: journal, diary, memoir, life story, mood tracker, voice journal (max 100 chars)
  >    - **Screenshots**: Required sizes — 6.7" iPhone (required), 6.5" iPhone, 12.9" iPad (if universal)
  >    - **App Preview Video**: optional but increases conversion significantly
  >    - **Support URL**: your website or email
  > 3. Add screenshots for each language you support (English + French for Canada)

- [ ] **Submit for App Review**
  > **How:**
  > 1. App Store Connect → Your App → select the version
  > 2. Click "Add for Review"
  > 3. Answer the export compliance question (Yes, exempt)
  > 4. Answer advertising identifier question (No IDFA used)
  > 5. Click "Submit to App Review"
  > 6. Typical review time: 24–48 hours (can be up to 7 days for first submission)
  > 7. You'll get an email when approved or if there are issues

---

### Android

- [ ] **Build release AAB**
  > **How:**
  > ```bash
  > flutter build appbundle --release \
  >   --dart-define=AI_API_URL=https://YOUR_PROJECT_REF.supabase.co/functions/v1
  > ```
  > Output: `build/app/outputs/bundle/release/app-release.aab`

- [ ] **Sign with your keystore**
  > **How:**
  > 1. Create a keystore (first time only):
  >    ```bash
  >    keytool -genkey -v -keystore ~/deardays-release-key.jks \
  >      -keyalg RSA -keysize 2048 -validity 10000 \
  >      -alias deardays
  >    ```
  > 2. **BACK UP THIS FILE IMMEDIATELY** — store in: password manager + encrypted cloud backup + separate physical location. Losing the keystore = you can never update your app on Google Play.
  > 3. Add signing config to `android/app/build.gradle`
  > 4. Or use Google Play App Signing (recommended) — Play signs on your behalf after upload

- [ ] **Upload to Play Console**
  > **How:**
  > 1. Play Console → Your App → Production → Create new release
  > 2. Upload the `.aab` file
  > 3. Add release notes (what's new in this version) — add for English and French
  > 4. Click "Save" then "Review release"
  > 5. Complete the "Set up your app" checklist if any items are still pending

- [ ] **Complete store listing for all countries**
  > **How:**
  > 1. Play Console → Store presence → Main store listing
  > 2. Fill in title, short description (80 chars), full description (4000 chars)
  > 3. Upload screenshots: phone (required), 7" tablet, 10" tablet (optional)
  > 4. Feature graphic: 1024×500px banner (required)
  > 5. For French (Canada): Play Console → Store presence → Manage translations → Add French

---

## PHASE 10 — POST-LAUNCH

- [ ] **Monitor crash reports daily for first 2 weeks**
  > **How:**
  > 1. Set up Sentry alerts: sentry.io → Alerts → Create Alert → "New issue" → notify by email
  > 2. Check Android Vitals in Play Console (Play Console → Android Vitals → Crashes) daily
  > 3. Check App Store Connect → Xcode Organizer → Crashes daily
  > 4. Set a triage target: any crash affecting >0.1% of sessions should be fixed within 48 hours

- [ ] **Respond to user data requests within 30 days**
  > **How:**
  > 1. Set up a dedicated privacy inbox: privacy@deardays.app
  > 2. When a user emails requesting their data or deletion:
  >    a. Verify their identity (confirm their account email)
  >    b. For data requests: query all their data and send as JSON attachment
  >    c. For deletion: set `account_deleted_at` in Supabase, confirm by email
  > 3. Track requests in a simple spreadsheet: date received, user, type, date responded
  > 4. GDPR/DPDPA deadline: 30 days from request. CCPA: 45 days.

- [ ] **Check grievance_requests table weekly**
  > **How:**
  > ```sql
  > SELECT id, type, description, status, created_at, due_at
  > FROM grievance_requests
  > WHERE status IN ('open', 'in_progress')
  > ORDER BY due_at ASC;
  > ```
  > Set a weekly calendar reminder. For any approaching `due_at`, resolve or escalate immediately.

- [ ] **Review consent_audit_log for anomalies**
  > **How:**
  > ```sql
  > -- Check for users who signed up but have no consent record
  > SELECT p.id, p.created_at
  > FROM profiles p
  > LEFT JOIN consent_audit_log cal
  >   ON cal.user_id = p.id AND cal.event = 'consent_given'
  > WHERE cal.id IS NULL
  >   AND p.created_at > now() - INTERVAL '7 days';
  > ```
  > If this returns rows, there's a bug in your consent recording flow — fix it immediately.

- [ ] **Get Privacy Policy reviewed by a lawyer**
  > **How:**
  > 1. Find a lawyer specialising in data privacy via:
  >    - UK: Legal 500 directory (legal500.com) → Privacy & Data Protection
  >    - India: Bar Council of India licensed advocates with IT/privacy experience
  >    - Online: Clerky, Stripe Atlas, or Osome offer startup legal packages
  > 2. Send them: your Privacy Policy, Terms of Service, and a brief on the 5 target countries
  > 3. Budget: £500–£1,500 for a review and markup
  > 4. They'll catch jurisdiction-specific gaps you missed — worth it before you hit 1,000 users

- [ ] **Set annual ICO renewal reminder (UK)**
  > **How:**
  > 1. ICO sends email reminders 30 days before renewal
  > 2. Also add a calendar event: set it for 11 months after your registration date
  > 3. Renewal: ico.org.uk/registration → same process, ~£40

- [ ] **Consider DPO appointment at 500+ users**
  > **How:**
  > A Data Protection Officer is formally required under GDPR if you process special category data (mood/health data) at scale. For a small app this threshold is not strictly defined — GDPR says "large scale" processing. As a practical rule:
  > - Under 500 users: you are the DPO
  > - 500–5,000: document your processing activities (Article 30 record) and consider a part-time DPO
  > - 5,000+: appoint a named DPO (can be an external consultant, ~£2,000–£5,000/year)
  > - The Article 30 record is a simple spreadsheet: list every type of data you collect, why, legal basis, retention period, and who it's shared with

---

## QUICK REFERENCE — Key deadlines

| Action | Deadline | How long it takes |
|---|---|---|
| Sign Supabase + OpenAI DPAs | Before first user | 10 minutes each |
| Run migration 028 | Before submission | 5 minutes |
| Get D-U-N-S number | 5 days before Apple signup | 3–5 business days |
| ICO registration (UK) | Before serving UK users | 30 minutes, instant |
| Name India Grievance Officer | Before serving Indian users | 15 minutes |
| French language support | Before Canada launch | 1–2 weeks dev time |
| OpenAI SCCs | Before serving NL/UK users | 2–5 days (email request) |
| Apple App Review | Allow 24–48 hours buffer | 24–48 hours typical |
| Google Play Review | Allow 3–7 days buffer | 3–7 days for new apps |

---

## MINIMUM AGE BY COUNTRY

| Country | Min age | Law | Block screen text |
|---|---|---|---|
| US | 13 | COPPA | "DearDays is for users 13 and older." |
| UK | 13 | UK GDPR | "DearDays is for users 13 and older." |
| Canada | 13 | PIPEDA | "DearDays is for users 13 and older." |
| Netherlands | 16 | GDPR (NL) | "DearDays is for users 16 and older." |
| India | 18 | DPDPA 2023 | "DearDays is for users 18 and older." |

---
*Last updated: 2026-03-17*
