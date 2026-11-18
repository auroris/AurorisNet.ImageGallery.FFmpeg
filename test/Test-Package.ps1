#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$root = Split-Path $PSScriptRoot
$feed = Join-Path $root 'artifacts/packages'
$spec = [xml](Get-Content -Raw -LiteralPath "$root/AurorisNet.ImageGallery.FFmpeg.nuspec")
$version = $spec.package.metadata.version
$testDir = Join-Path $root ('artifacts/test-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testDir)
Copy-Item -LiteralPath "$PSScriptRoot/Consumer.csproj" -Destination $testDir

# Resolve the package under test exclusively from this build. An earlier copy in the
# global NuGet cache or the public feed could otherwise mask missing package assets.
$config = [xml]@'
<configuration>
  <packageSources>
    <clear />
    <add key="candidate" value="." />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="candidate"><package pattern="AurorisNet.ImageGallery.FFmpeg" /></packageSource>
    <packageSource key="nuget.org"><package pattern="*" /></packageSource>
  </packageSourceMapping>
</configuration>
'@
$config.configuration.packageSources.add[0].value = $feed
$config.Save("$testDir/NuGet.Config")
dotnet restore "$testDir/Consumer.csproj" --configfile "$testDir/NuGet.Config" --packages "$testDir/packages" `
    --disable-build-servers "-p:GalleryFFmpegVersion=$version"
dotnet publish "$testDir/Consumer.csproj" --no-restore --disable-build-servers -c Release `
    -p:UseSharedCompilation=false "-p:GalleryFFmpegVersion=$version" -o "$testDir/publish"

$tools = Join-Path $testDir 'publish/ffmpeg'
$expected = Get-ChildItem -File -LiteralPath "$root/artifacts/native/win-x64"
$actual = Get-ChildItem -File -LiteralPath $tools
if (Compare-Object $expected.Name $actual.Name) { throw 'Published files differ from the native build.' }
foreach ($file in $expected) {
    if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath "$tools/$($file.Name)").Hash) {
        throw "Published $($file.Name) differs from the native build."
    }
}

$ffmpeg = Join-Path $tools 'ffmpeg.exe'
$ffprobe = Join-Path $tools 'ffprobe.exe'
foreach ($sample in Get-ChildItem -File -LiteralPath "$PSScriptRoot/samples") {
    $source = $sample.FullName
    $metadata = & $ffprobe -v error -select_streams V:0 -show_entries 'stream=width,height,duration:format=duration' -of json -i $source | ConvertFrom-Json
    if ($metadata.streams.Count -ne 1 -or $metadata.streams[0].width -le 0) { throw "Cannot probe $sample" }
    $start = if ($sample.BaseName -eq 'h264') { 10 } else { 0 }
    $preview = "$testDir/$($sample.BaseName)-preview.mp4"
    $icon = "$testDir/$($sample.BaseName)-icon.png"
    & $ffmpeg -v error -nostdin -abort_on empty_output -ss $start -i $source -map 0:V:0 -t 15 -an `
        -vf 'scale=260:-2' -c:v libx264 -pix_fmt yuv420p -b:v 60k -f mp4 $preview
    & $ffmpeg -v error -nostdin -abort_on empty_output -i $source -map 0:V:0 `
        -vf 'trim=end_frame=10,scale=100:-1,reverse' -frames:v 1 -c:v png -f image2 -update 1 $icon
    $streams = (& $ffprobe -v error -show_entries 'stream=codec_name,width,height,pix_fmt' -of json $preview | ConvertFrom-Json).streams
    if ($streams.Count -ne 1 -or $streams[0].codec_name -ne 'h264' -or $streams[0].pix_fmt -ne 'yuv420p' -or $streams[0].width -ne 260) {
        throw "Unexpected preview for $sample"
    }
    if ($sample.BaseName -eq 'hevc' -and $streams[0].height -le $streams[0].width) { throw 'Lost portrait rotation' }
    $bytes = [IO.File]::ReadAllBytes($icon)
    if ($bytes.Length -lt 24 -or [Convert]::ToHexString($bytes,0,8) -ne '89504E470D0A1A0A' -or
        [Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($bytes, 16)) -ne 100) { throw "Unexpected PNG icon for $sample" }
    Write-Host "Passed $($sample.Name)"
}
