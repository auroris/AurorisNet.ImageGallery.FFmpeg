# Native sources for AurorisNet.ImageGallery.FFmpeg

On Windows x64 with PowerShell 7.4 or later, run `pwsh -File build/Build-Native.ps1` from the extracted archive. The script uses the included source files and retrieves the self-extracting MSYS2 base, compiler and prebuilt dependency packages listed by exact version and SHA-256 in `build/inputs.json`. To use previously cached downloads, pass `-DownloadDirectory <path>`.

The `sources` directory includes the FFmpeg release tarball and the MSYS2 source packages for the redistributed native components. Extract a `.src.tar.zst` with `tar -xf <file>` to obtain its PKGBUILD, patches and upstream sources. The x264 and winpthreads source packages include Git mirrors. Their PKGBUILD files give the commits used. The MinGW-w64 CRT and headers use the same MinGW-w64 commit as winpthreads. Their respective PKGBUILD files are included separately. The GCC source package contains the compiler runtime source and MSYS2 patches.

The binaries use the Windows Universal C Runtime supplied by Windows. Redistribution notices for the bundled components are in `LICENSE.txt`.
