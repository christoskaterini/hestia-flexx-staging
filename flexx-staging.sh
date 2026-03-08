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
echo "1) Files ONLY     (OVERWRITES Target Themes, Plugins, Uploads - Safe for Live eCommerce DB)"
echo "2) Database ONLY  (OVERWRITES Target Posts, Pages, Settings - DANGEROUS for Live eCommerce DB)"
echo "3) ALL            (OVERWRITES EVERYTHING - Files + Database)"
echo ""
read -r -p "Select 1, 2, or 3: " SYNC_TYPE

echo ""

# 3. Process Files if selected (1 or 3)
if [ "$SYNC_TYPE" == "1" ] || [ "$SYNC_TYPE" == "3" ]; then
    echo "--> Copying Files (ignoring wp-config.php)..."
    rsync -av --exclude 'wp-config.php' "$SOURCE_PATH/" "$TARGET_PATH/"
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

    echo "--> Importing Database into Target..."
    run_wp db import "$TARGET_PATH/sync_dump.sql" --path="$TARGET_PATH" --quiet
    rm "$TARGET_PATH/sync_dump.sql"

    echo "--> Updating URLs in Target Database..."
    OLD_URL="https://$SOURCE_DOM"
    NEW_URL="https://$TARGET_DOM"

    # Sync the Database Prefix
    echo "--> Syncing Database Table Prefix..."
    SOURCE_PREFIX=$(run_wp config get table_prefix --path="$SOURCE_PATH" --quiet)
    TARGET_PREFIX=$(run_wp config get table_prefix --path="$TARGET_PATH" --quiet)

    if [ "$SOURCE_PREFIX" != "$TARGET_PREFIX" ] && [ -n "$SOURCE_PREFIX" ]; then
        # We explicitly set it in the target's wp-config since we omitted it in rsync
        run_wp config set table_prefix "$SOURCE_PREFIX" --path="$TARGET_PATH" --quiet
    fi

    # We replace both http and https to be clean
    run_wp search-replace "http://$SOURCE_DOM" "$NEW_URL" --skip-columns=guid --path="$TARGET_PATH" --quiet
    run_wp search-replace "$OLD_URL" "$NEW_URL" --skip-columns=guid --path="$TARGET_PATH" --quiet

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
