# Publishing ZenTap to GitHub

This project is ready to publish as a normal GitHub repository.

## Option A: Use the GitHub Website

1. Open [github.com/new](https://github.com/new).
2. Repository name: `ZenTap`
3. Description:

   ```text
   A tiny, private, mouse-first macOS dictation tool.
   ```

4. Choose **Public**.
5. Do not add a README, `.gitignore`, or license on GitHub. They already exist locally.
6. Click **Create repository**.
7. In this local project folder, run the commands GitHub shows under **push an existing repository from the command line**.

They will look like this:

```bash
git remote add origin https://github.com/YOUR_NAME/ZenTap.git
git branch -M main
git push -u origin main
```

Replace `YOUR_NAME` with your GitHub username.

## Option B: Use GitHub CLI

If `gh` is installed and authenticated:

```bash
gh repo create ZenTap --public --source=. --remote=origin --push \
  --description "A tiny, private, mouse-first macOS dictation tool."
```

## Suggested Repository Topics

```text
macos
swift
appkit
speech-recognition
dictation
accessibility
assistive-technology
privacy
offline
open-source
```

## Suggested Short Description

```text
A tiny, private, mouse-first macOS dictation tool.
```
