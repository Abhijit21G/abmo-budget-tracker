# AbMo Budget Tracker — two-person shared version

This is an installable iPhone web app (PWA) with shared cloud storage. It is free to start using Supabase's free tier, subject to Supabase limits and policies. It is not a native App Store app.

## What this version supports
- Two people sign in using secure email magic links.
- One person creates the household and makes a private invitation link for the second person.
- Both members can add, edit and delete shared transactions.
- Each person can also add personal transactions visible only to that person.
- Shared household budget limits, monthly income target and opening savings setting.
- Current savings estimate based on opening savings plus visible income minus visible expenses.
- A one-time migration screen can import the existing local AbMo records without deleting the local copy. Choose whether imported transactions should be shared or personal.
- Database row-level security policies limit access to household members and keep personal transactions private.

## One-time setup (required)

### 1. Create a Supabase project
1. Go to https://supabase.com and create a free project.
2. Open **SQL Editor** in the project dashboard.
3. Open `schema.sql` from this package, copy its entire contents into the SQL Editor, and run it.
4. In **Project Settings → API** (or the API keys section), copy the **Project URL** and the **publishable/anon client key**.
5. Edit `config.js` and replace the two `PASTE_...` values with those values.

**Never put a service-role key in `config.js` or any browser file.** The public client key is designed to be used in a browser; the SQL row-level security rules are what restrict access.

### 2. Configure email sign-in redirects
In Supabase, open **Authentication → URL Configuration**. Set the Site URL to the final HTTPS app URL. Add that URL to the allowed redirect URLs as well. If using GitHub Pages, it usually looks like `https://YOUR-USERNAME.github.io/YOUR-REPOSITORY/`.

Email magic-link delivery depends on Supabase's configured email service and its current limits. For a production app, configure a reliable email provider in Supabase.

### 3. Publish the app over HTTPS for free
1. Create a GitHub repository and upload `index.html`, `manifest.json`, `sw.js`, `config.js`, and `schema.sql`.
2. In the repository, choose **Settings → Pages → Deploy from a branch**, then select the `main` branch and root folder.
3. Wait for GitHub Pages to publish the HTTPS URL.
4. Open that URL in Safari on each iPhone and use **Share → Add to Home Screen**.

The app's source repository can be public, so do not put private data, email passwords, or a Supabase service-role key in it. The Supabase URL and publishable/anon key are browser client configuration and are not secrets.

## Invite the second person
1. The first person signs in, then chooses **Create a new household**.
2. Open **Household → Create / refresh invitation link** and send the link privately to the second person.
3. The second person opens the link, signs in using their own email, and chooses **Join invited household**.
4. Both should then see shared transactions and budget changes online. Personal transactions remain visible only to the person who created them.

Creating a new invite link invalidates the previous invite. Share it only with the intended person.

## Existing data and migration
- Keep the original ZIP and export a CSV backup before migrating.
- The first sign-in on a device may offer to import the original local data. Choose **Shared with household** only if you want the other member to see all those imported transactions. Choose **Personal — only me** if the records should remain private to your account.
- Import does not delete the local records. Do not press import more than once, or it may create duplicates.
- If the original local data was never customized, it may contain sample transactions. Review the records before importing.

## Privacy and limitations
- The database policies protect transaction rows by household membership and visibility. Both household members can edit shared transactions; personal transactions are restricted to their owner.
- Household settings and category budgets are shared and editable by both members.
- This is a manual budgeting tool. It does not connect to bank accounts, and savings is an estimate based on the records entered.
- This version supports one household per account. The invite link is a bearer credential: send it privately and rotate it if it is exposed.
- Free hosting/database tiers have quotas and terms that may change. Back up important records regularly.
- Offline caching covers the app shell only; creating and syncing transactions requires an internet connection.
