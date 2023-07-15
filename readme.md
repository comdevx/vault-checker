# README.md

This code is a Bash script used to retrieve data from HashiCorp Vault and generate environment files based on the key list found in the Vault. It checks for new versions and only updates files with newer versions. The script reads values from the `vault.env` file, which is necessary to specify the environment variables used for connecting to the Vault and other configurations. The remaining parts of the code retrieve data from the Vault and generate environment files using the file names and content obtained from the Vault.

If a file has an 'env' extension, it will be created in the .env format. Here's an example of the file's content:

```
FIELD_NAME=VALUE
```

However, if a file does not have an 'env' extension, it will be created according to its name, but the content inside will be in JSON format.

## vault.env

The `vault.env` file is required to use this script. It specifies the necessary environment variables for connecting to HashiCorp Vault and other configurations. Here's an example of the content in the `vault.env` file:

```
HOST=https://vault.test.com
TOKEN=token_of_the_hashi_vault
PROJECT_NAME=project-name
PROJECT_PATH=api
DESTINATION=folder-name
```

You can edit the values in the `vault.env` file to match your own configurations. Set the values according to your requirements for the script to connect to the Vault and generate the environment files correctly.

## Usage

1. Copy the code into your project.
2. Check and edit the `vault.env` file to configure it.
3. Open the script in a terminal or Bash-compatible tool.
4. Run the script using the command `./vault.sh`.

The script will retrieve data from HashiCorp Vault and generate environment files based on the configurations specified in the `vault.env` file. It will check for new versions of files and, if found, display the new data and prompt you to update the version.

## Author

This script was created by ComdevX.
Facebook: [https://www.facebook.com/devpairueai](https://www.facebook.com/devpairueai)
Translate By: ChatGPT