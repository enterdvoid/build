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
VENDORDOCS="https://github.com/armarchindo/build#readme"
VENDORURL="https://github.com/armarchindo/build"
VENDORSUPPORT="https://github.com/armarchindo/build/issues"
VENDORBUGS="https://github.com/armarchindo/build/issues"
VERSION=26.11.0
REVISION=26.11.0
VENDORPRETTYNAME='Armbian-DBAI-2K26'
```

File ini juga berisi metadata board, kernel, arsitektur, serta nilai `EXTENSIONS` yang dihasilkan framework. `BUILD_REPOSITORY_COMMIT` harus menunjukkan commit source yang benar-benar digunakan dalam build; nilainya tidak dipatok ke contoh commit lama.

**Catatan branding firmware:** `lib/functions/bsp/armbian-bsp-cli-deb.sh` menulis `BUILD_REPOSITORY_URL=https://github.com/armarchindo/build` ke `/etc/armbian-release`. Saat image dibuat, `lib/functions/rootfs/distro-agnostic.sh` menyalin berkas ini ke `/etc/armbian-image-release`, sehingga keduanya menampilkan URL brand yang sama. URL vendor/support/bugs dan URL pada `/etc/os-release` juga memakai `armarchindo`. Ini hanya mengganti referensi yang tertanam di firmware. Remote Git sumber, workflow GitHub Actions, riwayat run, dan GitHub Releases tetap berada di `enterdvoid/build`; `BUILD_REPOSITORY_COMMIT` tetap menunjukkan commit source yang benar-benar digunakan.

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
- **Pilihan aplikasi:** Home Assistant, OpenMediaVault, Kali, Docker CE, dan CasaOS. CasaOS tersedia pada Bookworm ARM64 dan installer resminya berjalan otomatis pada boot pertama.
- **CCTV:** LightNVR 0.43.2 + go2rtc terintegrasi; tersedia pada Trixie ARM64 dan container ditarik otomatis saat boot pertama. Jika Applications=all, CasaOS dan CCTV juga ikut dibuat untuk release yang didukung.
- **Pilihan desktop:** XFCE, MATE, GNOME, Cinnamon, KDE Plasma, LXQt, i3-wm, Enlightenment, Budgie, dan Openbox standalone sesuai dukungan yang tercantum di matriks.
- **Speedtest:** checkbox opsional dengan default tidak dicentang.
- **Proxmox VE Official:** opsional; memakai paket resmi Proxmox VE 9 dari repositori no-subscription pada Debian Trixie, sambil mempertahankan kernel/DTB Armbian. Ini bukan sertifikasi dukungan resmi Proxmox untuk STB Amlogic berbasis U-Boot/device tree.
- **Proxmox Community:** opsional; memakai PXVIRT 8 (penerus proyek Proxmox-Port) dari repositori komunitas pada Debian Bookworm. Kernel/DTB Armbian dipertahankan.
- Kedua pilihan Proxmox terpisah dan tidak dipengaruhi **OS group** umum: Official selalu memakai Trixie, Community selalu memakai Bookworm. Filesystem mengikuti pilihan run, dan image berukuran 12.288 MiB agar masuk akal untuk media nominal 16 GB.
- **Cleanup run history:** operasi penghapusan riwayat Actions yang terpisah dan memerlukan konfirmasi eksplisit `DELETE ALL RUN HISTORY`. Jangan mengaktifkannya bila yang diinginkan adalah build image.

Matriks menolak kombinasi duplikat dan menolak lebih dari batas 256 job GitHub Actions. Default saat semua grup profil dan semua filesystem dipilih menghasilkan **170 job** setelah varian CasaOS (Bookworm) dan LightNVR + go2rtc (Trixie) dimasukkan. Setiap pilihan Proxmox menambah satu job per filesystem yang dipilih (dua job bila filesystem=both). Jumlah job berubah sesuai input run.

Bullseye tetap tersedia untuk profil yang ditentukan dalam matriks. Desktop environment Armbian disaring berdasarkan dukungannya; Openbox standalone disediakan melalui ekstensi DBAI tersendiri.


### Varian CasaOS dan CCTV

