# GetGoogleAccessToken

This is a Bash script for generating a JWT token and authorizing the Google API.

In order to use this, you will need to create a service account by following [official instructions by Google](https://developers.google.com/identity/protocols/oauth2/service-account#creatinganaccount) and download `service-account-key.json`.

# Usage

- Download the script
- Make sure that the script has executable permissions with the command `chmod +x script.sh`.
- Open the script with your preferred text editor.
- Edit the SERVICE_ACCOUNT_KEY_PATH variable to match the path to your service account key file.
- Edit the AUTH_SCOPE variable for your needs.
- Run the script with the command ./script.sh.