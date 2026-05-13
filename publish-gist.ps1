<#
.SYNOPSIS
    Publish/update/delete a gist under the bydynamics-shared GitHub account.
.DESCRIPTION
    Uses the bydynamics-shared account PAT (stored in env var BDY_GIST_PAT) to
    create, update, or delete gists branded under the bydynamics-shared org account.
.PARAMETER File
    Path to the local file to publish as a gist.
.PARAMETER Name
    Optional custom filename for the gist (defaults to the source filename).
.PARAMETER Description
    Optional gist description (shown in gist list).
.PARAMETER Public
    If set, creates a public gist. Default is secret (unlisted).
.PARAMETER Remove
    If set, deletes a gist by filename (searches existing gists).
.PARAMETER List
    If set, lists all gists on the bydynamics-shared account.
.EXAMPLE
    publish-gist -File "docs\plan.md" -Description "Project plan for customer X"
    publish-gist -File "docs\plan.md" -Name "customer-plan.md" -Public
    publish-gist -File "customer-plan.md" -Remove
    publish-gist -List
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$File,

    [string]$Name,
    [string]$Description = "",
    [switch]$Public,
    [switch]$Remove,
    [switch]$List
)

$ErrorActionPreference = 'Stop'

# --- Resolve PAT ---
$pat = $env:BDY_GIST_PAT
if (-not $pat) {
    Write-Error @"
BDY_GIST_PAT environment variable not set.
Set it with the bydynamics-shared account PAT (gist scope):
  [System.Environment]::SetEnvironmentVariable('BDY_GIST_PAT', '<your-pat>', 'User')
Then restart your terminal.
"@
    return
}

$headers = @{
    Authorization = "token $pat"
    Accept        = "application/vnd.github+json"
}

# --- List gists ---
if ($List) {
    $gists = Invoke-RestMethod -Uri "https://api.github.com/gists" -Headers $headers -Method Get
    if ($gists.Count -eq 0) {
        Write-Host "No gists found on bydynamics-shared." -ForegroundColor Yellow
        return
    }
    Write-Host "`nbydynamics-shared gists:" -ForegroundColor Cyan
    Write-Host ("-" * 60)
    foreach ($g in $gists) {
        $files = ($g.files.PSObject.Properties | ForEach-Object { $_.Name }) -join ", "
        $vis = if ($g.public) { "PUBLIC" } else { "SECRET" }
        Write-Host "  [$vis] $files" -ForegroundColor White
        Write-Host "         $($g.html_url)" -ForegroundColor Gray
        if ($g.description) { Write-Host "         $($g.description)" -ForegroundColor DarkGray }
    }
    Write-Host ""
    return
}

# --- Validate File param ---
if (-not $File) {
    Write-Error "Specify -File <path> or use -List to see existing gists."
    return
}

# --- Remove gist ---
if ($Remove) {
    $searchName = if ($Name) { $Name } else { Split-Path $File -Leaf }
    $gists = Invoke-RestMethod -Uri "https://api.github.com/gists" -Headers $headers -Method Get
    $match = $gists | Where-Object { $_.files.PSObject.Properties.Name -contains $searchName }
    if (-not $match) {
        Write-Error "No gist found with filename '$searchName'."
        return
    }
    $gistId = $match[0].id
    Invoke-RestMethod -Uri "https://api.github.com/gists/$gistId" -Headers $headers -Method Delete | Out-Null
    Write-Host "Deleted gist '$searchName' ($($match[0].html_url))" -ForegroundColor Green
    return
}

# --- Resolve file path ---
if (-not (Test-Path $File)) {
    Write-Error "File not found: $File"
    return
}

$resolvedFile = Resolve-Path $File
$fileDir = Split-Path $resolvedFile -Parent
$fileName = if ($Name) { $Name } else { Split-Path $resolvedFile -Leaf }
$content = Get-Content $resolvedFile -Raw -Encoding UTF8

if (-not $content) {
    Write-Error "File is empty: $File"
    return
}

# --- Upload embedded images and rewrite references ---
$ghToken = $null
try { $ghToken = (gh auth token 2>$null) } catch {}

