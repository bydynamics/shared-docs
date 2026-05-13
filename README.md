# bydynamics Shared Docs

Public documentation published from private bydynamics repositories.

**Browse**: https://bydynamics.github.io/shared-docs/

---

## For Developers: How to Publish

### Prerequisites

- [GitHub CLI](https://cli.github.com/) installed and authenticated (`gh auth login`)
- Member of the **bydynamics** GitHub organization

### Publish a file

From **any bydynamics repo**, run:

```powershell
# One-liner: download script and publish a file
Invoke-Expression (gh api repos/bydynamics/shared-docs/contents/publish-to-pages.ps1 --jq '.content' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String()) }); publish-to-pages -File "path\to\your-file.md"
```

Or if you have the script locally (in `.github/scripts/`):

```powershell
.\.github\scripts\publish-to-pages.ps1 -File "docs\my-plan.md"
```

### Custom filename

```powershell
.\.github\scripts\publish-to-pages.ps1 -File "docs\my-plan.md" -Name "customer-project-plan.md"
```

### Remove a published file

```powershell
.\.github\scripts\publish-to-pages.ps1 -File "customer-project-plan.md" -Remove
```

### What happens

1. File gets pushed to `bydynamics/shared-docs` (this repo)
2. GitHub Pages auto-rebuilds (~30 seconds)
3. You get a shareable URL: `https://bydynamics.github.io/shared-docs/<filename>`

### URL format

| Source file | Published URL |
|-------------|---------------|
| `my plan.md` | `bydynamics.github.io/shared-docs/my-plan` |
| `docs/api-spec.md` | `bydynamics.github.io/shared-docs/api-spec` |

### Rules

- Only `.md` files supported
- Spaces in filenames are converted to hyphens
- Anyone with the URL can view (public) — don't publish secrets
- To unpublish, use `-Remove`
- All published files are visible in this repo's file list

---

*Script: [publish-to-pages.ps1](publish-to-pages.ps1)*