Kedua varian tersedia sebagai checkbox tersendiri di **Run workflow**. Keduanya juga ikut dibuat ketika **Applications=all** dicentang, tetapi hanya untuk release yang cocok:

| Menu | OS basis | Cara pemasangan | Ukuran image mentah |
|---|---|---|---:|
| CasaOS | Debian Bookworm ARM64 | Service systemd menjalankan installer resmi CasaOS pada boot pertama | 16.384 MiB |
| LightNVR + go2rtc | Debian Trixie ARM64 | Docker Compose menarik container LightNVR 0.43.2 pada boot pertama | 16.384 MiB |

Contoh asset:

- aml-s9xx-box-ext4-bookworm-casaos.img.xz
- aml-s9xx-box-btrfs-bookworm-casaos.img.xz
- aml-s9xx-box-ext4-trixie-lightnvr-go2rtc.img.xz
- aml-s9xx-box-btrfs-trixie-lightnvr-go2rtc.img.xz

**Catatan CasaOS:** image membawa service instalasi, bukan semua paket CasaOS yang sudah diunduh saat build. Firmware harus tersambung ke internet ketika boot pertama. Prosesnya dicatat di /var/log/dbai-casaos-install.log; status unit ada di dbai-casaos-firstboot.service. Image memakai target 16 GiB karena CasaOS sendiri membutuhkan ruang untuk aplikasi/container dan data.

**Catatan LightNVR:** firmware memasang Docker CE dan menaruh Compose stack di /opt/dbai-cctv. Pada boot pertama systemd menarik image resmi ghcr.io/opensensor/lightnvr:0.43.2. LightNVR membawa/mengelola go2rtc sendiri—tidak ada go2rtc kedua yang memakai port sama. UI LightNVR: http://IP-STB:8080; API go2rtc: http://IP-STB:1984; RTSP: port 8554; WebRTC: port 8555/TCP dan 8555/UDP. Kredensial awal LightNVR adalah admin/admin; segera ganti saat login pertama. Log layanan tersedia lewat journalctl -u dbai-lightnvr.service, dan log container lewat docker logs lightnvr.

Sebaiknya arahkan rekaman CCTV ke USB HDD/SSD eksternal sebelum menambah banyak kamera; image 16 GiB hanya menyediakan ruang awal untuk OS, konfigurasi, container dan pengujian, bukan kapasitas arsip CCTV jangka panjang. Variasi jumlah kamera, resolusi, codec, dan bitrate akan memengaruhi pemakaian RAM, CPU, jaringan dan disk.

## 3. Speedtest VM (opsional)

Input workflow bernama `speedtest`:

