# Magisk Frida Stealth — Rencana Arsitektur (Stage 1)

Status: rencana, belum ada implementasi. Dokumen ini keputusan desain untuk stage 2.

## 1. Tujuan

- Module Magisk/KernelSU/APatch berisi frida-server yang auto-start saat boot.
- Binary frida di-patch agar lolos deteksi umum (nama file, simbol, thread, string,
  socket, port, memfd) tanpa merusak kompatibilitas client frida standar.
- Build sendiri dari source frida yang di-pin, bukan bergantung pada rilis pihak ketiga.
- Installer dan perilaku boot mengikuti pola ViRb3/magisk-frida yang sudah terbukti.

Non-goal: menjamin lolos RASP berbasis perilaku (integrity check, prologue hook,
baseline thread count), menyembunyikan root itu sendiri, atau mendukung iOS.

## 2. Temuan riset

### 2.1 ViRb3/magisk-frida (basis module)

Struktur yang dipakai sekarang:

- `base/customize.sh` — `SKIPMOUNT=true`, binary di `$MODPATH/bin`, deteksi Magisk/KSU/APatch,
  ekstrak `files/frida-server-<arch>`, simpan port kustom.
- `base/service.sh` — late_start, tunggu `sys.boot_completed`, jalankan server, health check.
- `base/utils.sh` — `start_frida_server` (opsional `-l 127.0.0.1:<port>` dan `-D`),
  `check_frida_is_up` menulis status ke `module.prop`.
- `base/action.sh` — tombol aksi untuk stop/start.
- `build.py` — unduh `frida-server-<tag>-android-<arch>.xz` resmi, bungkus jadi ZIP.
- Mendukung 4 arch: arm, arm64, x86, x86_64; port default 27042, bisa diubah lewat file `port`.

Kesimpulan: ambil kerangka installer/daemon ini, ganti sumber binary dan tambah hardening.

### 2.2 strongR-frida-android dan Florida

Keduanya membangun frida-server dari source dengan patch di `frida-core` dan `frida-gum`.
Patch set Florida (basis terbaru yang dipakai strongR):

| Patch | Efek |
|---|---|
| `string_frida_rpc` | literal `frida:rpc` dibentuk runtime (base64 ganda), bukan string statis |
| `frida_agent_so` | nama agent `.so` diberi prefix UUID |
| `symbol_frida_agent_main` | rename simbol `frida*`/`FRIDA*`, entrypoint jadi `agent_entry` (patch source; bukan `main` agar tidak bentrok dengan signature C `main`), patch string rodata, rename thread `gum-js-loop`/`gmain`/`gdbus` |
| `thread_gum_js_loop`, `thread_gmain`, `update-python-script` | lanjutan script rename thread |
| `protocol_unexpected_command` | longgarkan error protokol di droidy client |
| `pool-frida` | `g_set_prgname("ggbond")` di frida-core dan frida-gum |
| `memfd-name-jit-cache` | nama memfd agent jadi `jit-cache`, bukan nama berbau frida |
| `exec-anti-anti-frida.py` | jalankan script rename saat embed agent |

Catatan penting: patch RPC hanya menyembunyikan literal dari binary. Nilai runtime tetap
`frida:rpc`, jadi client frida standar tetap kompatibel. Ini trade-off yang benar untuk
kita: stealth statis naik, client tidak perlu di-patch.

Status rilis strongR dan Florida saat riset (2026-11-10): tag terbaru `17.26.2`
tetapi daftar asset kosong; rilis `17.26.1`/`17.26.0`/`17.25.1` juga kosong. Jangan
bergantung pada artifact prebuilt.

### 2.3 Uji patch Florida terhadap frida 17.26.2 (dilakukan lokal)

Patch diuji dengan `git apply --check` pada source tag `17.26.2`:

- OK: `0002-frida_agent_so`, `0008-pool-frida`, `0009-memfd-name-jit-cache`,
  `0010-exec-anti-anti-frida.py`, patch `frida-gum/0001`.
- Gagal rebase:
  - `0001-string_frida_rpc`: `lib/base/rpc.vala` sekarang punya doc-comment sebelum `call()`.
  - `0003-symbol_frida_agent_main`: context `src/windows/windows-host-session.vala` berubah.
  - `0006-protocol_unexpected_command`: `src/droidy/droidy-client.vala` sudah tidak ada di tag ini.
  - `0004`, `0005`, `0007` hanya gagal karena `0003` (pembuat `anti-anti-frida.py`) belum jalan.

