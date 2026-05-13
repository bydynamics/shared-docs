# bydynamics Shared Docs

Public documentation published from private bydynamics repositories.

**Browse**: https://bydynamics.github.io/shared-docs/

---

## For Developers: Setup (one-time)

Add this to your PowerShell profile (`notepad $PROFILE`):

```powershell
# --- bydynamics: Publish MD files to GitHub Pages ---
function publish-to-pages {
    param(
        [Parameter(Mandatory)][string]$File,
        [string]$Name,
        [switch]$Remove
    )
    $scriptB64 = gh api repos/bydynamics/shared-docs/contents/publish-to-pages.ps1 --jq '.content' 2>$null
    if (-not $scriptB64) { Write-Error "Failed to download script. Check gh auth."; return }
    $scriptContent = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($scriptB64))
    $tempFile = Join-Path $env:TEMP "publish-to-pages.ps1"
    Set-Content -Path $tempFile -Value $scriptContent -Encoding UTF8
    $params = @{ File = $File }
    if ($Name) { $params.Name = $Name }
    if ($Remove) { $params.Remove = $true }
    & $tempFile @params
}
# --- end bydynamics publish-to-pages ---
```

Then reload: `. $PROFILE`

### Prerequisites

- [GitHub CLI](https://cli.github.com/) installed
- Authenticated: `gh auth login`
- Member of **bydynamics** org with repo access

---

## Usage

### Publish a file (from any repo, any folder)

```powershell
publish-to-pages -File "docs\my-plan.md"
```

### Custom output name

```powershell
publish-to-pages -File "docs\my-plan.md" -Name "customer-project-plan.md"
```

### Remove a published file

```powershell
publish-to-pages -File "customer-project-plan.md" -Remove
```

---

## What happens

1. Script downloads latest publish logic from this repo
2. File gets pushed to `bydynamics/shared-docs`
3. GitHub Pages auto-rebuilds (~30 seconds)
4. You get a shareable URL

### URL format

| Source file | Customer URL |
|-------------|--------------|
| `my plan.md` | https://bydynamics.github.io/shared-docs/my-plan |
| `api-spec.md` | https://bydynamics.github.io/shared-docs/api-spec |

---

## Rules

- Only `.md` files
- Spaces in filenames become hyphens
- Content is **public** — don't publish secrets/credentials
- Updates: just run the command again (overwrites)
- Script always pulls latest version from this repo (auto-updating)