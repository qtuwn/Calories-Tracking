# Android Signing Secrets Setup Guide

This guide explains how to set up GitHub Secrets for Android release signing in CI/CD.

## ⚠️ IMPORTANT SECURITY NOTES

- **NEVER** commit keystore files or `key.properties` to version control
- **NEVER** share your keystore password or key password publicly
- These secrets are stored securely in GitHub and only accessible during CI/CD runs

## Prerequisites

- You have an existing Android keystore file: `android/app/keystore/upload-keystore.jks`
- You know your keystore password, key password, and key alias

## Step 1: Base64 Encode Your Keystore

You need to convert your keystore file to a Base64 string that will be stored in GitHub Secrets.

### Windows (PowerShell)

Open PowerShell in the repository root and run:

```powershell
# Encode keystore to Base64 and copy to clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android/app/keystore/upload-keystore.jks")) | Set-Clipboard
```

The Base64 string is now in your clipboard. You can verify by pasting it somewhere (but be careful not to share it!).

### macOS / Linux (Bash)

Open Terminal in the repository root and run:

```bash
# Encode keystore to Base64 and copy to clipboard (macOS)
base64 -i android/app/keystore/upload-keystore.jks | pbcopy

# OR encode and display (Linux - you'll need to manually copy)
base64 android/app/keystore/upload-keystore.jks
```

## Step 2: Create GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each of the following:

### Required Secrets

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded keystore file | (Paste the Base64 string from Step 1) |
| `ANDROID_KEYSTORE_PASSWORD` | Password for the keystore | `your-keystore-password` |
| `ANDROID_KEY_PASSWORD` | Password for the signing key | `your-key-password` |
| `ANDROID_KEY_ALIAS` | Alias of the signing key | `upload` |

### How to Add Each Secret

1. Click **New repository secret**
2. Enter the **Name** exactly as shown above (case-sensitive)
3. Paste or type the **Secret** value
4. Click **Add secret**

## Step 3: Verify Secrets Are Set

After adding all secrets, verify they exist:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. You should see all 4 secrets listed:
   - ✅ ANDROID_KEYSTORE_BASE64
   - ✅ ANDROID_KEYSTORE_PASSWORD
   - ✅ ANDROID_KEY_PASSWORD
   - ✅ ANDROID_KEY_ALIAS

## Step 4: Test the CI/CD Pipeline

1. Push a commit to `main` or `master` branch, OR
2. Go to **Actions** tab → **Android Release** → **Run workflow** → **Run workflow**

The workflow will:
- Reconstruct the keystore from the Base64 secret
- Reconstruct `android/key.properties` from the secrets
- Build a signed release AAB (and optionally APK)
- Upload the artifacts for download

## Troubleshooting

### "Keystore file not found" error
- Verify `ANDROID_KEYSTORE_BASE64` contains the complete Base64 string
- Ensure you encoded the entire `.jks` file, not just part of it

### "Password incorrect" error
- Double-check `ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEY_PASSWORD`
- Ensure there are no extra spaces or newlines in the secret values

### "Key alias not found" error
- Verify `ANDROID_KEY_ALIAS` matches the alias used when creating the keystore
- Common aliases: `upload`, `key`, `release`

## Security Best Practices

- Rotate secrets periodically
- Use different keystores for different environments (dev/staging/prod) if needed
- Never print or log secret values in CI/CD workflows
- Restrict access to repository secrets to trusted team members only

