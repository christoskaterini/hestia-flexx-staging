# Flexx-Staging Sync Tool

A robust, terminal-based staging tool for HestiaCP and WordPress.

## Prerequisites

Before using the tool, ensure you have:
1. **Created a DNS Record**: Your target staging domain (e.g., `staging.yourdomain.com`) must have an `A` record pointing to your server's IP address (in Cloudflare, Hestia DNS, etc.).
2. **Setup a Target Website in Hestia**: The staging domain must exist as a website under your HestiaCP user account.

## Best Practices (Optional but Recommended)

- **Database Naming Convention**: When creating a database for the staging site in Hestia, name it clearly (e.g., `user_stagingdb`) so you never accidentally select and delete the live production database.
- **Full Backup**: Take a full backup of your source AND target websites (files and DB) before running any synchronization tool.

*Note: This script installs and uses [WP-CLI](https://wp-cli.org/) to handle all WordPress database operations safely.*

## Installation

Run this single block of commands as `root` to install both **WP-CLI** (required for database sync) and the **flexx-staging** script globally:

```bash
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
chmod +x wp-cli.phar && \
mv wp-cli.phar /usr/local/bin/wp && \
curl -o /usr/local/bin/flexx-staging https://raw.githubusercontent.com/christoskaterini/hestia-flexx-staging/main/flexx-staging.sh && \
chmod 755 /usr/local/bin/flexx-staging
```

## Usage

Run the script as the website user

```bash
flexx-staging
```

The script will guide you through:
1. Selecting the Source Domain.
2. Selecting the Target Domain.
3. Choosing what to sync (Files, Database, or Both).

## Safety Features

- **Root Protection**: Prevents accidental execution as root.
- **Confirmation**: Requires typing `yes` before overwriting data.
- **Smart Sync**: Automatically excludes `wp-config.php` during file sync.
- **URL Replacement**: Automatically updates `http(s)://source.com` to `https://target.com` in the database.
- **Safe Plugin Deactivation**: Safely deactivates extreme caching and security plugins (like Wordfence, AIOS, W3TC) inside the Staging database via WP-CLI so they don't break the staging environment.

## Professional Workflow: Security & Caching

Staging environments and Security/Caching plugins are naturally opposed. Security plugins will block staging IPs, and Caching plugins will cache live URLs.

Here is the professional workflow when using `flexx-staging` alongside heavy plugins like **All-In-One WP Security (AIOS), Wordfence, LiteSpeed, or W3 Total Cache**:

### 1. PULLING: Live ➔ Staging

When you run `flexx-staging` to create your staging site, the script copies all the plugin files, but **automatically deactivates the following known problem plugins** in the staging database:

- **Security & Firewalls:**
  `all-in-one-wp-security-and-firewall`, `wordfence`, `ithemes-security`, `better-wp-security`, `sucuri-scanner`, `sg-security`, `wp-cerber`, `shield-security`, `defender-security`

- **Login & 2FA:**
  `loginizer`, `limit-login-attempts-reloaded`, `two-factor-authentication`

- **Caching & Performance:**
  `w3-total-cache`, `litespeed-cache`, `wp-super-cache`, `wp-fastest-cache`, `sg-cachepress`, `wp-rocket`, `autoptimize`, `wp-optimize`, `breeze`, `hummingbird-performance`

- **Redirection & Utilities:**
  `redirection`, `simple-301-redirects`, `safe-svg`

> **Pro Tip:** Leave them deactivated on Staging! You do not need a firewall or a caching layer on a hidden development site.

> **Unknown Plugins:** If you use a heavy caching or security plugin that is *not* on the list above, you should manually deactivate it on your Live site *before* running the script, then reactivate it on Live once the sync finishes.

<br>

### 2. PUSHING FILES: Staging ➔ Live (Option 1)

If you made CSS or theme changes and want to run `flexx-staging` (Option 1 - Files Only) to push back to Live:

1. The script only copies files; your Live site's database remains completely untouched.
2. Your Live site's security and caching plugins will remain fully active and functional, exactly as they always were.
3. **CRITICAL POST-STEP:** After pushing files to Live, log into your Live WordPress dashboard and click **"Clear Cache"** in your caching plugin so your new files load instantly for users.

<br>

### 3. PUSHING DATABASES: Staging ➔ Live (Option 2 or 3)

*(Only recommended for static/non-eCommerce sites)*

If you are doing a full Database push from Staging back to Live:

1. Because the plugins were deactivated on Staging, pushing the database will make the Live site boot up with AIOS, Wordfence, and all Caches **DEACTIVATED**.
2. **THIS IS INTENTIONAL:** It prevents plugins from breaking your Live site by aggressively writing Staging rules to your Live `.htaccess`.
3. **CRITICAL POST-STEP:** The instant the sync finishes, you MUST log into your Live WordPress dashboard and click **Activate** on your required security and cache plugins.

*(Note: For security plugins that use custom login URLs, you will temporarily need to log in via `/wp-admin` until you reactivate the plugin.)*

## Uninstallation

To remove the `flexx-staging` tool and `wp-cli` from your server, run this command as `root`:

```bash
rm /usr/local/bin/flexx-staging
rm /usr/local/bin/wp
```

---

## Contributing & Support

If you encounter any issues or bugs while using `flexx-staging`, please **open an issue on GitHub**.

**Help us expand the safe-list!**
If you use a caching or security plugin that caused staging to break or lock you out, please submit an issue on GitHub suggesting it. We routinely update the `flexx-staging.sh` code to automatically deactivate problem plugins, and your feedback helps make this tool safer for everyone!
