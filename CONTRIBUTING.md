# Contributing to ZenTap

Thank you for helping make voice input calmer, more private, and more accessible.

## Good First Contributions

- Improve onboarding copy for macOS permissions.
- Add screenshots or short demo videos.
- Refine the floating window layout and motion.
- Improve Chinese and English documentation.
- Add additional localization files.
- Improve packaging, signing, and release automation.
- Test offline recognition behavior on different macOS versions.

## Development

Build the local app:

```bash
./build.sh
```

The app is copied to:

```text
~/Desktop/ZenTap.app
```

## Notes for macOS Permissions

During development, the app is rebuilt and ad-hoc signed. macOS may treat a rebuilt app as a new identity for Accessibility permissions. If automatic text insertion stops working, remove ZenTap from:

```text
System Settings -> Privacy & Security -> Accessibility
```

Then add the current `ZenTap.app` again.

## Pull Request Guidelines

- Keep changes focused.
- Explain user-facing behavior changes clearly.
- Include screenshots or short recordings for UI changes when possible.
- Avoid adding network code unless the privacy model is explicitly discussed.
- Preserve the offline-first design principle.
