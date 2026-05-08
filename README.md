# IPAID

A lightweight iPhone IPA bundle identifier editor.

Built for SideStore / AltStore style workflows where an app needs to update over an existing install without taking another App ID slot or losing app data.

---

# Features

- Select `.ipa` files directly from Files
- Read app bundle identifiers
- Edit main app bundle identifier
- Automatically rewrite `.appex` extension bundle identifiers
- Export updated `.ipa`
- Keeps original IPA untouched
- Generates readable export filenames
- No certificate required for editing
- iPhone-only workflow
- Works before signing

---

# Example

Input:

```txt
MeloVertex.ipa
Bundle ID:
com.vertexselection.MeloVertex
