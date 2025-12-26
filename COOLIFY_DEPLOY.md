# Deploying MyLMS to Coolify

This guide explains how to deploy your **Svelte Frontend** and **Python Backend** to a Coolify instance, configured to auto-deploy on GitHub updates.

## Prerequisites

- A running **Coolify** instance.
- Your project pushed to a GitHub repository.
- **Ports Configured**:
  - Backend: `2004`
  - Frontend: `2005`

---

## 1. Python Backend Deployment

1. **Dashboard**: Go to your Coolify dashboard -> **Projects** -> Select (or create) a project -> **New** -> **Public Repository** (or **Private** if you use a key).
2. **Repository URL**: Enter your GitHub repository URL.
3. **Build Pack**: Select **Docker Compose** or **Dockerfile**. Since we added a `Dockerfile` in `mylms-py-backend`:
   - Set **Base Directory** to `/mylms-py-backend` (or wherever the backend code resides relative to repo root).
   - Coolify should auto-detect the Dockerfile.
4. **Configuration**:
   - **Name**: `mylms-backend` (example).
   - **Port**: In the **General** tab, ensure **Ports Exposes** includes `2004`.
   - **Domains**: Set your domain (e.g., `https://api.mylms.com`).
   - **Environment Variables**: Go to the **Environment Variables** tab and add any secrets from your local `.env`.
5. **Auto-Deploy**:
   - Go to **Webhooks** (or "Git Sources" in newer Coolify versions).
   - Ensure **Autodeploy** is enabled. Coolify usually adds a webhook to your repo automatically if connected via GitHub App. If not, copy the "GitHub Webhook" URL and add it to your GitHub Repository Settings -> Webhooks.
   - Now, every push to `main` (or selected branch) will trigger a redeploy.

## 2. Svelte Frontend Deployment

> **Important**: We switched to `@sveltejs/adapter-node`. This means the app runs as a Node.js server, not a static site.

1. **Dashboard**: **New** -> **Public/Private Repository**.
2. **Repository URL**: Same GitHub URL.
3. **Build Pack**: **Dockerfile**.
   - Set **Base Directory** to `/mylms-svelte`.
4. **Configuration**:
   - **Name**: `mylms-frontend`.
   - **Port**: `2005` (The Dockerfile explicitly sets `PORT=2005` and exposes it).
   - **Domains**: Set your domain (e.g., `https://mylms.com`).
   - **Environment Variables**:
     - `PUBLIC_BACKEND_URL`: **Crucial**. Set this to `http://10.0.0.109:2004` (or your domain).
     - **Note**: Ensure you do NOT include trailing slash.
     - You *must* click **Redeploy** after adding this.
5. **Auto-Deploy**:
   - Ensure **Autodeploy** is checked. Push to GitHub -> Coolify rebuilds.

## 3. GitHub CI/CD & Webhooks

To ensure **both** update when you update GitHub:

1. **GitHub App Method** (Recommended):
   - If you linked Coolify via the GitHub App integration, it automatically receives "Push" events.
   - It will detect changes. If you use a monorepo (both in one repo), Coolify might try to rebuild both, or you can configure "Watch Paths" in Coolify:
     - For Backend Resource: Set Watch Path to `mylms-py-backend/**`.
     - For Frontend Resource: Set Watch Path to `mylms-svelte/**`.
   - This ensures the Backend only rebuilds when backend files change, and vice versa.

2. **Manual Webhook Method**:
   - If using manual webhooks, adding the Coolify webhook URL to GitHub triggers on *any* push. Coolify then decides what to build. Configuring "Watch Paths" (if available in your version) or "Base Directory" helps it decide.

---

## 4. Verification

- **Backend**: Visit `http://10.0.0.109:2004`. You should see `{"message": "MyLMS Backend is running"}`.
- **Frontend**: Visit `http://10.0.0.109:2005`. It should load and successfully talk to the backend.

## Authentication & Moodle Token

Your MyLMS app requires a **Moodle Web Service Token** to log in.

**How to get your Token:**
1. Log in to your Moodle instance (e.g., `https://moodle.example.com`).
2. Click your **Profile Picture** -> **Preferences**.
3. Under "User account", click **Security keys**.
4. Look for the **Moodle mobile web service** key.
   - If it doesn't exist, your Moodle admin needs to enable Mobile web services.
5. Copy the Key/Token.
6. Paste this token into the MyLMS login screen.

## Troubleshooting

### "Remote branch main not found"
If your deployment fails with this error, your repository likely uses `master` instead of `main` as the default branch.
- **Fix**: In Coolify, under your generic git settings or when creating the resource, change the **Production Branch** from `main` to `master`.
- **Alternative**: Rename your local branch to main: `git branch -m master main` and push: `git push -u origin main`.

### "This site can't be reached" / Connection Timed Out
If you cannot access `http://10.0.0.109:2005`, check these three things:

1.  **Coolify Port Mapping**:
    - Go to your Svelte Resource in Coolify.
    - Click **General**.
    - Ensure **Ports Exposes** is set to `2005`.
    - **Crucial**: After changing this, you must click **Save** and then **Redeploy**.

2.  **Server Firewall**:
    - Since `ufw` is not installed, your Linux system is **not** blocking ports.
    - **The Problem is likely Windows Firewall**.
    - **Fix**: Open **PowerShell** as Administrator on Windows and run:
      ```powershell
      New-NetFirewallRule -DisplayName "Coolify Ports" -Direction Inbound -LocalPort 2004,2005 -Protocol TCP -Action Allow
      ```

3.  **The "Localhost" Test**:
    - Open the browser **on the server itself** (the machine running Docker).
    - Visit `http://localhost:2005`.
    - **If this works**, but `10.0.0.109` fails, the issue is **WSL Network Bridging**.
    - **Fix**: WSL 2 does not share its ports with the LAN automatically. You must run this in **Administrator PowerShell**:
      ```powershell
      $wsl_ip = (wsl hostname -I).Trim()
      netsh interface portproxy add v4tov4 listenport=2004 listenaddress=0.0.0.0 connectport=2004 connectaddress=$wsl_ip
      netsh interface portproxy add v4tov4 listenport=2005 listenaddress=0.0.0.0 connectport=2005 connectaddress=$wsl_ip
      ```

4.  **Deployment Status**:
    - Ensure the deployment actually succeeded (Green dot in Coolify).
    - Check the **Application Logs** in Coolify. If the app crashed, it won't load.

### Ports
If Coolify complains about ports or mapping:
- Ensure the **Network** setting in Coolify is correct (usually `coolify` network).
- If you access via domain, the internal port (2004/2005) matters for the reverse proxy. You don't need to open these ports on the VPS firewall (AWS Security Group / UFW) unless you want direct IP access. Coolify's proxy handles the routing from 80/443 -> 2004/2005.
