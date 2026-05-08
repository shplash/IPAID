# IPAID

---

Supports iOS 16.0+

---

A lightweight iPhone IPA bundle identifier editor.

Built for SideStore / AltStore workflows where an app needs to update over an existing install without consuming another App ID slot or losing app data.

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

Input:

```txt
com.exampleapp123.fire
```

Output:

```txt
com.exampleapp679.ice
```

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
