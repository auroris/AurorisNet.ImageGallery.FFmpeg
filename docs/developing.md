# Developing

Requires Windows x64, PowerShell 7.4+, and the .NET 10 SDK.

```powershell
./build/Build-Native.ps1
dotnet pack ./AurorisNet.ImageGallery.FFmpeg.nuspec -o ./artifacts/packages
./test/Test-Package.ps1
```

- `build/Build-Native.ps1` downloads SHA-256-verified sources/MSYS2 packages from `build/inputs.json`, outputs binaries to `artifacts/native/win-x64`, and packages `artifacts/ffmpeg-<version>-sources.zip`.
- `test/Test-Package.ps1` verifies the packed `.nupkg` against sample videos for every supported codec in `test/samples`.
- `automation/Update-Upstream.ps1` (and `upstream.yml`) checks for new stable FFmpeg releases, verifies tarball signatures, and triggers `release.yml`.

See the shared [release guide](https://github.com/auroris/AurorisNet.Build/blob/main/docs/releasing.md).
