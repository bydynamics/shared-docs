<#
.SYNOPSIS
    Publish a markdown file from any bydynamics repo to GitHub Pages.

.DESCRIPTION
    One command to share any .md file publicly via bydynamics.github.io/shared-docs/
    No workflow setup needed in the source repo.

.EXAMPLE
    # From any repo root:
    .github\scripts\publish-to-pages.ps1 -File "docs/my-plan.md"
    
    # With custom output name:
    .github\scripts\publish-to-pages.ps1 -File "docs/my-plan.md" -Name "customer-plan.md"

    # Remove a published file:
    .github\scripts\publish-to-pages.ps1 -File "customer-plan.md" -Remove

.NOTES
    Requires: gh CLI authenticated with repo scope on bydynamics org.
    Target: bydynamics/shared-docs (GitHub Pages)
    URL pattern: https://bydynamics.github.io/shared-docs/<filename-without-extension>
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$File,

    [string]$Name,

    [switch]$Remove
)

$targetRepo = "bydynamics/shared-docs"
$branch = "main"

# Determine target filename
if ($Remove) {
    $targetName = Split-Path $File -Leaf
}
else {
    if (-not (Test-Path $File)) {
        Write-Error "File not found: $File"
        exit 1
    }
    $targetName = if ($Name) { $Name } else { (Split-Path $File -Leaf) -replace ' ', '-' }
    # Ensure .md extension
    if ($targetName -notlike "*.md") { $targetName += ".md" }
}

if ($Remove) {
    # Get file SHA (needed for deletion)
    $sha = gh api "repos/$targetRepo/contents/$targetName" --jq '.sha' 2>$null
    if (-not $sha) {
        Write-Error "File '$targetName' not found in $targetRepo"
        exit 1
    }
    $body = @{
        message = "Remove: $targetName"
        sha     = $sha
        branch  = $branch
    } | ConvertTo-Json

    $body | gh api "repos/$targetRepo/contents/$targetName" --method DELETE --input - | Out-Null
    Write-Host "Removed: $targetName" -ForegroundColor Yellow
    Write-Host "Pages will update in ~30 seconds." -ForegroundColor DarkGray
}
else {
    # Read and base64 encode the file
    $content = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes((Resolve-Path $File)))

    # Check if file already exists (update vs create)
    $sha = gh api "repos/$targetRepo/contents/$targetName" --jq '.sha' 2>$null

    $body = @{
        message = "Publish: $targetName"
        content = $content
        branch  = $branch
    }
    if ($sha) { $body.sha = $sha }

    $body | ConvertTo-Json | gh api "repos/$targetRepo/contents/$targetName" --method PUT --input - | Out-Null

    $slug = $targetName -replace '\.md$', ''
    $url = "https://bydynamics.github.io/shared-docs/$slug"

    Write-Host ""
    Write-Host "Published: $targetName" -ForegroundColor Green
    Write-Host "URL: $url" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Share this link with customers." -ForegroundColor DarkGray
}