- Jika dicentang, langkah **Ookla Speedtest (optional)** berjalan tepat setelah **Show runner specs and selected build configuration**.
- Jika tidak dicentang (default), GitHub Actions melewati langkah Speedtest.
- Pengujian dijalankan pada setiap job build matrix yang berjalan, bukan satu kali untuk seluruh run. Jika banyak job dipilih, mengaktifkannya berarti setiap VM/job akan menjalankan Speedtest.
- Menggunakan Ookla Speedtest CLI dari repository paket Linux Ookla.
- Log sebelumnya memperlihatkan installer Packagecloud mendeteksi `Ubuntu/noble`, lalu APT meminta indeks `noble Release` yang mengembalikan HTTP 404. Jadi error berasal dari metadata repository APT, sebelum paket Speedtest diunduh.
- Workflow kini **tidak menambahkan repository APT Ookla**. Ia mengunduh file `.deb` resmi langsung dari Packagecloud berdasarkan arsitektur yang dilaporkan `dpkg --print-architecture`, lalu memverifikasi SHA-256 sebelum instalasi. URL menggunakan listing paket Debian Bookworm karena Packagecloud menyediakan file tersebut untuk arsitektur yang didukung; paket mencantumkan `ca-certificates` sebagai dependensi. Halaman repositori menampilkan paket Debian dan Ubuntu menurut label distribusinya, sementara nama file `.deb` mengidentifikasi arsitektur. Rujukan: [daftar paket Ookla](https://packagecloud.io/ookla/speedtest-cli), [paket amd64 Bookworm](https://packagecloud.io/ookla/speedtest-cli/packages/debian/bookworm/speedtest_1.2.0.84-1.ea6b6773cf_amd64.deb), dan [paket arm64 Bookworm](https://packagecloud.io/ookla/speedtest-cli/packages/debian/bookworm/speedtest_1.2.0.84-1.ea6b6773cf_arm64.deb).
- Versi paket dipatok ke `1.2.0.84-1.ea6b6773cf` dan SHA-256 yang diterbitkan Packagecloud diverifikasi per arsitektur: `amd64`, `arm64`, `armhf`, dan `i386`. Arsitektur lain dilewati dengan pesan yang jelas.
- Setelah verifikasi, workflow memasang file lokal dengan `apt-get install /path/to/package.deb`; dependensi diambil dari repository Ubuntu runner yang sudah dikonfigurasi.
- Mencatat ISP, server, latency, download, upload, dan URL hasil bila tersedia. Hasil dimasukkan ke ringkasan job dan artefak log job.
- Download, verifikasi checksum, instalasi, atau tes jaringan yang gagal bersifat **non-fatal**: dicatat, lalu proses build image tetap berlanjut.
- Tes jaringan dibatasi 120 detik, sementara seluruh langkah Speedtest memiliki timeout 10 menit.
- **Catatan validasi:** URL package dan checksum berasal dari halaman paket resmi Packagecloud; perubahan workflow sudah diperbarui secara statis, tetapi belum ada bukti run Actions baru yang sukses menjalankan download, validasi checksum, instalasi, dan pengukuran jaringan.

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

### Varian Proxmox

Dua checkbox tersedia di **Actions → DBAI Armbian Build → Run workflow**:

| Menu | Basis | Paket | Ukuran image |
|---|---|---|---:|
| Proxmox VE Official | Debian Trixie | Paket resmi PVE 9 dari `download.proxmox.com`, kernel Armbian dipertahankan | 12.288 MiB |
| Proxmox Community | Debian Bookworm | PXVIRT 8 dari repositori komunitas, kernel Armbian dipertahankan | 12.288 MiB |

Contoh nama output:

- `aml-s9xx-box-ext4-trixie-proxmox-official.img.xz`
- `aml-s9xx-box-btrfs-trixie-proxmox-official.img.xz`
- `aml-s9xx-box-ext4-bookworm-proxmox-community.img.xz`
- `aml-s9xx-box-btrfs-bookworm-proxmox-community.img.xz`

Repositori Official menggunakan keyring resmi Trixie dan komponen `pve-no-subscription`. Repositori Community memakai key `pveport.gpg` dari dokumentasi PXVIRT dan komponen `bookworm main`. Keduanya sengaja tidak memasang meta-package/kernel Proxmox; ini menjaga kernel dan DTB yang membuat STB bisa boot. Karena itu kernel updates serta dukungan modul kernel akan tetap mengikuti Armbian. Fitur ZFS/DKMS tidak dipasang otomatis; konfigurasi bridge jaringan dan storage guest dilakukan setelah boot.

Sebuah systemd one-shot mengatur pemetaan hostname ke alamat IPv4 LAN saat boot pertama sebelum layanan utama Proxmox/PXVIRT berjalan. Ini membantu layanan web dan cluster menemukan alamat host, tetapi pengguna tetap harus memastikan DHCP/static IP dan hostname sesuai jaringan.

**Batas kompatibilitas:** “Official” merujuk sumber paket resmi PVE 9, bukan berarti platform Amlogic STB disertifikasi upstream. Dokumentasi Proxmox saat ini mensyaratkan platform ARM64 yang boot melalui UEFI dan menjelaskan hardware berbasis device tree saja sebagai tidak didukung secara resmi. Maka image Official di sini adalah jalur eksperimen memakai paket resmi pada kernel Armbian. PXVIRT 8 adalah port/fork komunitas untuk ARM64 dan mempublikasikan panduan pemasangan di Armbian Bookworm; kompatibilitas tiap model STB tetap perlu diuji. Referensi: [Proxmox pada Armbian](https://docs.armbian.com/software/proxmox-ve/), [PXVIRT: install dari Debian/Armbian](https://docs.pxvirt.lierfang.com/en/installfromdebian), [PXVIRT repository documentation](https://docs.pxvirt.lierfang.com/en/repo).

**Status validasi:** integrasi ini statis dan belum diuji pada workflow runtime. Run pertama sebaiknya memilih satu checkbox, satu filesystem, dan hanya satu varian Proxmox; setelah image selesai, uji web UI di `https://IP-STB:8006`, LXC, dan `/dev/kvm` bila tersedia.

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


## 8. Proxmox Community, status MOTD, dan kernel freeze

Temuan saat pengujian image Proxmox Community (PXVIRT 8) pada Debian Bookworm:

- **Label `Debian rolling (bookworm)`:** skrip `10-armbian-header` membaca status codename dari `/etc/armbian-distribution-status` dan memakai label `rolling` sebagai fallback ketika status tidak dikenali. Label MOTD itu sendiri bukan bukti bahwa APT benar-benar memakai suite `sid`/unstable. Periksa `/etc/os-release`, file source APT, dan `apt-cache policy`. Fallback DBAI hanya mengubah tampilan: Bookworm/Trixie serta Ubuntu Jammy/Noble/Resolute ditampilkan sebagai `stable`; Bullseye ditampilkan sebagai `LTS` apabila metadata Armbian tidak dikenal; Forky tetap `rolling` karena merupakan Debian testing. Jika metadata Armbian secara eksplisit menyatakan `supported` atau `eos`, metadata itu tetap didahulukan. Lihat [panduan Proxmox Community](PANDUAN-PROXMOX-COMMUNITY.md) untuk detail dan referensi upstream.
- **Kernel upgrade:** image lama bisa menunjukkan `Kernel upgrade enabled` karena paket kernel Armbian belum di-hold. Build lokal dan GitHub Actions kini memakai `BSPFREEZE=yes` untuk menahan upgrade paket kernel/DTB/U-Boot/board-support Armbian secara default; paket OS biasa tetap dapat diperbarui. Pada image yang sudah berjalan gunakan `sudo armbian-config --cmd UPD002`; untuk mengaktifkan kembali gunakan `sudo armbian-config --cmd UPD001`. Periksa `apt-mark showhold`.
- **First-login memilih akun `ceph`:** skrip Armbian sebelumnya memilih akun pertama ber-UID >=1000, meskipun akun tersebut adalah akun service paket. Di lingkungan PXVIRT hal ini dapat membuat akun service salah dipakai sebagai user harian dan diberi grup sudo. Sumber `armbian-firstlogin` sekarang membatasi reuse hanya untuk akun dengan home `/home/<user>` dan shell interaktif, serta memeriksa hasil `passwd` saat mengatur password root dan user biasa. Jika password ditolak oleh PAM, pesan kesalahan ditampilkan dan setup tidak melanjutkan diam-diam dengan password yang belum terverifikasi. Jangan menghapus user service `ceph`; pada image yang sudah terdampak, cabut grup tambahan yang diberikan first-login (`sudo`, `disk`, `docker`, dan daftar grup onboarding), kunci password akun itu, lalu buat pengguna administrator tersendiri jika diperlukan. Ikuti langkah terperinci di [Panduan Proxmox Community](PANDUAN-PROXMOX-COMMUNITY.md).
- **Akses UI Proxmox Community:** gunakan `https://IP-STB:8006`, login dengan `root@pam` dan password root first-boot. Port 8006 harus listen dan `pveproxy`, `pvedaemon`, `pve-cluster`, serta `pvestatd` perlu diperiksa ketika UI tidak dapat dibuka. Guest network bridge dan akselerasi `/dev/kvm` perlu diuji terpisah pada STB Amlogic; paket userspace yang terpasang tidak menjamin semua fitur hardware.
- **Dokumentasi penggunaan:** [Panduan Proxmox Community](PANDUAN-PROXMOX-COMMUNITY.md) memuat command, keamanan akun `ceph`, akses Web UI, diagnosis service, kernel freeze, serta batas kompatibilitas.

**Status validasi:** perubahan source/workflow sudah dimasukkan dan memiliki regression checks dalam workflow `DBAI Firmware Validation`. Image Proxmox Community baru tetap perlu dibangun ulang dan diuji di perangkat nyata untuk memastikan hasil onboarding, akses UI, dan status update sesuai harapan.
