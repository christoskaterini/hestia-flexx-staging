#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

# Prevent root from running it accidentally
if [ "$EUID" -eq 0 ]; then
  echo "ERROR: Please run this command as the website user, NOT as root."
  exit 1
fi

echo "=========================================="
echo "          FLEXX-STAGING SYNC TOOL         "
echo "=========================================="
echo "Logged in as user: $USER"
echo ""

# Display available domains for the user
echo "Available websites for user $USER:"
ls -1 /home/"$USER"/web/ | grep -v '^\.' | sed 's/^/  - /'
echo ""

# 1. Ask for Source and Target
read -r -p "Enter SOURCE Domain (Where to copy FROM): " SOURCE_DOM
read -r -p "Enter TARGET Domain (Where to copy TO):   " TARGET_DOM

SOURCE_PATH="/home/$USER/web/$SOURCE_DOM/public_html"
TARGET_PATH="/home/$USER/web/$TARGET_DOM/public_html"

# Verify folders exist
if [ ! -d "$SOURCE_PATH" ] || [ ! -d "$TARGET_PATH" ]; then
    echo "ERROR: One of these domains does not exist in Hestia for user $USER!"
    exit 1
fi

echo ""
echo "WARNING: You are about to overwrite data on --> $TARGET_DOM"
echo "SAFETY CHECK: Ensure your target database was named explicitly as a staging DB"
echo "              (e.g., user_stagingdb) to avoid deleting production work."
read -r -p "Are you 100% sure? (type 'yes' to continue): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# 2. Ask WHAT to sync
echo ""
echo "What do you want to sync?"
echo "IMPORTANT: The option you choose will OVERWRITE existing data on the TARGET domain ($TARGET_DOM)!"
echo ""
echo "1) Files ONLY     (Safe for Live eCommerce DB)"
echo "2) Database ONLY  (DANGEROUS for Live eCommerce DB)"
echo "3) ALL            (OVERWRITES EVERYTHING - Files + Database)"
echo ""
read -r -p "Select 1, 2, or 3: " SYNC_TYPE

echo ""

# 3. Process Files if selected (1 or 3)
if [ "$SYNC_TYPE" == "1" ] || [ "$SYNC_TYPE" == "3" ]; then
    echo "--> Copying Files (ignoring wp-config.php and .htaccess)..."

    rsync -av \
      --exclude 'wp-config.php' \
      --exclude '.htaccess' \
      "$SOURCE_PATH/" "$TARGET_PATH/"

    echo "--> Fixing permissions..."
    # Since we run as the user, files are already owned by the user,
    # but we ensure directories are 755 and files are 644 just to be clean.
    find "$TARGET_PATH" -type d -exec chmod 755 {} +
    find "$TARGET_PATH" -type f -exec chmod 644 {} +
fi

# 4. Process Database if selected (2 or 3)
if [ "$SYNC_TYPE" == "2" ] || [ "$SYNC_TYPE" == "3" ]; then
    # Verify WP-CLI is installed
    if ! command -v wp &> /dev/null; then
        echo "ERROR: WP-CLI ('wp' command) was not found!"
        echo "Please install WP-CLI globally to sync the database."
        exit 1
    fi

    # Hestia/CloudPanel often disable proc_open which WP-CLI uses.
    # To bypass this for our script, we run wp via explicitly enabling proc_open using php CLI.
    # We define a helper function to run wp commands bypassing the disable_functions directive.
    run_wp() {
        php -d disable_functions="" /usr/local/bin/wp "$@"
    }

    echo "--> Exporting Database from Source..."
    run_wp db export "$SOURCE_PATH/sync_dump.sql" --path="$SOURCE_PATH" --quiet
    mv "$SOURCE_PATH/sync_dump.sql" "$TARGET_PATH/sync_dump.sql"

    echo "--> Clearing existing tables from Target Database..."
    run_wp db reset --yes --path="$TARGET_PATH" --quiet

    echo "--> Importing Database into Target..."
    run_wp db import "$TARGET_PATH/sync_dump.sql" --path="$TARGET_PATH" --quiet
    rm "$TARGET_PATH/sync_dump.sql"

    echo "--> Updating URLs in Target Database..."
    NEW_URL="https://$TARGET_DOM"

    # Sync the Database Prefix
    echo "--> Syncing Database Table Prefix..."
    SOURCE_PREFIX=$(run_wp config get table_prefix --path="$SOURCE_PATH" --quiet)
    TARGET_PREFIX=$(run_wp config get table_prefix --path="$TARGET_PATH" --quiet)

    if [ "$SOURCE_PREFIX" != "$TARGET_PREFIX" ] && [ -n "$SOURCE_PREFIX" ]; then
        # We explicitly set it in the target's wp-config since we omitted it in rsync
        run_wp config set table_prefix "$SOURCE_PREFIX" --path="$TARGET_PATH" --quiet
    fi

    echo "--> Running Search and Replace..."
    # Get the exact live URL dynamically to ensure we catch 'www.' or HTTP variations
    EXACT_OLD_URL=$(run_wp option get siteurl --path="$SOURCE_PATH" --quiet)
    if [ -n "$EXACT_OLD_URL" ]; then
        run_wp search-replace "$EXACT_OLD_URL" "$NEW_URL" --skip-columns=guid --path="$TARGET_PATH" --quiet
    fi

    # Blindly replace standard variations just in case hardcoded links exist
    run_wp search-replace "https://$SOURCE_DOM" "$NEW_URL" --skip-columns=guid --path="$TARGET_PATH" --quiet
    run_wp search-replace "http://$SOURCE_DOM" "$NEW_URL" --skip-columns=guid --path="$TARGET_PATH" --quiet
    run_wp search-replace "https://www.$SOURCE_DOM" "$NEW_URL" --skip-columns=guid --path="$TARGET_PATH" --quiet
    run_wp search-replace "http://www.$SOURCE_DOM" "$NEW_URL" --skip-columns=guid --path="$TARGET_PATH" --quiet

    # Explicitly force the core URL options to guarantee the site loads
    run_wp option update home "$NEW_URL" --path="$TARGET_PATH" --quiet || true
    run_wp option update siteurl "$NEW_URL" --path="$TARGET_PATH" --quiet || true

    echo "--> Deactivating Security & Caching Plugins on Target..."
    # Deactivate plugins that cause severe redirect/lockout issues during staging
    run_wp plugin deactivate all-in-one-wp-security-and-firewall wordfence ithemes-security better-wp-security sucuri-scanner sg-security \
        w3-total-cache litespeed-cache wp-super-cache wp-fastest-cache sg-cachepress wp-rocket \
        redirection simple-301-redirects safe-svg \
        --path="$TARGET_PATH" --quiet || true

    echo "--> Flushing Permalinks (Rewrites)..."
    run_wp rewrite flush --hard --path="$TARGET_PATH" --quiet

    echo "--> Flushing Object Cache (if any)..."
    run_wp cache flush --path="$TARGET_PATH" --quiet
fi

# Invalid selection catch
if [ "$SYNC_TYPE" != "1" ] && [ "$SYNC_TYPE" != "2" ] && [ "$SYNC_TYPE" != "3" ]; then
    echo "Error: Invalid selection. Aborted."
    exit 1
fi

echo ""
echo "=========================================="
echo "          FLEXX-STAGING COMPLETE!         "
echo "=========================================="
