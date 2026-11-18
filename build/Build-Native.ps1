#Requires -Version 7.4
[CmdletBinding()]
param(
    [string] $ArtifactsDirectory = (Join-Path $PSScriptRoot '../artifacts'),
    [string] $DownloadDirectory,
    [ValidateRange(1, 256)]
    [int] $Jobs = [Math]::Min([Environment]::ProcessorCount, 12)
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if (-not $IsWindows) { throw 'Build-Native.ps1 requires Windows x64.' }
$ArtifactsDirectory = [IO.Path]::GetFullPath($ArtifactsDirectory)
if (-not $DownloadDirectory) { $DownloadDirectory = Join-Path $ArtifactsDirectory 'downloads' }
$DownloadDirectory = [IO.Directory]::CreateDirectory($DownloadDirectory).FullName
$lock = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'inputs.json') | ConvertFrom-Json -AsHashtable
$version = $lock.ffmpeg.version

function Get-PinnedFile([string]$Name, [string]$Url, [string]$Sha256) {
    $cached = Join-Path $DownloadDirectory $Name
    # A published source bundle already contains its source downloads.
    $bundled = Join-Path $PSScriptRoot "../sources/$Name"
    foreach ($candidate in $bundled, $cached) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            if ((Get-FileHash -LiteralPath $candidate).Hash -ne $Sha256) { throw "SHA-256 mismatch for $candidate" }
            return [IO.Path]::GetFullPath($candidate)
        }
    }
    Write-Host "Downloading $Name"
    $partial = "$cached.$([guid]::NewGuid()).part"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $partial -MaximumRetryCount 2
        if ((Get-FileHash -LiteralPath $partial).Hash -ne $Sha256) { throw "SHA-256 mismatch for $Url" }
        [IO.File]::Move($partial, $cached, $true)
    } finally {
        if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial }
    }
    return $cached
}

function Expand-Input([string]$Archive, [string]$Directory, [string]$Tar, [string[]]$Members = @()) {
    & $Tar -xf $Archive -C $Directory @Members
    if ($LASTEXITCODE) { throw "Could not extract $Archive." }
}

$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$work = [IO.Directory]::CreateTempSubdirectory('AurorisNet-FFmpeg-').FullName
try {
    $base = Get-PinnedFile ([IO.Path]::GetFileName($lock.msys2.url)) $lock.msys2.url $lock.msys2.sha256
    Expand-Input $base $work 'tar.exe'
    $msys = Join-Path $work 'msys64'
    # The pinned MSYS2 bsdtar supports zstd even when the Windows system tar does not.
    $tar = Join-Path $msys 'usr/bin/bsdtar.exe'
    foreach ($entry in $lock.packages.GetEnumerator()) {
        $ucrt = $entry.Key.StartsWith('mingw-w64-ucrt-x86_64-')
        $repo = if ($ucrt) { 'mingw/ucrt64' } else { 'msys/x86_64' }
        $member = if ($ucrt) { 'ucrt64' } else { 'usr' }
        $package = Get-PinnedFile $entry.Key "https://repo.msys2.org/$repo/$($entry.Key)" $entry.Value
        Expand-Input $package $msys $tar @($member)
    }

    $sources = [IO.Directory]::CreateDirectory((Join-Path $work 'sources')).FullName
    $ffmpegFile = "ffmpeg-$version.tar.xz"
    $ffmpeg = Get-PinnedFile $ffmpegFile "https://ffmpeg.org/releases/$ffmpegFile" $lock.ffmpeg.sha256
    Expand-Input $ffmpeg $work $tar
    Copy-Item -LiteralPath $ffmpeg -Destination $sources
    foreach ($entry in $lock.sourcePackages.GetEnumerator()) {
        $file = Get-PinnedFile $entry.Key "https://repo.msys2.org/mingw/sources/$($entry.Key)" $entry.Value
        Copy-Item -LiteralPath $file -Destination $sources
    }
    foreach ($entry in $lock.otherSources.GetEnumerator()) {
        $file = Get-PinnedFile $entry.Key $entry.Value.url $entry.Value.sha256
        Copy-Item -LiteralPath $file -Destination $sources
    }

    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'build-native.sh') -Destination $work
    Push-Location -LiteralPath $work
    try {
        & "$msys/usr/bin/bash.exe" --noprofile --norc ./build-native.sh $version $Jobs
        if ($LASTEXITCODE) { throw "FFmpeg build failed (exit $LASTEXITCODE)." }
        # Execute in isolation from the compiler's DLLs.
        foreach ($name in 'ffmpeg', 'ffprobe') {
            & "./native/$name.exe" -hide_banner -version
            if ($LASTEXITCODE) { throw "$name failed to start from the assembled runtime (exit $LASTEXITCODE)." }
        }
    } finally { Pop-Location }

    $sourceDir = [IO.Directory]::CreateDirectory((Join-Path $work 'corresponding-source')).FullName
    $scripts = [IO.Directory]::CreateDirectory((Join-Path $sourceDir 'build')).FullName
    foreach ($name in 'Build-Native.ps1', 'build-native.sh', 'inputs.json') {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $scripts
    }
    Move-Item -LiteralPath $sources -Destination (Join-Path $sourceDir 'sources')
    Copy-Item -LiteralPath (Join-Path $work 'native/LICENSE.txt') -Destination $sourceDir
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'SOURCE-README.md') -Destination (Join-Path $sourceDir 'README.md')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'SOURCE-README.md') -Destination $scripts
    $archiveName = "ffmpeg-$version-sources.zip"
    $archive = Join-Path $work $archiveName
    $zip = [IO.Compression.ZipFile]::Open($archive, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $files = [IO.Directory]::GetFiles($sourceDir, '*', [IO.SearchOption]::AllDirectories)
        [Array]::Sort($files, [StringComparer]::Ordinal)
        foreach ($file in $files) {
            $name = [IO.Path]::GetRelativePath($sourceDir, $file).Replace('\', '/')
            $entry = $zip.CreateEntry($name, [IO.Compression.CompressionLevel]::NoCompression)
            $entry.LastWriteTime = [DateTimeOffset]'2000-01-01T00:00:00Z'
            $output = $entry.Open()
            try {
                $inputStream = [IO.File]::OpenRead($file)
                try { $inputStream.CopyTo($output) } finally { $inputStream.Dispose() }
            } finally { $output.Dispose() }
        }
    } finally { $zip.Dispose() }

    # Replace only artifacts owned by this build after the binaries and source archive are complete.
    $runtime = [IO.Directory]::CreateDirectory((Join-Path $ArtifactsDirectory 'native/win-x64')).FullName
    Get-ChildItem -LiteralPath $runtime -File | Where-Object { $_.Extension -in '.exe', '.dll' -or $_.Name -eq 'LICENSE.txt' } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName }
    Get-ChildItem -LiteralPath (Join-Path $work 'native') -File | Copy-Item -Destination $runtime
    [IO.File]::Move($archive, (Join-Path $ArtifactsDirectory $archiveName), $true)
    Write-Host "Native runtime: $runtime"
    Write-Host "Corresponding source: $(Join-Path $ArtifactsDirectory $archiveName)"
} finally {
    $resolved = [IO.Path]::GetFullPath($work)
    if ([IO.Path]::GetDirectoryName($resolved) -eq $tempRoot.TrimEnd('\') -and
        [IO.Path]::GetFileName($resolved).StartsWith('AurorisNet-FFmpeg-')) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