Artinya: patch set harus di-rebase dan di-pin ke versi frida tertentu, dengan gate CI.

### 2.4 Artefak frida 17.x yang perlu ditangani (dicek di source 17.26.2)

- `src/linux/linux-host-session.vala`: agent descriptor `frida-agent-<arch>.so`,
  entrypoint `frida_agent_main`, helper dex `/data/local/tmp/frida-helper-<id>.dex`,
  thread `frida-android-helper`, socket zymbiote `"/frida-zymbiote-<uuid>"`.
- `src/frida-glue.c`: thread `frida-main-loop`.
- `lib/base/linux.vala`: `memfd_create(name)` — nama memfd muncul di `/proc/<pid>/maps`.
- `lib/base/rpc.vala`: literal `frida:rpc` di tiga tempat.
- `src/agent-container.vala`: thread `frida-agent-container`.
- Patch baru yang dibutuhkan di luar Florida: rename socket abstract zymbiote dan
  helper dex/thread (contoh pendekatan: Fdrida patch 0007); rename D-Bus/helper id
  opsional (phantom-frida melakukannya, tetapi berisiko ke client).

Frida 17.6+ menghapus ptrace untuk Zygote dan memakai `/proc/$pid/mem` + payload
zymbiote, jadi artefak zymbiote (socket abstract) menjadi jalur deteksi baru.
Attach ke proses biasa tetap memakai ptrace; `TracerPid` hanya non-zero sesaat.

### 2.5 Referensi stealth lain

- `FDlucifer/Fdrida` — patch set untuk frida 17.3.2: rename RPC, agent randomize,
  entrypoint, process name, memfd, hapus prefix `/frida-` pada socket, plus dokumentasi
  vektor deteksi (ps/comm/cmdline, port, TracerPid, maps, thread).
- `TheQmaks/phantom-frida` — builder + verifier untuk frida 17.16.4; rename D-Bus
  service id, helper JNI package, zymbiote prefix, process/library/path, thread;
  punya marker list yang dipakai untuk menolak artifact bocor; smoke test di device.
  Ini referensi paling matang untuk gate kualitas build.

## 3. Keputusan arsitektur

### ADR-1: Build sendiri, pin frida 17.26.2

Pakai source frida resmi tag `17.26.2` + patch set kita. Alasan: asset strongR/Florida
kosong, rantai pasok lebih jelas, dan kita butuh patch yang tidak ada di keduanya.
Versi baru dideteksi otomatis oleh workflow; rilis dibuat otomatis hanya jika patch
apply bersih, build 4 arch sukses, dan verifikasi marker lolos. Konflik patch =
issue, bukan rilis diam-diam.

Fallback sementara: pakai binary Florida/strongR jika ada rilis yang asetnya lengkap,
hanya untuk uji coba; rilis module tetap dari build sendiri.

### ADR-2: Patch set milik sendiri, rebased, diuji apply

Patch disimpan sebagai file di `patches/frida-core` dan `patches/frida-gum`, dengan
urutan deterministik. CI menjalankan `git apply --check` untuk semua patch sebelum
build. Patch yang tidak lagi relevan (droidy) dibuang, bukan dipaksa.

Daftar v1:

1. `rpc` — literal `frida:rpc` runtime (rebase).
2. `agent-path` — nama agent `.so` random per build.
3. `symbols` — rename simbol `frida*`, entrypoint `main`, rodata strings (rebase;
   hanya target Android/Linux, hunk Windows dibuang).
4. `threads` — rename `gum-js-loop`, `gmain`, `gdbus`, `frida-main-loop`,
   `frida-agent-container`, `frida-android-helper`.
5. `prgname` — `g_set_prgname` di frida-core dan frida-gum.
6. `memfd` — nama memfd agent dari build (default netral, bukan `frida`/`jit-cache`).
7. `zymbiote-socket` — hapus/rename prefix `/frida-` dan `/frida-zymbiote-`.
8. `helper` — path helper dex keluar dari `/data/local/tmp`, nama file netral.
9. `rodata` — string marker deteksi yang aman diubah (hindari string yang dipakai
   untuk perbandingan fungsional; setiap perubahan wajib lolos smoke test).

Tidak termasuk v1: rename D-Bus service `re.frida.*`, rename API publik `Frida`.
Itu berisiko memutus client standar; phantom-frida mempertahankannya.

