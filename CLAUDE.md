# Kukira Asset: notes for Claude

Read `SPEC.md` first. Its non-negotiable rules override anything else here.

## Building and testing

- There is no Flutter, Java or Android SDK on the owner's PC. All compiling, analysis, tests and APK builds happen in GitHub Actions (`.github/workflows/build-apk.yml`, Flutter 3.27.4). The `android/` folder is generated in CI by `flutter create` and patched by `tool/patch_android.py` from `android_overrides/`.
- GitHub CLI is portable at `C:\Users\Salim Danisy\tools\gh\bin\gh.exe` (logged in as sdkwad). Repo: `sdkwad/kukira-asset`.
- Workflow: one feature or fix per branch; push, watch with `gh run watch <id> --exit-status`, fix until green, then squash-merge onto `main` as a single commit.
- APKs: `gh run download <id> -n kukira-asset-apk -D apk`. Most phones use the `arm64-v8a` file.

## Conventions

- Every user-facing string goes in `lib/l10n/strings.dart` (declaration) and both `strings_ms.dart` and `strings_en.dart`. Bahasa Melayu is the default language.
- When editing files with a script, always read and write UTF-8 explicitly (`encoding='utf-8'` in Python). A file saved in the Windows code page broke the build once.
- Page bodies use `SafeScaffold` from `lib/ui/common.dart`. Widget tests use the harness in `test/helpers.dart` (fake `World`, no real database).
- The database schema lives in `lib/data/db.dart`. Bump `schemaVersion` and add an `onUpgrade` step for every schema change; old backups must still restore.
