[CmdletBinding()]
param([switch] $Apply)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$ProgressPreference = 'SilentlyContinue'
Set-Location (Split-Path $PSScriptRoot -Parent)

function Get-PackageVersion([string] $Upstream) {
    if ($Upstream.Split('.').Count -eq 2) { return "$Upstream.0" }
    return $Upstream
}

function Get-VerifiedHash([string] $Version) {
    # FFmpeg publishes the tarball signing key's fingerprint at https://ffmpeg.org/download.html.
    $fingerprint = 'FCF986EA15E6E293A5644F10B4322F04D67658D8'
    $base = "https://ffmpeg.org/releases/ffmpeg-$Version.tar.xz"
    $temp = [IO.Directory]::CreateTempSubdirectory('ffmpeg-signature-').FullName
    try {
        $tar = Join-Path $temp 'source.tar.xz'
        $key = Join-Path $temp 'upstream.asc'
        $trusted = Join-Path $temp 'trusted.gpg'
        Invoke-WebRequest $base -OutFile $tar
        Invoke-WebRequest "$base.asc" -OutFile "$tar.asc"
        Invoke-WebRequest 'https://ffmpeg.org/ffmpeg-devel.asc' -OutFile $key
        # Export just the pinned key into the keyring used for signature verification.
        gpg --batch --no-autostart --homedir $temp --import $key
        gpg --batch --no-autostart --homedir $temp --output $trusted --export $fingerprint
        gpgv --homedir $temp --keyring $trusted "$tar.asc" $tar
        return (Get-FileHash $tar -Algorithm SHA256).Hash.ToLowerInvariant()
    } finally {
        Remove-Item -LiteralPath $temp -Recurse
    }
}

$manifestPath = 'build/inputs.json'
$specPath = 'AurorisNet.ImageGallery.FFmpeg.nuspec'
$manifestText = [IO.File]::ReadAllText((Resolve-Path $manifestPath))
$manifest = $manifestText | ConvertFrom-Json
$specText = [IO.File]::ReadAllText((Resolve-Path $specPath))
$sourceVersion = $manifest.ffmpeg.version
$packageVersion = ([xml]$specText).package.metadata.version
if ($packageVersion -ne (Get-PackageVersion $sourceVersion)) { throw 'The pinned FFmpeg and NuGet versions disagree.' }

# A documentation change can move main while the same package version is still building.
$workflowRuns = "repos/$env:GITHUB_REPOSITORY/actions/workflows/release.yml/runs"
foreach ($status in 'in_progress', 'queued', 'pending', 'waiting', 'requested') {
    $active = gh api -X GET $workflowRuns -f branch=main -f event=workflow_dispatch -f status=$status -F per_page=1 --jq '.workflow_runs[0].id // empty'
    if ($active) {
        Write-Host "Release run $active is $status on main. Let it finish before starting another release."
        return
    }
}

# The shared publisher uploads NuGet first, then creates the GitHub release and its assets.
$owner, $repo = $env:GITHUB_REPOSITORY -split '/', 2
$query = @'
query($owner:String!, $repo:String!, $tag:String!, $ref:String!) {
  repository(owner:$owner, name:$repo) {
    release(tagName:$tag) { isDraft releaseAssets(first:20) { nodes { name } } }
    ref(qualifiedName:$ref) { target { oid } }
  }
}
'@
$state = gh api graphql -f query=$query -f owner=$owner -f repo=$repo -f tag="v$packageVersion" -f ref="refs/tags/v$packageVersion" |
    ConvertFrom-Json
$release = $state.data.repository.release
$assets = $release.releaseAssets.nodes.name
$complete = $release -and !$release.isDraft -and
    $assets -contains "AurorisNet.ImageGallery.FFmpeg.$packageVersion.nupkg" -and
    $assets -contains "ffmpeg-$sourceVersion-sources.zip"

$releaseCommit = $null
if (!$complete) {
    $releaseCommit = $state.data.repository.ref.target.oid
    Write-Host "Release v$packageVersion is incomplete. Finish it before advancing the upstream pin."
} else {
    $index = (Invoke-WebRequest 'https://ffmpeg.org/releases/').Content
    $versions = [regex]::Matches($index, 'href="ffmpeg-(\d+\.\d+(?:\.\d+)?)\.tar\.xz"') |
        ForEach-Object { $_.Groups[1].Value }
    if (!$versions) { throw 'No stable FFmpeg source tarballs found in the upstream release index.' }
    $latest = $versions | Sort-Object { [version](Get-PackageVersion $_) } -Descending | Select-Object -First 1
    $nextPackage = Get-PackageVersion $latest
    if ([version]$nextPackage -le [version]$packageVersion) {
        Write-Host "FFmpeg $sourceVersion and package $packageVersion are current."
        return
    }

    $hash = Get-VerifiedHash $latest
    $manifest.ffmpeg.version = $latest
    $manifest.ffmpeg.sha256 = $hash
    $oldElement = "<version>$packageVersion</version>"
    if (!$specText.Contains($oldElement)) { throw "Could not find $oldElement in $specPath." }
    $specText = $specText.Replace($oldElement, "<version>$nextPackage</version>")
    Write-Host "Verified FFmpeg $latest ($hash) for package $nextPackage."
    if (!$Apply) { Write-Host 'Dry run. The new pin would be committed and the release workflow started.'; return }

    $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding utf8NoBOM
    [IO.File]::WriteAllText((Resolve-Path $specPath), $specText)
    git config user.name 'github-actions[bot]'
    git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
    git add -- $manifestPath $specPath
    git commit -m "Update FFmpeg to $latest"
    git push origin HEAD:main
}

$head = git rev-parse HEAD
if (!$releaseCommit) { $releaseCommit = $head }
$runs = gh api -X GET $workflowRuns -f branch=main -f event=workflow_dispatch -f head_sha=$releaseCommit -F per_page=20 |
    ConvertFrom-Json
# A dry run of release.yml publishes nothing, so retrying one would not finish the release.
$prior = $runs.workflow_runs | Where-Object { $_.display_title -notlike '*(dry run)*' } | Select-Object -First 1
if ($prior -and $prior.status -ne 'completed') {
    Write-Host "Release run $($prior.id) is $($prior.status)."
    return
}
if ($releaseCommit -ne $head) {
    if (!$prior) { throw "The reserved tag points to $releaseCommit but there is no release run for that commit to retry." }
    Write-Host "Retry release run $($prior.id) for reserved commit $releaseCommit."
    if ($Apply) { gh run rerun $prior.id }
} else {
    Write-Host "Dispatch release.yml on main for $head."
    if ($Apply) { gh workflow run release.yml --ref main }
}
