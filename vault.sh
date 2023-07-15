#!/bin/bash

# Created by: ComdevX
# Facebook: https://www.facebook.com/devpairueai

if ! command -v jq &>/dev/null; then
  echo "Error: jq is not installed." >&2
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo "Error: curl is not installed." >&2
  exit 1
fi

if ! command -v sed &>/dev/null; then
  echo "Error: sed is not installed." >&2
  exit 1
fi

if ! command -v diff &>/dev/null; then
  echo "Error: diff is not installed." >&2
  exit 1
fi

# Check if vault.env exists
if [ ! -f vault.env ]; then
  echo "Error: vault.env file not found." >&2
  exit 1
fi

# Get environment variables from vault.env file
TOKEN=$(grep TOKEN vault.env | cut -d '=' -f2)
HOST=$(grep HOST vault.env | cut -d '=' -f2)
PROJECT_NAME=$(grep PROJECT_NAME vault.env | cut -d '=' -f2)
PROJECT_PATH=$(grep PROJECT_PATH vault.env | cut -d '=' -f2)
DESTINATION=$(grep DESTINATION vault.env | cut -d '=' -f2)

# Check the destination directory if not empty and exists
if [ ! -z "$DESTINATION" ] && [ ! -d "$DESTINATION" ]; then
    echo "Error: Destination directory not found." >&2
    exit 1
fi

# Get list of keys from Vault
URL_LIST="$HOST/v1/$PROJECT_NAME/metadata/$PROJECT_PATH/?list=true"
TEMP_LIST=$(mktemp)
curl --location $URL_LIST --header "X-Vault-Token: $TOKEN" >"$TEMP_LIST" 2>/dev/null

# Get the keys from the list
KEY_LIST=$(jq -r '.data.keys | to_entries | .[] | .value' $TEMP_LIST 2>/dev/null)

# Check if the list of keys is empty
if [ -z "$KEY_LIST" ]; then
  echo "Error: No keys found." >&2
  exit 1
fi

function check_new_version() {

  # Set NEW_VERSIONS to false
  NEW_VERSIONS=false

  for KEY in $KEY_LIST; do

    # Get the file name and file type from the key
    URL_FILE="$HOST/v1/$PROJECT_NAME/data/$PROJECT_PATH/$KEY"
    FILE_NAME=$(echo "$URL_FILE" | awk -F'/' '{print $NF}')
    FILE_TYPE=$(echo "$KEY" | awk -F'.' '{print $NF}')

    # Get the version of the key from Vault
    TEMP_FILE=$(mktemp)
    curl --location "$URL_FILE" --header "X-Vault-Token: $TOKEN" >"$TEMP_FILE" 2>/dev/null

    # Get the current version of the file
    VERSION=$(jq -r '.data.metadata.version' "$TEMP_FILE")

    # Check if the file already exists in version.txt
    if ! grep -q "$KEY" version.txt; then
      echo "$KEY=$VERSION" >>version.txt
    fi

    # Get the old version of the file from version.txt
    OLD_VERSION=$(grep "$KEY" version.txt | cut -d '=' -f2)

    # Check if the new version is greater than the old version
    if [ "$VERSION" -gt "$OLD_VERSION" ]; then

      # Set NEW_VERSIONS to true
      NEW_VERSIONS=true

      # Download the new and old versions of the file
      NEW_URL="$HOST/v1/$PROJECT_NAME/data/$PROJECT_PATH/$KEY"
      OLD_URL="$HOST/v1/$PROJECT_NAME/data/$PROJECT_PATH/$KEY?version=$OLD_VERSION"
      NEW_FILE=$(mktemp)
      OLD_FILE=$(mktemp)
      TEMP_NEW=$(mktemp)
      TEMP_OLD=$(mktemp)
      curl --location "$NEW_URL" --header "X-Vault-Token: $TOKEN" >"$TEMP_NEW" 2>/dev/null
      curl --location "$OLD_URL" --header "X-Vault-Token: $TOKEN" >"$TEMP_OLD" 2>/dev/null

      # Get the data from the new and old versions of the file
      jq -r '.data.data' "$TEMP_NEW" >"$NEW_FILE"
      jq -r '.data.data' "$TEMP_OLD" >"$OLD_FILE"

      # Compare the two files
      diff <(echo "$(cat "$NEW_FILE")") <(echo "$(cat "$OLD_FILE")") | while read -r line; do
        if [[ $line == \<* ]]; then
          echo "line: $line"
        fi
      done

      # Delete the temporary files
      rm "$NEW_FILE"
      rm "$OLD_FILE"
      rm "$TEMP_NEW"
      rm "$TEMP_OLD"

      # Prompt the user to update the version
      read -p "Do you want to update version? (y/n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then

        # Update the version in version.txt
        sed "s/$KEY=$OLD_VERSION/$KEY=$VERSION/g" version.txt >version.txt.tmp && mv version.txt.tmp version.txt

        # Check if the destination directory is not empty
        if [ ! -z "$DESTINATION" ]; then
          FILE_NAME="$DESTINATION/$FILE_NAME"
        fi

        # Write the new version of the file to disk
        if [ "$FILE_TYPE" = "env" ]; then
          jq -r '.data.data | to_entries | .[] | .key + "=" + (.value | tostring)' "$TEMP_FILE" >"$FILE_NAME"
        else
          jq -r '.data.data' "$TEMP_FILE" >"$FILE_NAME"
        fi

        echo "Environment file created: $FILE_NAME"
      fi
    fi
  done

  # Check if any new versions were found
  if [ "$NEW_VERSIONS" = false ]; then
    echo "No new versions found."
  fi
}

function begin() {

  for KEY in $KEY_LIST; do

    # Get the file name and file type from the key
    URL_FILE="$HOST/v1/$PROJECT_NAME/data/$PROJECT_PATH/$KEY"
    FILE_NAME=$(echo "$URL_FILE" | awk -F'/' '{print $NF}')
    FILE_TYPE=$(echo "$KEY" | awk -F'.' '{print $NF}')

    # Get the version of the key from Vault
    TEMP_FILE=$(mktemp)
    curl --location "$URL_FILE" --header "X-Vault-Token: $TOKEN" >"$TEMP_FILE" 2>/dev/null

    # Get the current version of the file
    VERSION=$(jq -r '.data.metadata.version' "$TEMP_FILE")

    # Check if the file already exists in version.txt
    if ! grep -q "$KEY" version.txt; then
      echo "$KEY=$VERSION" >>version.txt
    fi

    # Check if the destination directory is not empty
    if [ ! -z "$DESTINATION" ]; then
      FILE_NAME="$DESTINATION/$FILE_NAME"
    fi

    # Write the new version of the file to disk
    if [ "$FILE_TYPE" = "env" ]; then
      jq -r '.data.data | to_entries | .[] | .key + "=" + (.value | tostring)' "$TEMP_FILE" >"$FILE_NAME"
    else
      jq -r '.data.data' "$TEMP_FILE" >"$FILE_NAME"
    fi

    echo "Environment file created: $FILE_NAME"
  done
}

# Check if version.txt exists
if [ ! -f version.txt ]; then
  begin
else
  check_new_version
fi

# Delete the temporary files
rm "$TEMP_FILE"
rm "$TEMP_LIST"
