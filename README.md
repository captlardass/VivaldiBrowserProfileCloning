# Copy-VivaldiSettings

Copy your tuned Vivaldi settings from one profile to any number of other profiles — without touching passwords, cookies, or sessions.

Built for administrators who keep one Vivaldi profile per customer and want every profile to look and behave the same.

## What it does

1. Lists every Vivaldi profile (display name, folder, last changed).
2. Asks which profile to copy settings **from**.
3. Asks which profiles to copy settings **to** (or all of them).
4. Shows a summary and asks for confirmation.
5. Backs up each target, then applies the template settings while **keeping each profile's own name and avatar**.

## What is copied — and what is not

| Copied (`Preferences`)                         | Never touched                                  |
|------------------------------------------------|------------------------------------------------|
| UI layout, panels, tab behaviour               | Saved passwords (`Login Data`)                 |
| Keyboard shortcuts, mouse gestures             | Cookies and active sessions                    |
| Themes, appearance, privacy settings           | History, autofill, payment data (`Web Data`)   |
| Search engines, downloads, general settings    | Bookmarks, extensions' stored data             |

Customer profiles stay isolated from each other.

## Requirements

- Windows 10 / 11
- Windows PowerShell 5.1 or PowerShell 7+
- Vivaldi installed in the default location (`%LOCALAPPDATA%\Vivaldi\User Data`)

## Usage

```powershell
# Interactive run
.\Copy-VivaldiSettings.ps1

# Dry run — shows what would happen, writes nothing
.\Copy-VivaldiSettings.ps1 -WhatIf

# Close Vivaldi automatically if it is running
.\Copy-VivaldiSettings.ps1 -Force

# Custom Vivaldi data folder (e.g. standalone install)
.\Copy-VivaldiSettings.ps1 -UserDataPath "D:\Vivaldi\User Data"
```

If script execution is blocked, allow it for the current session only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## Parameters

| Parameter       | Description                                                    |
|-----------------|----------------------------------------------------------------|
| `-UserDataPath` | Vivaldi user data folder. Default: `%LOCALAPPDATA%\Vivaldi\User Data` |
| `-Force`        | Closes Vivaldi without asking.                                 |
| `-WhatIf`       | Dry run. No files are changed.                                 |

## Restoring a backup

Each target gets a backup named `Preferences.bak-<timestamp>` in its profile folder. To undo:

1. Close Vivaldi.
2. In the profile folder, delete `Preferences`.
3. Rename `Preferences.bak-<timestamp>` to `Preferences`.

Tip: find a profile's folder via `vivaldi://about` → **Profile Path**.

## Known limitations

- **Protected settings may reset.** Chromium guards a few settings (startup pages, homepage) with tamper hashes. These may revert on first launch and need to be set once by hand.
- **Fallback copy.** If the name/avatar merge fails, the file is copied as-is and a warning is shown. Rename that profile in Vivaldi afterwards.
- **Keep a clean template.** Best practice is a dedicated template profile that never signs into any customer system.

## License

Released under the [MIT License](LICENSE).