### ADR-3: Nama dan string dibangkitkan deterministik per rilis

`scripts/anti-anti-frida.py` mengganti simbol/string dengan nilai yang diturunkan dari
`sha256(versi frida + nama build)`; bukan `random()` murni. Tujuan: build reprodusibel,
tetap berbeda dari upstream, dan bisa diulang saat audit. Nama default binary:
`medcodec` (<=15 char agar `/proc/<pid>/comm` rapi), bisa dioverride `--name`.

### ADR-4: Transport TCP loopback, port acak, bukan 27042

`frida-server -l 127.0.0.1:<port> -D`. Port dibuat saat install (range 30000–59999),
disimpan di `<module>/port`, dipertahankan saat update. Alasan: `adb forward` hanya
mendukung TCP. Unix socket didukung frida (`unix:/path`) tetapi tidak bisa di-forward
lewat adb, jadi hanya opsi lanjutan untuk penggunaan on-device.

Port acak mengalahkan check port 27042, tetapi listener tetap terlihat di
`/proc/net/tcp`; ini residual risk yang diterima.

### ADR-5: Binary di module dir, bukan `/data/local/tmp`

`$MODPATH/bin/medcodec`, permission `0755 root:2000`, context `system_file`.
Tidak ada file frida di `/data/local/tmp`. Path `frida-helper-*.dex` dipindah ke
direktori module saat runtime.

### ADR-6: Supervisor minimal

`service.sh` menjalankan server sekali setelah boot dan menulis status ke `module.prop`.
Watchdog restart berkala tidak masuk v1 (menambah artefak proses); disiapkan sebagai
flag `watchdog` jika dibutuhkan.

### ADR-7: Deliverable mirror ViRb3/magisk-frida + rilis otomatis

Repo dan alur rilis mengikuti ViRb3, bukan hanya hasil ZIP-nya:

- Layout root sama: `base/` (template module), `main.py`, `build.py`, `util.py`,
  `pyproject.toml`, `downloads/`, `build/`, `.github/workflows/main.yml`.
- Tag rilis = versi frida + revisi: `17.26.2-1`, `17.26.2-2`, dst. `main.py`
  membandingkan tag frida terbaru dengan tag project, menulis `NEW_TAG.txt`,
  dan hanya deploy jika file itu ada. `FORCE_RELEASE=true` untuk rilis manual.
- `build.py` memakai `frida-server` hasil job build (diisi ke `downloads/`),
  lalu membungkus `MagiskFrida-<tag>.zip` dan `updater.json` untuk update channel
  Magisk. Untuk build lokal, binary diunduh dari release repo kita sendiri
  (`frida-server-<tag>-android-<arch>.xz`).
- Workflow `main.yml` berjalan berkala + `workflow_dispatch`: deteksi frida baru,
  auto-apply patch, build 4 arch, verifikasi marker, buat tag/release, unggah ZIP
  + binary + checksum. Jika patch gagal apply atau verifikasi gagal: tidak ada
  rilis, workflow membuka issue berisi log dan file patch yang konflik.

Patch tidak di-rebase otomatis secara buta. Auto yang diizinkan: apply patch
seri saat ini ke tag frida baru, `git apply -3`/`patch --fuzz` sebagai percobaan,
build, dan verifikasi. Keputusan merge manual hanya jika langkah itu gagal.
Dengan begitu rilis otomatis tetap aman dan tidak diam-diam merilis build rusak.

## 4. Struktur repo

```
magisk-ffrida/
├─ base/                      # template module, mengikuti ViRb3
│  ├─ META-INF/...
│  ├─ customize.sh
│  ├─ service.sh
│  ├─ action.sh
│  ├─ post-fs-data.sh
│  ├─ utils.sh
│  ├─ system/placeholder
│  └─ README.md
├─ patches/
│  ├─ frida-core/*.patch
│  └─ frida-gum/*.patch
├─ scripts/
│  ├─ build-frida.sh          # clone tag, apply patch, build 1 arch
│  ├─ anti-anti-frida.py      # rename simbol/string/memfd secara deterministik
│  └─ verify-artifacts.py     # tolak marker terlarang + cek ELF/arch
├─ main.py                    # cek tag frida vs tag project, tulis NEW_TAG.txt
├─ build.py                   # unduh binary rilis sendiri -> ZIP module + updater
├─ util.py                    # tag/revision helpers, GitHub API
├─ versions.json              # frida tag, patch revision, nama, marker allowlist
├─ pyproject.toml
├─ downloads/                 # cache binary (gitignored)
├─ build/                     # output ZIP/updater (gitignored)
├─ .github/workflows/
│  └─ main.yml                # patch -> build matrix -> verify -> release
└─ docs/ARCHITECTURE.md
```

