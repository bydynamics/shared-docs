<#
.SYNOPSIS
    Publish a markdown file from any bydynamics repo to GitHub Pages.

.DESCRIPTION
    One command to share any .md file publicly via bydynamics.github.io/shared-docs/
    No workflow setup needed in the source repo.
    Referenced images are automatically uploaded alongside the markdown.

.EXAMPLE
    publish-to-pages -File "docs/my-plan.md"
    publish-to-pages -File "docs/my-plan.md" -Name "customer-plan.md"
    publish-to-pages -File "customer-plan.md" -Remove

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
    if ($targetName -notlike "*.md") { $targetName += ".md" }
}

$slug = $targetName -replace '\.md$', ''
$imgFolder = "img/$slug"

function Upload-File {
    param([string]$LocalPath, [string]$RemotePath, [string]$CommitMsg)
    $b64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($LocalPath))
    $sha = gh api "repos/$targetRepo/contents/$RemotePath" --jq '.sha' 2>$null
    $body = @{ message = $CommitMsg; content = $b64; branch = $branch }
    if ($sha) { $body.sha = $sha }
    $body | ConvertTo-Json | gh api "repos/$targetRepo/contents/$RemotePath" --method PUT --input - --silent
}

function Remove-RemoteFile {
    param([string]$RemotePath)
    $sha = gh api "repos/$targetRepo/contents/$RemotePath" --jq '.sha' 2>$null
    if ($sha) {
        @{ message = "Remove: $RemotePath"; sha = $sha; branch = $branch } |
            ConvertTo-Json | gh api "repos/$targetRepo/contents/$RemotePath" --method DELETE --input - | Out-Null
    }
}

if ($Remove) {
    $sha = gh api "repos/$targetRepo/contents/$targetName" --jq '.sha' 2>$null
    if (-not $sha) {
        Write-Error "File '$targetName' not found in $targetRepo"
        exit 1
    }
    @{ message = "Remove: $targetName"; sha = $sha; branch = $branch } |
        ConvertTo-Json | gh api "repos/$targetRepo/contents/$targetName" --method DELETE --input - | Out-Null
    Write-Host "Removed: $targetName" -ForegroundColor Yellow

    $imgFiles = gh api "repos/$targetRepo/contents/$imgFolder" --jq '.[].path' 2>$null
    if ($imgFiles) {
        foreach ($imgPath in $imgFiles) {
            Remove-RemoteFile -RemotePath $imgPath
            Write-Host "  Removed image: $imgPath" -ForegroundColor DarkYellow
        }
    }
    Write-Host "Pages will update in ~30 seconds." -ForegroundColor DarkGray
}
else {
    $mdDir = Split-Path (Resolve-Path $File) -Parent
    $mdContent = Get-Content (Resolve-Path $File) -Raw

    # Find all markdown image references: ![alt](path)
    $imagePattern = '!\[[^\]]*\]\(([^)]+)\)'
    $matches_ = [regex]::Matches($mdContent, $imagePattern)

    $uploadedCount = 0
    foreach ($m in $matches_) {
        $rawRef = $m.Groups[1].Value
        $decodedRef = [System.Uri]::UnescapeDataString($rawRef)
        if ($decodedRef -match '^(https?://|data:)') { continue }
        $localImg = Join-Path $mdDir $decodedRef
        if (-not (Test-Path $localImg)) { continue }

        $imgName = (Split-Path $decodedRef -Leaf) -replace ' ', '-'
        $remotePath = "$imgFolder/$imgName"

        Upload-File -LocalPath (Resolve-Path $localImg) -RemotePath $remotePath -CommitMsg "Image: $imgName"
        $uploadedCount++
        Write-Host "  Uploaded: $remotePath" -ForegroundColor DarkCyan

        # Use site-root-relative path so Jekyll permalink routing doesn't break it
        $newRef = "/shared-docs/$imgFolder/$imgName"
        $mdContent = $mdContent.Replace($rawRef, $newRef)
    }

    # Upload the modified markdown
    $mdBytes = [System.Text.Encoding]::UTF8.GetBytes($mdContent)
    $b64Content = [Convert]::ToBase64String($mdBytes)
    $sha = gh api "repos/$targetRepo/contents/$targetName" --jq '.sha' 2>$null
    $body = @{ message = "Publish: $targetName"; content = $b64Content; branch = $branch }
    if ($sha) { $body.sha = $sha }
    $body | ConvertTo-Json | gh api "repos/$targetRepo/contents/$targetName" --method PUT --input - --silent

    $url = "https://bydynamics.github.io/shared-docs/$slug"
    Write-Host ""
    Write-Host "Published: $targetName ($uploadedCount images)" -ForegroundColor Green
    Write-Host "URL: $url" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Share this link with customers." -ForegroundColor DarkGray
}