if ($ghToken) {
    $ghHeaders = @{
        Authorization = "token $ghToken"
        Accept        = "application/vnd.github+json"
    }

    # Match markdown image syntax: ![alt](path) — skip http/https URLs
    $imagePattern = '!\[([^\]]*)\]\(([^)]+)\)'
    $matches = [regex]::Matches($content, $imagePattern)

    foreach ($m in $matches) {
        $imgPath = $m.Groups[2].Value -replace '"[^"]*"$', '' # strip optional title
        $imgPath = $imgPath.Trim()

        # Skip URLs and data URIs
        if ($imgPath -match '^(https?://|data:)') { continue }

        # Resolve relative to the file's directory
        $localImg = Join-Path $fileDir $imgPath
        if (-not (Test-Path $localImg)) {
            Write-Warning "Image not found, skipping: $imgPath"
            continue
        }

        $resolvedImg = Resolve-Path $localImg
        $imgFileName = Split-Path $resolvedImg -Leaf
        $imgBytes = [System.IO.File]::ReadAllBytes($resolvedImg)
        $imgB64 = [Convert]::ToBase64String($imgBytes)

        # Upload to bydynamics/shared-docs/gist-images/<filename>
        $targetPath = "gist-images/$imgFileName"
        $uploadUri = "https://api.github.com/repos/bydynamics/shared-docs/contents/$targetPath"

        # Check if file already exists (need SHA to update)
        $existingSha = $null
        try {
            $existing = Invoke-RestMethod -Uri $uploadUri -Headers $ghHeaders -Method Get -ErrorAction Stop
            $existingSha = $existing.sha
        } catch {}

        $uploadBody = @{
            message = "Upload gist image: $imgFileName"
            content = $imgB64
        }
        if ($existingSha) { $uploadBody.sha = $existingSha }

        try {
            $uploadResult = Invoke-RestMethod -Uri $uploadUri -Headers $ghHeaders -Method Put -Body ($uploadBody | ConvertTo-Json) -ContentType "application/json"
            $rawUrl = "https://raw.githubusercontent.com/bydynamics/shared-docs/main/$targetPath"
            # Replace the local path with the public URL in content
            $content = $content.Replace($m.Groups[2].Value, $rawUrl)
            Write-Host "  Uploaded image: $imgFileName -> $rawUrl" -ForegroundColor DarkGray
        } catch {
            Write-Warning "Failed to upload image '$imgFileName': $_"
        }
    }
}
else {
    # Check if there are local images that can't be uploaded
    if ($content -match '!\[[^\]]*\]\((?!https?://|data:)') {
        Write-Warning "Local images detected but 'gh' CLI not authenticated. Images won't render in the gist."
    }
}

# --- Check if gist already exists (update) ---
$gists = Invoke-RestMethod -Uri "https://api.github.com/gists" -Headers $headers -Method Get
$existing = $gists | Where-Object { $_.files.PSObject.Properties.Name -contains $fileName }

if ($existing) {
    # Update existing gist
    $gistId = $existing[0].id
    $body = @{
        description = if ($Description) { $Description } else { $existing[0].description }
        files       = @{ $fileName = @{ content = $content } }
    } | ConvertTo-Json -Depth 5

    $result = Invoke-RestMethod -Uri "https://api.github.com/gists/$gistId" -Headers $headers -Method Patch -Body $body -ContentType "application/json"
    Write-Host "Updated gist:" -ForegroundColor Green
    Write-Host "  $($result.html_url)" -ForegroundColor Cyan
}
else {
    # Create new gist
    $body = @{
        description = $Description
        public      = [bool]$Public
        files       = @{ $fileName = @{ content = $content } }
    } | ConvertTo-Json -Depth 5

    $result = Invoke-RestMethod -Uri "https://api.github.com/gists" -Headers $headers -Method Post -Body $body -ContentType "application/json"
    $vis = if ($Public) { "public" } else { "secret" }
    Write-Host "Created $vis gist:" -ForegroundColor Green
    Write-Host "  $($result.html_url)" -ForegroundColor Cyan
}

Write-Host "  Filename: $fileName" -ForegroundColor Gray
