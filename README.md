<p align="center">
  <img src="assets/AppIconSourceClear.PNG" width="140" alt="IPAID Icon">
</p>

<h1 align="center">IPAID</h1>

<p align="center">
  Lightweight iPhone IPA bundle identifier editor.
</p>

<p align="center">
  SideStore • AltStore • LiveContainer
</p>

---

# Features

- Select `.ipa` files directly from Files
- Read app bundle identifiers
- Edit main app bundle identifiers
- Automatically rewrite `.appex` extension bundle identifiers
- Export updated `.ipa` files
- Keeps original IPA untouched
- Generates readable export filenames
- No certificate required for editing
- Fully iPhone-native workflow
- Works before signing

---

# Example

<p align="center">
  <img src="assets/example1.PNG" width="320" alt="IPAID Example">
</p>

---

# Why

Most iOS signing apps tie bundle identifier editing to signing workflows or certificate setup.

IPAID directly edits the IPA itself before SideStore/AltStore signing.

---

# Notes

IPAID does NOT sign apps directly.

Use:
- SideStore
- AltStore
- Feather
- LiveContainer
- etc

to install/sign the exported IPA afterward.

---

# Current Support

- Supports iOS 16.0+
- Main app `CFBundleIdentifier`
- `.appex` extension bundle identifiers
- Readable export naming
- Extension rewrite counting
- Version/build display
- Copy/paste helpers
- Success haptics

---

# License

Licensed under MPL-2.0.
