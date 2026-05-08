# IPAID

Tiny iOS app for changing an IPA's main app bundle identifier.

## What it does

- Select an `.ipa` from Files
- Reads `Payload/*.app/Info.plist`
- Shows `CFBundleIdentifier`
- Lets you change it
- Rebuilds a new `.ipa`
- Lets you save/share it back to Files or SideStore

## Notes

This does not sign the IPA. SideStore/AltStore/etc will still need to sign it during install.
