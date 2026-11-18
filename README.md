# AurorisNet.ImageGallery.FFmpeg

FFmpeg and FFprobe for Windows x64, as a NuGet package that copies the tools into an application's output.

![GPL-2.0-or-later license](https://raw.githubusercontent.com/auroris/AurorisNet.Build/main/badges/license-gpl-2.0-or-later.svg)
![Windows](https://raw.githubusercontent.com/auroris/AurorisNet.Build/main/badges/windows.svg)

[AurorisNet.ImageGallery](https://github.com/auroris/AurorisNet.ImageGallery) starts these tools for each video in a gallery folder: FFprobe reads the video's size and length, and FFmpeg writes a short silent MP4 preview and a PNG icon. The build holds what those three commands need and leaves the rest of FFmpeg out:

- **Reads** H.264, HEVC, VP8, VP9 and AV1 video from MP4, MOV, WebM and Matroska files.
- **Writes** H.264 video to MP4 with x264, and PNG images.
- **Runs on the CPU.** The tools use no hardware decoder and no Media Foundation, so they behave the same on a workstation and on Windows Server.
- **Leaves out** every audio codec, network protocol and capture device, and FFplay. The tools open local files only.

## Install

```shell
dotnet add package AurorisNet.ImageGallery.FFmpeg
```

The package holds no .NET assembly. On build and on publish, NuGet copies `ffmpeg.exe`, `ffprobe.exe`, their DLLs and `LICENSE.txt` into an `ffmpeg` folder in the application's output. Start a tool from there:

```csharp
string ffprobe = Path.Combine(AppContext.BaseDirectory, "ffmpeg", "ffprobe.exe");
```

The project must reference the package with `PackageReference`, which every SDK-style project does.

## What the build enables

| Part of FFmpeg | Enabled |
|---|---|
| Programs | `ffmpeg`, `ffprobe` |
| Protocols | `file` |
| Demuxers | `mov`, which reads MP4 and MOV, and `matroska`, which reads WebM and Matroska |
| Decoders | `h264`, `hevc`, `vp8`, `vp9`, and `libdav1d` for AV1 |
| Encoders | `libx264`, `png` |
| Muxers | `mp4`, `image2` |
| Filters | `scale`, `trim`, `reverse`, `format` |

[`build/build-native.sh`](https://github.com/auroris/AurorisNet.ImageGallery.FFmpeg/blob/main/build/build-native.sh) holds the full `configure` line. An application that needs another codec or filter needs a different FFmpeg build.

## Supported versions

| Component | Version |
|---|---|
| FFmpeg | The package version is the FFmpeg release: package `9.0.2` holds FFmpeg 9.0.2. A release with two numbers, such as 9.1, becomes package `9.1.0`. |
| Operating system | Windows x64. The tools use the Universal C Runtime that Windows includes. |
| Project | Any SDK-style .NET project. |

## Developing

You need Windows x64, PowerShell 7.4 or later and the .NET 10 SDK or later. From the repository root:

```powershell
./build/Build-Native.ps1
dotnet pack ./AurorisNet.ImageGallery.FFmpeg.nuspec -o ./artifacts/packages
./test/Test-Package.ps1
```

`Build-Native.ps1` downloads the FFmpeg source, an MSYS2 base and the compiler and library packages that [`build/inputs.json`](https://github.com/auroris/AurorisNet.ImageGallery.FFmpeg/blob/main/build/inputs.json) names, and checks each against its SHA-256 there. It builds in a temporary folder, then writes the tools to `artifacts/native/win-x64` and the matching sources to `artifacts/ffmpeg-<version>-sources.zip`.

`Test-Package.ps1` publishes a small .NET project that takes the package from `artifacts/packages` only. It checks that the published files are the built files, then runs the gallery's probe, preview and icon commands on a sample of each input codec in `test/samples`.

| Folder | Contents |
|---|---|
| `build` | The native build, its pinned inputs, and the README that goes into the source archive. |
| `test` | The package test, its consumer project and the sample videos. |
| `automation` | `Update-Upstream.ps1`, which moves the pin to a new FFmpeg release. |

## Releases

The package follows FFmpeg's stable releases. `upstream.yml` starts by hand: it compares the newest stable FFmpeg release with the pinned one. For a newer release it checks the source tarball's signature against FFmpeg's release key, commits the new version and checksum to `main`, and starts `release.yml`.

`release.yml` builds the pinned version on a hosted Windows runner, packs it and runs the package test. When the test passes, it pushes the package to nuget.org and publishes a GitHub release with the package and `ffmpeg-<version>-sources.zip`. Both workflows have a `dry-run` input, which publishes nothing. `ci.yml` runs the same build and test on each pull request.

A new package version reaches ImageGallery as a Dependabot pull request there. The [release guide](https://github.com/auroris/AurorisNet.Build/blob/main/docs/releasing.md) describes the shared workflows.

## License

The FFmpeg build includes x264, so the tools are under the GNU General Public License, version 2 or later. `ffmpeg/LICENSE.txt` in the package holds the license texts and notices of FFmpeg, x264, dav1d, zlib and the MinGW-w64 runtime.

Each [release](https://github.com/auroris/AurorisNet.ImageGallery.FFmpeg/releases) has an `ffmpeg-<version>-sources.zip` with the sources of those components, the patches and the build scripts for the binaries in that package. `LICENSE.txt` links to it.

The build scripts, the package test and the sample videos in this repository are under the [MIT license](https://github.com/auroris/AurorisNet.ImageGallery.FFmpeg/blob/main/LICENSE).
