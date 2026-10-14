# DBAI Armbian Build — Dokumentasi Implementasi

Dokumen ini merangkum konfigurasi khusus DBAI yang saat ini tersimpan di branch `main`, cara kerja workflow GitHub Actions, penamaan output, fitur yang diterapkan, dan status validasinya.

> **Status validasi:** perubahan sumber dan konfigurasi sudah di-commit ke repository. Belum ada build penuh setelah perubahan branding versi dan fitur Speedtest ini, sehingga hasil image aktual dan keberhasilan Speedtest masih perlu dikonfirmasi oleh run berikutnya. Jangan menganggap status build runtime sudah lulus hanya dari dokumentasi ini.

## 1. Identitas dan versi DBAI

Versi image disetel stabil ke `26.11.0`. Build tidak lagi memakai nilai bertanggal seperti `2026.10.14.26` ataupun suffix `-trunk`.

Konfigurasi default berada di `userpatches/config-default.conf`:

- `REVISION="26.11.0"`
- `IMAGE_VERSION="26.11.0"`
- `VENDOR="DBAI"`
- `VENDORPRETTYNAME="Armbian-DBAI-2K26"`
- `ENABLE_EXTENSIONS="dbai-branding"`

Workflow mengirim nilai versi dan vendor yang sama secara eksplisit ke `compile.sh`, agar nilai default konfigurasi tidak mengubahnya.

### Isi yang diharapkan di `/etc/armbian-image-release`

Field utama yang diharapkan:

```ini
VENDOR="DBAI"
VENDORCOLOR="39;174;96"
VENDORDOCS="https://github.com/enterdvoid/build#readme"
VENDORURL="https://github.com/enterdvoid/build"
VENDORSUPPORT="https://github.com/enterdvoid/build/issues"
VENDORBUGS="https://github.com/enterdvoid/build/issues"
VERSION=26.11.0
REVISION=26.11.0
VENDORPRETTYNAME='Armbian-DBAI-2K26'
```

File ini juga berisi metadata board, kernel, arsitektur, serta nilai `EXTENSIONS` yang dihasilkan framework. `BUILD_REPOSITORY_COMMIT` harus menunjukkan commit source yang benar-benar digunakan dalam build; nilainya tidak dipatok ke contoh commit lama.

### Isi yang diharapkan di `/etc/armbian-release`

Field utamanya sama untuk board, vendor, URL, versi dan revisi. Framework tidak menambahkan `VENDORPRETTYNAME` atau `EXTENSIONS` ke file ini karena keduanya adalah metadata image build.

### Isi yang diharapkan di `/etc/os-release`

Untuk Bullseye, nama tampilan yang diharapkan:

```ini
PRETTY_NAME="DBAI-2K26 bullseye"
NAME="Debian GNU/Linux"
VERSION_ID="11"
VERSION="11 (bullseye)"
VERSION_CODENAME=bullseye
ID=debian
HOME_URL="https://www.armbian.com/"
SUPPORT_URL="https://forum.armbian.com"
BUG_REPORT_URL="https://www.armbian.com/bugs"
ARMBIAN_PRETTY_NAME="DBAI-2K26 bullseye"
```

Ekstensi `userpatches/extensions/dbai-branding.sh` menggunakan hook `post_family_tweaks` setelah paket terpasang di root filesystem. Hook mengganti hanya `PRETTY_NAME` dan `ARMBIAN_PRETTY_NAME` menjadi `DBAI-2K26 <release-codename>`. Field identitas dan versi Debian serta URL yang sudah ada tidak diubah. Misalnya untuk Trixie, nama tampilannya menjadi `DBAI-2K26 trixie`.

Nama tampilan OS sengaja tidak memasukkan versi build. Versi tetap tersedia pada metadata Armbian dan detail rilis GitHub. Branding di atas merupakan target yang diimplementasikan; konfirmasi hasil akhirnya tetap memerlukan pemeriksaan image dari build berikutnya.

## 2. Cara menjalankan workflow

Workflow berada di [`.github/workflows/armbian-build.yml`](../.github/workflows/armbian-build.yml) dan dijalankan melalui **Actions → DBAI Armbian Build → Run workflow**.

Input utama:

