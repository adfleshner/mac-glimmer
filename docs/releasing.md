# Releasing Glimmer

Releases are built by GitHub Actions ([`.github/workflows/build.yml`](../.github/workflows/build.yml)).

## Every push

Each push to `main` (and every pull request) builds `Glimmer.dmg` on a macOS runner and saves it
as a workflow artifact. Open **Actions → Build Glimmer → the run → Artifacts** to download it.
Artifacts are kept for 90 days. Use these to test a build before releasing it.

## Publishing a release

Tag the commit and push the tag. The version number comes from the tag; you don't need to edit
`Info.plist`.

```bash
git tag -a v1.2.0 -m "Glimmer 1.2.0"
git push origin v1.2.0
```

The workflow builds `Glimmer.dmg` (version 1.2.0 inside), creates the **Glimmer v1.2.0** release
with install notes, the SHA-256 and GitHub's auto-generated change list, and attaches the DMG.
The file name never changes, so the README's Download button
(`/releases/latest/download/Glimmer.dmg`) always downloads the newest release directly.

The disk-image window (background, arrow, icon positions) is laid out by
[dmgbuild](https://github.com/dmgbuild/dmgbuild) from `scripts/dmg-settings.py`; the artwork is
`Resources/dmg-background.tiff`, rendered by `scripts/render-assets.sh`.

To (re)publish an existing tag, run the workflow by hand: **Actions → Build Glimmer → Run
workflow** and enter the tag.

## Optional: sign with your certificate

Without a certificate, CI builds are ad-hoc signed. They work the same, but macOS treats each
update as a new app, so users have to re-allow the brightness-key permission after updating.
Signing every build with the same certificate makes that permission stick.

1. In **Keychain Access**, find your "Apple Development" or "Developer ID Application"
   certificate, right-click it → **Export…** → save as `cert.p12` with a password.
2. Copy it as base64: `base64 -i cert.p12 | pbcopy`
3. In the GitHub repo: **Settings → Secrets and variables → Actions → New repository secret**:
   - `MACOS_CERT_P12`: paste the base64
   - `MACOS_CERT_PASSWORD`: the export password
4. Delete `cert.p12`.

The next build imports it into a temporary keychain and signs with it.

## Later: notarization

With a paid Apple Developer ID, add a notarization step after "Build DMG"
(`xcrun notarytool submit … --wait` and `xcrun stapler staple …`; see the comments in
`scripts/make-dmg.sh`). That removes the "Open Anyway" step for users.
