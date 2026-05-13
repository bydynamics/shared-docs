# How to Share Single MD Files from a Private/Internal Repository with Customers

## Problem

You have a private or internal GitHub repository and want to share specific `.md` files with external customers — without exposing the entire repo.

---

## Options

### 1. GitHub Gists (Simplest)

- Create a **secret gist** (unlisted URL, not indexed, but accessible to anyone with the link)
- Or a **public gist** if discoverability is fine
- Copy the MD content into a gist and share the URL
- Supports rendered Markdown preview

**Pros**: Zero setup, instant sharing, version history  
**Cons**: Manual copy/sync, no access control beyond "has the link", no folder structure

---

### 2. GitHub Pages (Static Site from a Public Repo)

- Create a separate **public** repo (e.g., `bydynamics/docs-public`)
- Copy or auto-publish selected MD files there
- Enable GitHub Pages → files render as a website
- Share the Pages URL with customers

**Automation option**: GitHub Action in private repo that copies specific files to the public repo on push.

```yaml
# .github/workflows/publish-docs.yml
name: Publish Selected Docs
on:
  push:
    paths:
      - 'docs/shared/**'
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cpina/github-action-push-to-another-repository@main
        env:
          API_TOKEN_GITHUB: ${{ secrets.DOCS_PUBLISH_PAT }}
        with:
          source-directory: 'docs/shared'
          destination-github-username: 'bydynamics'
          destination-repository-name: 'docs-public'
          target-branch: main
```

**Pros**: Automated, rendered HTML, custom domain possible  
**Cons**: Requires second repo, all published content is public

---

### 3. Fine-Grained Personal Access Token + Raw URL (Quick & Dirty)

- Generate a fine-grained PAT with `contents: read` on the specific repo
- Share the raw file URL with token embedded (NOT recommended for security)
- Better: build a tiny proxy/redirect that authenticates on behalf of the customer

**Verdict**: Avoid — tokens leak, no audit trail, expires

---

### 4. GitHub Repository Collaborator (Per-File Not Possible)

- GitHub does not support per-file permissions
- You can invite a customer as an **outside collaborator** with `read` access — but they see the entire repo
- Use a dedicated "shared docs" repo if you go this route

**Pros**: Native GitHub access, no extra tooling  
**Cons**: Exposes full repo or requires separate repo

---

### 5. Share via Rendered URL Services

Use third-party services that render raw GitHub MD files:

| Service | URL Pattern | Notes |
|---------|-------------|-------|
| **github.com raw** | `https://raw.githubusercontent.com/...` | Only works for public repos |
| **htmlpreview.github.io** | Wraps raw HTML | Public repos only |
| **MarkdownShare** | Upload/paste | No repo link needed |

**For private repos** — none of these work without authentication.

---

### 6. Azure Blob Storage + Static Website (Best for Customers)

- Publish selected MD files (rendered to HTML) to Azure Blob Storage static website
- Optionally gate with Azure AD / SAS tokens for access control
- Automate with GitHub Action → render MD to HTML → upload to blob

```yaml
# .github/workflows/publish-to-azure.yml
name: Publish Docs to Azure
on:
  push:
    paths:
      - 'docs/customer/**'
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Convert MD to HTML
        run: |
          npm install -g marked
          for f in docs/customer/*.md; do
            marked "$f" > "${f%.md}.html"
          done
      - uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - name: Upload to Blob
        run: |
          az storage blob upload-batch \
            --account-name bydynamicsdocs \
            --destination '$web' \
            --source docs/customer/ \
            --pattern '*.html' \
            --overwrite
```

**Pros**: Access control (SAS tokens, Entra ID), custom domain, scalable  
**Cons**: Azure cost (minimal), setup effort

---

### 7. Email/Teams Share with Auto-Export (Pragmatic)

- GitHub Action converts specific MD files to PDF on push
- Attach or upload to a shared Teams channel / SharePoint folder

```yaml
- name: Convert to PDF
  uses: BaileyJM02/markdown-to-pdf@v1
  with:
    input_path: docs/customer/plan.md
    output_dir: output/
- name: Upload to SharePoint
  # Use Microsoft Graph API or Power Automate webhook
```

---

## Recommended Approach for bydynamics

| Scenario | Recommendation |
|----------|---------------|
| Quick one-off share | **Gist** (secret, share link) |
| Ongoing customer docs | **Separate public/internal repo** + GitHub Pages |
| Access-controlled sharing | **Azure Blob static site** with SAS tokens |
| Internal between repos | **GitHub Action** cross-repo publish |
| Customer portal | Azure Static Web App + Entra ID auth |

---

## Folder Convention (Private Repo)

```
repo-root/
├── docs/
│   ├── internal/       # Never shared
│   ├── shared/         # Auto-published to public repo or Azure
│   └── customer/       # Per-customer folders
│       ├── contoso/
│       └── fabrikam/
```

Add a `.github/workflows/publish-docs.yml` that triggers on changes to `docs/shared/**` or `docs/customer/**`.

---

## Security Considerations

- Never embed tokens/secrets in shared URLs
- Prefer time-limited SAS tokens for Azure Blob
- Audit who accessed shared links (Azure provides this)
- Use branch protection on the source docs folder
- Review what's in `docs/shared/` before enabling auto-publish

---

## Developer Setup & Usage (bydynamics)

Our implementation uses **GitHub Pages** on `bydynamics/shared-docs` with a global PowerShell function.

### One-Time Setup

1. Install [GitHub CLI](https://cli.github.com/) and authenticate:
   ```
   gh auth login
   ```

2. Add this function to your PowerShell profile (`notepad $PROFILE`):

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

3. Reload your profile:
   ```
   . $PROFILE
   ```

### Usage

**Publish a file** (from any repo, any folder):
```powershell
publish-to-pages -File "docs\my-plan.md"
```

**Publish with custom name**:
```powershell
publish-to-pages -File "docs\my-plan.md" -Name "customer-project-plan.md"
```

**Update a file** (just run the same command again — overwrites):
```powershell
publish-to-pages -File "docs\my-plan.md"
```

**Remove a published file**:
```powershell
publish-to-pages -File "customer-project-plan.md" -Remove
```

### Result

Customer-shareable URL: `https://bydynamics.github.io/shared-docs/<filename>`

| Source file | Customer URL |
|-------------|--------------|
| `my plan.md` | https://bydynamics.github.io/shared-docs/my-plan |
| `api-spec.md` | https://bydynamics.github.io/shared-docs/api-spec |

### Notes

- Only `.md` files supported
- Spaces in filenames become hyphens automatically
- Content is **public** — never publish secrets or credentials
- The function auto-downloads the latest script each run (self-updating)
- Pages rebuild takes ~30 seconds after publish