- **Filesystem:** `both`, `ext4`, atau `btrfs`.
- **OS group:** semua release, keluarga Debian/Ubuntu, atau release spesifik.
- **Server / Minimal / Applications / Desktop:** pilih profil yang akan dibuat.
- **Pilihan aplikasi:** Home Assistant, OpenMediaVault, Kali, dan Docker CE; matriks membatasi setiap aplikasi pada release yang dikonfigurasi kompatibel.
- **Pilihan desktop:** XFCE, MATE, GNOME, Cinnamon, KDE Plasma, LXQt, i3-wm, Enlightenment, Budgie, dan Openbox standalone sesuai dukungan yang tercantum di matriks.
- **Speedtest:** checkbox opsional dengan default tidak dicentang.
- **Cleanup run history:** operasi penghapusan riwayat Actions yang terpisah dan memerlukan konfirmasi eksplisit `DELETE ALL RUN HISTORY`. Jangan mengaktifkannya bila yang diinginkan adalah build image.

Matriks menolak kombinasi duplikat dan menolak lebih dari batas 256 job GitHub Actions. Default saat semua grup profil dan semua filesystem dipilih menghasilkan 166 job, sesuai pemeriksaan konsistensi yang ditanam dalam workflow. Jumlah job dapat berbeda bila input run diubah.

Bullseye tetap tersedia untuk profil yang ditentukan dalam matriks. Desktop environment Armbian disaring berdasarkan dukungannya; Openbox standalone disediakan melalui ekstensi DBAI tersendiri.

## 3. Speedtest VM (opsional)

Input workflow bernama `speedtest`:

- Jika dicentang, langkah **Ookla Speedtest (optional)** berjalan tepat setelah **Show runner specs and selected build configuration**.
- Jika tidak dicentang (default), GitHub Actions melewati langkah Speedtest.
- Pengujian dijalankan pada setiap job build matrix yang berjalan, bukan satu kali untuk seluruh run. Jika banyak job dipilih, mengaktifkannya berarti setiap VM/job akan menjalankan Speedtest.
- Menggunakan Ookla Speedtest CLI dari repository paket Linux Ookla.
- Mencatat ISP, server, latency, download, upload, dan URL hasil bila tersedia. Hasil dimasukkan ke ringkasan job dan artefak log job.
- Setup atau tes jaringan yang gagal bersifat **non-fatal**: dicatat, lalu proses build image tetap berlanjut.
- Tes dibatasi dengan timeout 120 detik, sementara langkah instalasi memiliki timeout 10 menit.

Speedtest opsional bisa menambah waktu job dan penggunaan jaringan. Pengujian berulang secara paralel dapat memengaruhi hasil throughput, jadi hasil antar-job bukan pengukuran laboratorium yang benar-benar terisolasi.

## 4. Urutan build dan keluaran

Setiap job build menjalankan langkah utama berikut:

1. Diagnostik runner awal: OS, kernel, CPU, RAM, swap, filesystem, dan storage.
2. Memperbesar ruang build runner dan memindahkan Docker data root ke volume workspace yang lebih besar.
3. Laporan spesifikasi VM dan konfigurasi profil.
4. Speedtest opsional.
5. Pemeriksaan konfigurasi board serta ekstensi.
6. Pengecekan dukungan Btrfs bila filesystem yang dipilih adalah Btrfs.
7. Menyiapkan emulasi ARM64 melalui QEMU dan menguji eksekusi container ARM64.
8. Menjalankan `compile.sh` dengan board `aml-s9xx-box`, branch kernel `current`, filesystem yang dipilih, ukuran image dari matriks, versi `26.11.0`, dan identitas DBAI.
9. Mengganti nama hasil image, membuat checksum, dan mengunggahnya ke GitHub Release.
10. Menghapus image lokal setelah upload berhasil dan mengunggah log runner/build sebagai artefak.
11. Job finalisasi menggabungkan checksum menjadi `SHA256SUMS.txt`.

Batas paralelisme build adalah empat job. Workflow juga memiliki timeout pada langkah diagnostik/setup dan job build untuk mencegah job menggantung tanpa batas.

### Nama asset

Pola asset rilis:

```text
aml-s9xx-box-{filesystem}-{os-release}-{variant}.img.xz
```

Jika hasil tidak dikompresi, ekstensi akhirnya `.img`. Contoh untuk Bullseye:

- `aml-s9xx-box-ext4-bullseye-server.img.xz`
- `aml-s9xx-box-btrfs-bullseye-server.img.xz`
- `aml-s9xx-box-ext4-bullseye-minimal.img.xz`
- `aml-s9xx-box-btrfs-bullseye-minimal.img.xz`

