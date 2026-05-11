<p align="center">
  <img src="assets/AppIconSourceClear.PNG" width="220" alt="IPAID Icon">
</p>

<p align="center">
  <a href="https://github.com/shplash/IPAID/stargazers">
    <img src="https://img.shields.io/github/stars/shplash/IPAID?style=for-the-badge&label=stars">
  </a>
  <a href="https://github.com/shplash/IPAID/releases/latest">
    <img src="https://img.shields.io/github/v/release/shplash/IPAID?style=for-the-badge&label=release">
  </a>
  <a href="https://github.com/shplash/IPAID/issues">
    <img src="https://img.shields.io/github/issues/shplash/IPAID?style=for-the-badge&label=open%20issues">
  </a>
</p>

<h1 align="center">IPAID</h1>

<p align="center">
  Lightweight IPA editor for iOS 15+
</p>

<br>

## Features

- Edit app bundle identifiers
- Rename apps before export
- Clone apps for side-by-side installs
- Remove unwanted app extensions
- Automatically rewrite kept extension bundle IDs
- Export updated `.ipa` files
- Keeps original IPA untouched
- Fully iPhone-native workflow
- Works before signing

<br>

## Example

<p align="center">
  <img src="assets/example4.PNG" width="360" alt="IPAID editing example">
</p>

<br>

## Why

Most iOS signing apps tie bundle identifier editing to signing workflows or certificate setup.

IPAID directly edits the IPA itself before signing it.

<br>

## Notes

IPAID does NOT sign apps directly.

Use:
- SideStore
- AltStore
- Feather
- LiveContainer
- TrollStore
- etc

to install/sign the exported IPA afterward.

<br>

## License

Licensed under MPL-2.0.
