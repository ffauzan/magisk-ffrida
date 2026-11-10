# Magisk Frida Stealth

Module Magisk/KernelSU/APatch yang menjalankan frida-server hasil patch saat boot.

Binary dibangun dari source frida resmi, dipatch untuk menghilangkan penanda runtime
yang umum dipakai deteksi (nama agent, thread, string, socket, memfd, port), lalu
dikemas sebagai module. Client frida standar tetap dipakai.

Status: arm64 build + module sudah diuji di itel P661N (Android 13, KernelSU Next
1.1.1): boot auto-start, `frida-ps`, attach, dan scan marker target lolos.

## Install

1. Unduh `MagiskFrida-<versi>.zip` dari Releases.
2. Install lewat aplikasi Magisk, KernelSU, atau APatch.
3. Reboot.

Port acak dibuat saat install. Lihat port:

```bash
adb shell su -c "cat /data/adb/modules/magisk-ffrida/port"
```

Hubungkan client:

```bash
adb forward tcp:27042 tcp:$(adb shell su -c "cat /data/adb/modules/magisk-ffrida/port")
frida-ps -H 127.0.0.1:27042
```

Tombol aksi module menyalakan/mematikan server dan menampilkan port.

## Build lokal

```bash
export ANDROID_NDK_ROOT=/path/to/android-ndk-r29
export STEALTH_RENAMER="$PWD/scripts/anti-anti-frida.py"
./scripts/build-frida.sh arm64 17.26.2 /tmp/frida-src
python3 build.py --frida-tag 17.26.2 --project-tag 17.26.2-1
```

Build butuh NDK r29, Node.js 18+, JDK 17, Python 3, ~20 GB disk.

## Rilis otomatis

`.github/workflows/main.yml` berjalan tiap 12 jam dan saat manual:

1. mendeteksi tag frida terbaru;
2. apply patch ke source frida;
3. build 4 arch;
4. verifikasi marker dan ELF;
5. paket module + updater.json + checksum;
6. rilis dengan tag `<frida>-<revisi>`.

Jika patch gagal apply atau verifikasi gagal, tidak ada rilis; workflow membuka issue.
