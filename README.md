<p align="center">
  <img src="assets/AppIconSourceClear.PNG" width="140" alt="IPAID Icon">
</p>

<h1 align="center">IPAID</h1>
<p align="center">
   Lightweight iPhone IPA editor
</p>

---

# Features

- Edit app bundle identifiers
- Rename apps before export
- Clone apps for side-by-side installs
- Remove unwanted app extensions
- Automatically rewrite kept extension bundle IDs
- Export updated `.ipa` files
- Keeps original IPA untouched
- Fully iPhone-native workflow
- Works before signing

---

# Example

<p align="center">
  <img src="assets/example1.PNG" width="360" alt="IPAID editing example">
</p>


---

# Why

Most iOS signing apps tie bundle identifier editing to signing workflows or certificate setup.

IPAID directly edits the IPA itself before signing it.

---

# Notes

IPAID does NOT sign apps directly.

Use:
- SideStore
- AltStore
- Feather
- LiveContainer
- TrollStore
- etc

to install/sign the exported IPA afterward.

---

# License

Licensed under MPL-2.0.