## 5. Pipeline build dan rilis

Alur mengikuti ViRb3 `main.yml`, dengan build frida di dalam repo (bukan unduh upstream):

1. Trigger: `schedule` (mis. tiap 12 jam) + `workflow_dispatch` + `push` ke
   `patches/**`. Job `check_version` mengambil latest release `frida/frida`,
   membandingkan dengan tag project terakhir (`<frida>-<rev>`), dan menentukan
   `NEEDS_RELEASE`. `FORCE_RELEASE` memaksa rilis.
2. Job `patch-check`: clone frida tag baru + submodule, apply seluruh patch
   (`git am`/`git apply -3`), gagal cepat jika konflik.
3. Job `build` matrix `android-arm`, `android-arm64`, `android-x86`, `android-x86_64`:
   NDK r29, JDK 17, Node 24, Python 3.9; `configure --host=... && make`;
   jalankan `anti-anti-frida.py` pada agent sebelum embed; hasil `frida-server`.
4. Job `verify`: cek ELF/arsitektur dan scan marker terlarang (daftar di
   `versions.json`): `frida-server`, `frida-agent`, `frida-helper`, `frida:rpc`,
   `gum-js-loop`, `gmain\0`, `gdbus\0`, `pool-frida`, `pool-spawner`,
   `jit-cache\0`, `frida-zymbiote`, `frida-main-loop`, `frida-android-helper`.
   Allowlist: `Frida\0` dan `re.frida.*` (kontrak client).
5. Job `package`: `main.py` menulis `NEW_TAG.txt` (`17.26.2-1`); `build.py`
   memakai 4 binary dari artifact job build (ditaruh di `downloads/`), menulis
   `module.prop`, ZIP `MagiskFrida-<tag>.zip`, `updater.json`, `SHA256SUMS`.
6. Job `release`: buat tag + release, unggah ZIP, binary mentah, checksum.
   Jika verifikasi gagal: tidak ada tag/release; job membuka issue berisi log,
   daftar patch yang konflik, dan perintah reproduksi lokal.

Build lokal: `uv run python3 main.py` (sama seperti ViRb3) atau
`scripts/build-frida.sh <arch>` dengan NDK/SDK di env; butuh ~20 GB disk.
Untuk iterasi cepat tanpa build frida, `downloads/frida-server-<tag>-android-<arch>`
bisa diisi manual dan `build.py` akan memakainya.

## 6. Desain runtime module

Urutan boot:

1. `post-fs-data.sh` — no-op (sama seperti ViRb3).
2. `service.sh` (late_start) — tunggu `sys.boot_completed=1`.
3. Pilih port: file `port`; jika kosong generate dan tulis.
4. Jalankan `$MODPATH/bin/medcodec -l 127.0.0.1:$PORT -D`.
5. Health check: cek proses dan koneksi TCP lokal; tulis
   `description=... ✅/❌` ke `module.prop`.
6. Log di `$MODPATH/logs/`.

Operasional:

- `action.sh` — stop/start + tampilkan port aktif di output.
- Client PC:
  `adb forward tcp:27042 tcp:$(adb shell cat /data/adb/modules/magisk-ffrida/port)`
  lalu `frida-ps -H 127.0.0.1:27042` (atau `-H 127.0.0.1:<port>` tanpa forward).
- `uninstall.sh` — matikan proses, hapus file sementara helper/memfd tidak perlu
  (memfd hilang saat proses mati).

Kompatibilitas: Magisk, KernelSU, APatch (mengikuti customize.sh ViRb3, termasuk
`skip_mount` untuk KSU). Root hiding bukan tanggung jawab module; dokumentasikan
opsi Shamiko/Zygisk Next.

## 7. Verifikasi dan acceptance criteria

Gate build (otomatis):

- Semua patch apply bersih pada tag yang di-pin.
- 4 arch berhasil build, ukuran dan ELF valid.
- Scan marker terlarang = 0 hit (kecuali allowlist).
- `SHA256SUMS` cocok.