Nama asset memang tidak menyertakan versi; metadata versi di dalam image adalah `26.11.0`. Judul GitHub Release tetap mencerminkan profil terpilih serta waktu mulai build dalam zona waktu Asia/Jakarta. Tag release dibuat per workflow run.

File checksum per image digunakan saat upload. Pada akhir run, job finalisasi menyusun `SHA256SUMS.txt`; sidecar checksum individual dihapus setelah checksum gabungan berhasil diunggah. Image lokal di runner dihapus setelah upload berhasil, sedangkan asset pada GitHub Release tetap ada.

## 5. Penyesuaian khusus yang sudah ada di repository

Selain perubahan versi dan Speedtest, konfigurasi workflow sudah meliputi:

- Matriks profil Server, Minimal, Applications, dan Desktop/WM; OS Debian/Ubuntu serta filesystem ext4/Btrfs.
- Dukungan aplikasi dibatasi per release melalui matriks kompatibilitas.
- Openbox standalone sebagai varian desktop tersendiri, dengan LightDM, LXPanel, PCManFM, terminal, dan NetworkManager tray; sesi LightDM diarahkan ke Openbox.
- Preflight untuk file board dan ekstensi yang diperlukan.
- Laporan spesifikasi runner dan storage sebelum serta setelah build.
- Docker dipindahkan ke data root di volume workspace, bukan dibiarkan memakai storage root yang terbatas.
- QEMU/binfmt untuk menjalankan container ARM64 di runner x86_64.
- Maksimal empat job paralel dan antrean yang menginterleave filesystem/profil.
- Ringkasan matriks OS/profile di Actions Summary.
- Penggabungan SHA256 terpusat dan pembersihan asset checksum individual setelah upload berhasil.
- Fix lingkungan non-interaktif dengan menetapkan `COLUMNS=80` dan `LINES=24` untuk menghindari error `/bin/mksh: COLUMNS: bad number` pada pre-install `rng-tools` yang sebelumnya menggagalkan build Server Bullseye pada ext4 maupun Btrfs. Penyebabnya variabel terminal kosong, bukan filesystem; profil Minimal sebelumnya tidak memicu paket yang sama.
- Workflow history cleanup tersedia sebagai operasi khusus dengan konfirmasi terpisah, bukan bagian dari build biasa.

## 6. Riwayat perubahan yang relevan

Daftar berikut adalah ringkasan tahapan implementasi yang sudah dikomit di branch `main`:

- Perbaikan awal workflow serta finalisasi checksum yang aman.
- Penghapusan subtitle/manifest release yang berulang atau tidak diperlukan.
- Perbaikan timestamp judul dan diagnostik runner, timeout, serta laporan disk/memori.
- Batas paralelisme empat job dan pengaturan antrean matriks.
- Ekstensi desktop Openbox, integrasi matriks, serta pengaturan sesi LightDM.
- Fix `COLUMNS` kosong yang menyebabkan paket `rng-tools` gagal dipasang pada Server Bullseye.
- Konfigurasi default DBAI untuk vendor dan versi image.
- Branding workflow DBAI dan injeksi metadata build.
- Hook `dbai-branding` untuk nama tampilan `/etc/os-release`.
- Versi stabil `26.11.0` dan checkbox Speedtest VM opsional.

## 7. Status dan cara verifikasi setelah perubahan

Yang sudah dilakukan: file konfigurasi dan workflow diperbarui, ekstensi branding ditambahkan, dokumentasi ini dibuat, dan perubahan disimpan sebagai commit di `main`.

Yang belum dikonfirmasi oleh build baru:

- Apakah Armbian menghasilkan `VERSION=26.11.0` dan `REVISION=26.11.0` pada image output.
- Apakah kedua field `PRETTY_NAME` berhasil menjadi `DBAI-2K26 <codename>` pada root filesystem akhir.
- Apakah pemasangan Ookla CLI, tes jaringan, dan format hasil berjalan pada runner GitHub Actions.
- Apakah seluruh variasi filesystem/profil selesai tanpa regresi.

Pemeriksaan statis terhadap sumber dapat memastikan konfigurasi telah ditanam, tetapi tidak dapat menggantikan pengujian build aktual. Setelah run berikutnya, cek file `/etc/armbian-image-release`, `/etc/armbian-release`, dan `/etc/os-release` dari hasil image untuk memverifikasi nilai akhirnya.
