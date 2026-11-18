#!/usr/bin/env bash
set -euo pipefail
export PATH=/ucrt64/bin:/usr/bin LC_ALL=C TZ=UTC SOURCE_DATE_EPOCH=946684800
export PKG_CONFIG_PATH=/ucrt64/lib/pkgconfig

version=$1
jobs=$2
mkdir build-output native
cd build-output
../ffmpeg-"$version"/configure \
  --arch=x86_64 --target-os=mingw32 --cc=gcc --enable-shared --disable-static \
  --disable-autodetect --disable-everything --disable-network --disable-avdevice --disable-ffplay --disable-doc --disable-debug \
  --enable-gpl --enable-libx264 --enable-libdav1d --enable-zlib \
  --extra-cflags="-ffunction-sections -fdata-sections" --extra-ldflags="-static-libgcc -Wl,--gc-sections,--no-insert-timestamp" \
  --enable-protocol=file --enable-demuxer=mov,matroska --enable-muxer=mp4,image2 \
  --enable-parser=h264,hevc,vp8,vp9,av1 --enable-decoder=h264,hevc,vp8,vp9,libdav1d \
  --enable-encoder=libx264,png --enable-filter=scale,trim,reverse,format
# Keep __FILE__ diagnostics independent of the workstation's temporary directory.
# FFmpeg's make-time ECFLAGS avoids recording that directory in its public -buildconf.
make -j"$jobs" "ECFLAGS=-ffile-prefix-map=\"$(cygpath -am ..)\"=." ffmpeg.exe ffprobe.exe
cp ffmpeg.exe ffprobe.exe lib*/*-[0-9]*.dll ../native/
strip --strip-all ../native/*.{exe,dll}
cp /ucrt64/bin/{libdav1d-*,libwinpthread-1,libx264-*,libz-1}.dll ../native/
cd ..

{
  printf 'FFmpeg %s\n\n' "$version"
  printf '%s\n' 'This build uses FFmpeg under GPL-2.0-or-later with x264, dav1d, zlib and the MinGW-w64 runtime.'
  tag_version=$version
  if [[ $tag_version =~ ^[0-9]+\.[0-9]+$ ]]; then tag_version+=.0; fi
  printf 'Matching source and build scripts: https://github.com/auroris/AurorisNet.ImageGallery.FFmpeg/releases/download/v%s/ffmpeg-%s-sources.zip\n\n' "$tag_version" "$version"
  for notice in ffmpeg-"$version"/{LICENSE.md,COPYING.GPLv2,COPYING.LGPLv2.1} \
      sources/x264-COPYING.txt /ucrt64/share/licenses/{dav1d,zlib,libwinpthread,libgcc,crt,headers}/*; do
    printf '\n--- %s ---\n\n' "$notice"
    cat "$notice"
  done
} > native/LICENSE.txt
