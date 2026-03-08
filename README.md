# Flexx-Staging Sync Tool

A robust, terminal-based staging tool for HestiaCP and WordPress.

## Installation

Run this command as `root` to download and install the script globally:

```bash
curl -o /usr/local/bin/flexx-staging https://raw.githubusercontent.com/christoskaterini/hestia-flexx-staging/main/flexx-staging.sh
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
