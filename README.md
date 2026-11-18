# AurorisNet.ImageGallery.FFmpeg

Windows x64 builds of FFmpeg and FFprobe for [AurorisNet.ImageGallery](https://github.com/auroris/AurorisNet.ImageGallery). The gallery probes a local video, makes a silent H.264 MP4 preview and extracts a PNG icon. The package supports H.264, HEVC, VP8, VP9 and software AV1 decoding from MP4/MOV and WebM/Matroska containers. Browser playback of the original still depends on the browser's codecs.

## Use the package

```shell
dotnet add package AurorisNet.ImageGallery.FFmpeg
```

NuGet copies `ffmpeg.exe`, `ffprobe.exe`, their native DLLs and `LICENSE.txt` into the application's `ffmpeg/` directory on build and publish. Start the tools from `Path.Combine(AppContext.BaseDirectory, "ffmpeg")`. They run on the CPU and work on Windows Server without Media Foundation.

## Build and test

To build locally, use Windows x64, PowerShell 7.4 or later and the .NET 10 SDK or later. From the repository root, run:

```powershell
./build/Build-Native.ps1
dotnet pack ./AurorisNet.ImageGallery.FFmpeg.nuspec -o ./artifacts/packages
./test/Test-Package.ps1
```

The native build uses pinned sources and puts the tools in `artifacts/native/win-x64/`. The package test restores and publishes a small .NET consumer and runs the gallery's probe, preview and icon commands on synthetic samples for each supported input codec.

## License and source

The FFmpeg build includes x264 and reports GPL version 2 or later. The package includes the upstream license texts and notices in `ffmpeg/LICENSE.txt`. The packaging scripts and synthetic test fixtures are covered by this repository's [MIT license](https://github.com/auroris/AurorisNet.ImageGallery.FFmpeg/blob/main/LICENSE).

Each [package release](https://github.com/auroris/AurorisNet.ImageGallery.FFmpeg/releases) includes an `ffmpeg-<upstream version>-sources.zip` asset with the exact component sources, patches and build recipes. The license file shipped with the binaries links directly to their source archive. GitHub Actions checks weekly for a newer stable FFmpeg release. It verifies the upstream signature, records the new source checksum and runs the Release workflow on a hosted Windows runner. Each release must pass the package and codec tests before it reaches NuGet.org and GitHub. The upstream check and release can also be run manually from Actions.
