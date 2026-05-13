# bydynamics Gist Sharing — Developer Guide

Share markdown files (with images) from any repo as company-branded gists under **`bydynamics-shared`**.

![Gist example on bydynamics-shared](gist-example.png)

---

## One-Time Setup

### 1. Install GitHub CLI

```
winget install GitHub.cli
gh auth login
```

### 2. Store the PAT

Get the `bydynamics-shared` PAT from the team vault (scope: `gist` only), then:

```powershell
[System.Environment]::SetEnvironmentVariable('BDY_GIST_PAT', '<pat-from-vault>', 'User')
```

### 3. Add to your PowerShell profile

Run `notepad $PROFILE` and add:

```powershell
# --- bydynamics: Ensure BDY_GIST_PAT is loaded from User env ---
if (-not $env:BDY_GIST_PAT) {
    $env:BDY_GIST_PAT = [System.Environment]::GetEnvironmentVariable('BDY_GIST_PAT', 'User')
}

# --- bydynamics: Publish gists under bydynamics-shared account ---
function publish-gist {
    param(
        [string]$File,
        [string]$Name,
        [string]$Description,
        [switch]$Public,
        [switch]$Remove,
        [switch]$List
    )
    $scriptPath = Join-Path $env:TEMP "publish-gist.ps1"
    $scriptB64 = gh api repos/bydynamics/shared-docs/contents/publish-gist.ps1 --jq '.content' 2>$null
    if (-not $scriptB64) { Write-Error "Failed to download publish-gist script. Check gh auth."; return }
    $scriptContent = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($scriptB64 -replace "\s","")))
    Set-Content -Path $scriptPath -Value $scriptContent -Encoding UTF8
    $params = @{}
    if ($File) { $params.File = $File }
    if ($Name) { $params.Name = $Name }
    if ($Description) { $params.Description = $Description }
    if ($Public) { $params.Public = $true }
    if ($Remove) { $params.Remove = $true }
    if ($List) { $params.List = $true }
    & $scriptPath @params
}
# --- end bydynamics publish-gist ---
```

### 4. Reload

```powershell
. $PROFILE
```

---

## Usage

### Publish a gist (secret/unlisted by default)

```powershell
publish-gist -File "docs\plan.md" -Description "Project plan for Contoso"
```

### Publish as public

```powershell
publish-gist -File "docs\plan.md" -Public
```

### Custom filename

```powershell
publish-gist -File "docs\my-long-name.md" -Name "plan.md"
```

### Update an existing gist

Same filename = auto-update:

```powershell
publish-gist -File "docs\plan.md"
```

### List all gists

```powershell
publish-gist -List
```

### Delete a gist

```powershell
publish-gist -File "plan.md" -Remove
```

---

## Images

Local images referenced in your markdown are **automatically uploaded** to `bydynamics/shared-docs/gist-images/` and the markdown URLs are rewritten to `raw.githubusercontent.com`. Images render inline in the gist without appearing as extra files.

Requirements:
- `gh` CLI must be authenticated (used for image upload to shared-docs)
- Images must use relative paths in the markdown (e.g. `![](screenshot.png)`)
- HTTP URLs are left unchanged

---

## How It Works

1. Reads your local `.md` file
2. Detects local image references (`![alt](relative/path.png)`)
3. Uploads images to `bydynamics/shared-docs/gist-images/` via GitHub API
4. Rewrites image URLs to `raw.githubusercontent.com` in the content
5. Creates or updates the gist via the GitHub REST API using `BDY_GIST_PAT`

The gist appears at `https://gist.github.com/bydynamics-shared/<id>` — share this URL with customers.

---

## Details

| Field | Value |
|-------|-------|
| Account | `bydynamics-shared` |
| Gist URL pattern | `https://gist.github.com/bydynamics-shared/<id>` |
| PAT scope | `gist` only |
| PAT env var | `BDY_GIST_PAT` (user-level) |
| Script source | `bydynamics/shared-docs/publish-gist.ps1` |
| Image hosting | `bydynamics/shared-docs/gist-images/` |
| Visibility default | Secret (unlisted — anyone with the link can view) |

---

## Tips

- **Secret ≠ private** — anyone with the URL can view a secret gist, it's just not indexed/discoverable
- Use `-Public` only if you want the gist to appear in searches and on the account profile
- The script is self-updating — always pulls the latest from shared-docs
- Works from any directory, any repo, any terminal
