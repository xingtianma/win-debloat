# win-debloat

A PowerShell script for debloating Windows and targetted for gaming performance.

## Quick start

Open **PowerShell as Administrator** (right-click Start → *Terminal (Admin)* or *Windows PowerShell (Admin)*) and run:

```powershell
irm https://raw.githubusercontent.com/xingtianma/win-debloat/main/debloat.ps1 | iex
```

This downloads the latest `debloat.ps1` from this repository and runs it directly.

> **Note:** Always review a script before piping it into your shell. You can read it here: [`debloat.ps1`](debloat.ps1).

## Running locally

If you'd rather download the script first:

```powershell
git clone https://github.com/xingtianma/win-debloat.git
cd win-debloat
powershell -ExecutionPolicy Bypass -File .\debloat.ps1
```

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or later
- Administrator privileges

## Disclaimer

This script changes system settings and removes software. Create a restore point or back up your system before running it. Use at your own risk.