Gate device (manual, satu device root per arch utama):

- Reboot → proses jalan, port benar, status module ✅.
- `frida-ps`, attach, spawn, dan Java bridge via client standar berfungsi.
- `/proc/<pid target>/maps` tidak mengandung `frida`, `jit-cache`, `frida-agent`.
- `/proc/<pid target>/task/*/comm` tidak mengandung `gum-js-loop`, `gmain`, `gdbus`,
  `frida-main-loop`.
- `/proc/net/unix` tidak mengandung `/frida-`; port 27042 tertutup.
- `/proc/<pid>/cmdline` dan `comm` server tidak mengandung `frida`.
- Aplikasi uji deteksi (frida-detection-demo / DetectFrida / AntiFrida) tidak
  menemukan sinyal nama/port/thread.
- Update module mempertahankan port dan tidak ada proses duplikat.

Yang secara eksplisit tidak dijamin: deteksi berbasis hooks/prologue, baseline
thread count, RWX scan, Play Integrity, atau RASP yang memeriksa perilaku.

## 8. Risiko dan mitigasi

| Risiko | Mitigasi |
|---|---|
| Patch drift tiap rilis frida | Pin versi, gate apply+build, upgrade manual |
| Rename merusak client | Pertahankan protokol `frida:rpc`, `Frida` API, `re.frida.*`; smoke test client |
| Patch rodata merusak fitur | Hanya string non-fungsional; uji attach/spawn/Java bridge |
| Build 4 arch lama/mahal | Matrix CI, cache NDK; build lokal per arch |
| Port acak menyulitkan user | `action.sh` menampilkan port; dokumentasi `adb forward` |
| Listener tetap terlihat | Terima; loopback-only, port acak, token/cert sebagai opsi nanti |
| Deteksi perilaku (RASP) | Di luar cakupan v1; dokumentasikan batas |
| Android 16KB page | NDK r29 + flag alignment; verifikasi di device 16KB |

## 9. Roadmap implementasi (stage 2)

1. Scaffold `base/` dari ViRb3 (installer, service, action, utils) + `module.prop`.
2. Rebase patch Florida ke 17.26.2; tambah patch zymbiote/helper/memfd/thread.
3. Tulis `anti-anti-frida.py` deterministik + `verify-artifacts.py`.
4. Port `main.py`/`build.py`/`util.py` ViRb3: sumber binary dari release sendiri,
   tag `<frida>-<rev>`, `updater.json`.
5. Workflow `main.yml`: deteksi frida baru → patch-check → build matrix → verify →
   package → release; auto-issue saat patch gagal.
6. Uji device: boot, client, marker scan, aplikasi deteksi.
7. Dokumentasi pemakaian dan prosedur upgrade frida (termasuk cara rebase patch).

## 10. Referensi

- ViRb3/magisk-frida — https://github.com/ViRb3/magisk-frida
- strongR-frida-android — https://github.com/hzzheyang/strongR-frida-android
- Florida — https://github.com/Ylarod/Florida
- Fdrida — https://github.com/FDlucifer/Fdrida
- phantom-frida — https://github.com/TheQmaks/phantom-frida
- OWASP MASTG reverse engineering tool detection —
  https://mas.owasp.org/MASTG/knowledge/android/MASVS-RESILIENCE/MASTG-KNOW-0030/
- Otukan, detecting modified Frida builds —
  https://otukan.co/how-to-detect-community-sponsored-frida-variants/
- Frida 17.6.0 release notes —
  https://frida.re/news/2026/01/18/frida-17-6-0-released/

## 11. Status implementasi

- Patch set di-rebase ke frida `17.26.2` dan lolos `apply-patches.sh` dari source bersih.
- frida-server arm64 berhasil dibangun dengan NDK r29; verifier marker PASS.
- Module diuji di itel P661N, Android 13, KernelSU Next 1.1.1: install, reboot,
  auto-start, `frida-ps`, attach, dan action stop/start berfungsi.
- Target process: `/memfd:codecache`, socket `@/.virt-sessions-*`, tanpa marker
  `frida`/`gum-js-loop`/`gmain`/`gdbus`; port 27042 tertutup.
- Belum diverifikasi: build arm/x86/x86_64, Magisk/APatch, dan client Java bridge.
- Residual: embedded helper dex masih memuat string `frida-helper`; API `Frida` dan
  `re.frida.*` dipertahankan untuk kompatibilitas client.

