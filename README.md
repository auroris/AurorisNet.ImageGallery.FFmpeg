# AurorisNet.ImageGallery.FFmpeg

Minimal Windows x64 `ffmpeg.exe` and `ffprobe.exe` NuGet package for [AurorisNet.ImageGallery](https://github.com/auroris/AurorisNet.ImageGallery). Copies the binaries, DLLs, and `LICENSE.txt` into `ffmpeg/` in your build and publish output (contains no .NET assembly).

![GPL-2.0-or-later license](https://raw.githubusercontent.com/auroris/AurorisNet.Build/main/badges/license-gpl-2.0-or-later.svg)
![Windows](https://raw.githubusercontent.com/auroris/AurorisNet.Build/main/badges/windows.svg)

CPU-only build tailored to local video previews and PNG icons (no audio codecs, network protocols, capture devices, or `ffplay`):
- **Demuxers / decoders:** MP4, MOV, WebM, Matroska — H.264, HEVC, VP8, VP9, AV1 (`libdav1d`)
- **Encoders / muxers / filters:** `libx264` (MP4), `png` (`image2`), `scale`, `trim`, `reverse`, `format`

Package versions match the bundled FFmpeg release (e.g. `9.0.2`).

## Install

```shell
dotnet add package AurorisNet.ImageGallery.FFmpeg
```

```csharp
string ffprobe = Path.Combine(AppContext.BaseDirectory, "ffmpeg", "ffprobe.exe");
```

## Links

- [Native build, testing, and releases](https://github.com/auroris/AurorisNet.ImageGallery.FFmpeg/blob/main/docs/developing.md)
- [Build configure line](https://github.com/auroris/AurorisNet.ImageGallery.FFmpeg/blob/main/build/build-native.sh)

## License

Bundled FFmpeg/x264 binaries are **GPL-2.0-or-later** (`ffmpeg/LICENSE.txt`; matching source archive `ffmpeg-<version>-sources.zip` on each [GitHub release](https://github.com/auroris/AurorisNet.ImageGallery.FFmpeg/releases)). Repository scripts and tests are [MIT](https://github.com/auroris/AurorisNet.ImageGallery.FFmpeg/blob/main/LICENSE).
