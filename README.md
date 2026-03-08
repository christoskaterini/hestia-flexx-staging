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

## Uninstallation

To remove the `flexx-staging` tool and `wp-cli` from your server, run this command as `root`:

```bash
rm /usr/local/bin/flexx-staging
rm /usr/local/bin/wp
```
