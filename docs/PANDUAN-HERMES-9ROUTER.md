# Panduan Penggunaan Hermes Agent dan 9Router pada Firmware DBAI Armbian

Dokumen ini adalah panduan operasional untuk tiga image aplikasi AI yang tersedia pada workflow **DBAI Armbian Build**: Hermes Agent, 9Router, dan image gabungan Hermes + 9Router.

> **Penting tentang cara instalasi:** software AI dipasang otomatis pada **boot pertama**, bukan seluruhnya ditanam lengkap saat image dikompilasi. Boot pertama memerlukan koneksi internet. Tunggu proses selesai sebelum menjalankan perintah konfigurasi.

## 1. Pilih image yang sesuai

Pada GitHub, buka **Actions → DBAI Armbian Build → Run workflow**. Di input **Applications preset**, pilih salah satu opsi berikut.

| Preset | Image AI yang dibuat | Kegunaan |
|---|---|---|
| `hermes` | `hermes-agent` | Hermes Agent saja; aplikasi AI berupa CLI/terminal |
| `9router` | `9router` | Dashboard web 9Router dan API OpenAI-compatible |
| `both` | `hermes-9router` | 9Router sebagai gateway/provider endpoint, Hermes sebagai agent yang menggunakannya |
| `ai-all` | Ketiga varian di atas | Membuat semua varian AI, serta aplikasi standar lain jika checkbox aplikasinya dipilih |
| `all` | Semua varian AI dan semua aplikasi standar yang kompatibel | Build lengkap; menghasilkan jauh lebih banyak image |

Nama preset di menu menyertakan keterangan berbahasa Indonesia. Pilihan **Server**, **Minimal**, **Desktop**, OS, dan filesystem adalah pilihan terpisah. Jika ingin menguji ketiga image AI saja, pilih `ai-all`, matikan checkbox Server dan Minimal, biarkan aplikasi standar tidak dicentang, atur Desktop ke `none`, lalu pilih satu OS dan satu filesystem untuk uji awal.

Image AI mensyaratkan arsitektur ARM64 dan saat ini dijadwalkan untuk Debian Bookworm/Trixie atau Ubuntu Jammy/Noble/Resolute. Nama asset berakhir dengan `-hermes-agent`, `-9router`, atau `-hermes-9router`.

## 2. Boot pertama dan persiapan

1. Burn image ke media penyimpanan, pasang pada perangkat Amlogic yang sesuai, lalu boot.
2. Selesaikan login awal Armbian dan konfigurasi jaringan sesuai prompt sistem.
3. Sambungkan perangkat ke internet. Service first-boot perlu mengunduh paket Linux, installer Hermes (jika dipilih), dan/atau image container 9Router.
4. Biarkan service bekerja. Pada instalasi pertama, proses dapat memerlukan waktu karena harus mengunduh paket dan container.
5. Setelah perangkat dapat diakses lewat SSH atau terminal, periksa status:

   ```bash
   sudo dbai-ai-setup
   sudo systemctl status dbai-ai-stack-firstboot.service
   ```

Service membuat marker selesai hanya ketika proses provisioning berhasil. Jika instalasi gagal, systemd dikonfigurasi untuk mencoba ulang; lihat bagian diagnostik sebelum mengulang operasi manual.

File log instalasi:
- `/var/log/dbai-ai-stack-install.log`
- `sudo journalctl -u dbai-ai-stack-firstboot.service -n 100 --no-pager`

Jangan menghapus file status atau menghapus direktori data untuk sekadar mengatasi masalah koneksi. Periksa log terlebih dahulu.

## 3. Menggunakan Hermes Agent (image Hermes saja atau image gabungan)

Hermes dipasang sebagai software native pada host Armbian, bukan sebagai Docker container. Instalasi berjalan sebagai akun Linux khusus `dbai-hermes`; perintah `hermes` disediakan sebagai wrapper agar proses tidak dijalankan sebagai root.

### Konfigurasi pertama

Jalankan sebagai user biasa:

```bash
hermes
```

Pada pemakaian pertama, wrapper membuka pemilih provider/model Hermes. Ikuti prompt, pilih provider dan model yang tersedia, kemudian selesaikan autentikasi sesuai instruksi provider. Setelah pemilihan berhasil, wrapper melanjutkan ke chat.

Untuk membuka pengaturan provider/model lagi:

```bash
hermes model
```

Setelah setup, mulai chat menggunakan:

```bash
hermes
```

Perintah Hermes lain diteruskan ke CLI upstream. Untuk daftar command dan kemampuan yang tersedia pada versi terpasang, gunakan dokumentasi resmi Hermes Agent: https://hermes-agent.nousresearch.com/docs.

### Lokasi instalasi dan konfigurasi

- Binary: `/var/lib/dbai-hermes/.local/bin/hermes`
- Home akun service: `/var/lib/dbai-hermes`
- Konfigurasi dan data Hermes: `/var/lib/dbai-hermes/.hermes`
- Wrapper yang dipanggil pengguna: `/usr/local/bin/hermes`
- Penanda setup provider/model selesai: `/var/lib/dbai-hermes/.dbai-model-configured`

Jangan memindahkan atau mengubah kepemilikan direktori `/var/lib/dbai-hermes` secara sembarang; wrapper menjalankan agent menggunakan akun khusus tersebut.

### Pemeriksaan Hermes

```bash
sudo systemctl status dbai-ai-stack-firstboot.service
sudo journalctl -u dbai-ai-stack-firstboot.service -n 100 --no-pager
sudo tail -n 100 /var/log/dbai-ai-stack-install.log
ls -la /var/lib/dbai-hermes/.hermes
```

Saat boot pertama, installer resmi dipanggil dengan opsi `--non-interactive --skip-browser`, sehingga varian ini adalah instalasi CLI/headless, bukan aplikasi desktop grafis.

## 4. Menggunakan 9Router

9Router berjalan di dalam **Docker container** bernama `dbai-9router`. Container dimulai otomatis oleh Docker Compose dan diatur restart kecuali dihentikan secara eksplisit.

### Buka dashboard

Jalankan:

```bash
sudo dbai-ai-setup
```

Pada image 9Router, perintah tersebut menampilkan alamat dashboard, alamat API, dan password awal acak (selama password tersebut belum diganti). Dari browser komputer yang berada di jaringan LAN yang sama, buka:

```text
http://IP-STB:20128/dashboard
```

Ganti `IP-STB` dengan alamat IP perangkat yang ditampilkan oleh `dbai-ai-setup`. Login dengan password awal yang ditampilkan, lalu segera ganti password tersebut. **Catatan implementasi:** helper saat ini membaca kembali nilai `INITIAL_PASSWORD` dari file konfigurasi dan dapat menampilkannya lagi setiap kali dipanggil. Setelah password dashboard diubah, nilai yang tercetak itu adalah password awal yang sudah kedaluwarsa, bukan password login aktif. Jangan gunakan nilai itu untuk mencoba mengambil alih dashboard; simpan file `/etc/dbai/9router.env` tetap terbatas pada root.

### Hubungkan provider

Di dashboard 9Router, ikuti UI upstream untuk menambahkan/mengautentikasi provider yang ingin dipakai, lalu pastikan tersedia model yang bisa digunakan. Letak menu dapat berubah menurut versi 9Router.

Endpoint API OpenAI-compatible adalah:

```text
http://IP-STB:20128/v1
```

Aplikasi/API client dapat menggunakan endpoint tersebut dengan API key yang dibuat di **Settings → API Keys**. Endpoint API dan dashboard bukan hal yang sama: dashboard digunakan untuk mengelola 9Router dan provider, sedangkan endpoint `/v1` dipakai oleh aplikasi klien.

### Keamanan API wajib diverifikasi

Firmware menulis `REQUIRE_API_KEY=true`, tetapi beberapa versi upstream mungkin tidak menerapkannya pada endpoint API. Karena itu, firmware memeriksa respons `/v1/models` tanpa bearer token.

Jalankan:

```bash
sudo dbai-ai-setup
```

Hasil yang diharapkan untuk permintaan tanpa token adalah HTTP **401** atau **403**. Jika status menunjukkan HTTP **200**, buka dashboard **Endpoint** (atau pengaturan API key yang sesuai pada versi terpasang), aktifkan persyaratan API key, lalu jalankan kembali `sudo dbai-ai-setup` untuk mengulang verifikasi.

**Jangan meneruskan port 20128 langsung ke internet.** Dashboard bawaan menggunakan HTTP dan tidak menyediakan TLS sendiri; gunakan hanya pada LAN tepercaya atau akses jarak jauh melalui VPN / reverse proxy HTTPS yang memiliki autentikasi dan TLS yang benar.

### Lokasi container, konfigurasi dan data

- Docker Compose: `/opt/dbai-ai-stack/compose.yaml`
- Environment/secrets: `/etc/dbai/9router.env` (dimiliki root, permission `0600`)
- Data aplikasi: Docker named volume `dbai_9router_data`
- Port host: `20128`
- Container: `dbai-9router`

Jangan membagikan isi `/etc/dbai/9router.env`: file tersebut berisi password awal serta secret autentikasi. Jangan memakai `docker compose down -v` untuk restart biasa—opsi `-v` dapat menghapus volume data persisten.

### Periksa status 9Router

```bash
sudo docker compose -f /opt/dbai-ai-stack/compose.yaml ps
sudo docker logs --tail 100 dbai-9router
sudo systemctl status docker.service
```

Untuk melihat penggunaan resource, gunakan `docker stats dbai-9router`.

## 5. Varian gabungan: Hermes menggunakan 9Router

Pada image `hermes-9router`, Hermes tetap terpasang native pada host dan 9Router tetap berjalan di Docker. Setelah first-boot selesai, lakukan langkah-langkah ini:

1. Jalankan `sudo dbai-ai-setup`, buka dashboard 9Router, ganti password awal, dan hubungkan provider.
2. Di **Settings → API Keys**, buat API key 9Router.
3. Jalankan:

   ```bash
   sudo dbai-ai-setup --connect-hermes
   ```

4. Ketika diminta, tempelkan API key. Input dibaca secara tersembunyi; jangan mengetikkannya sebagai argumen command.
5. Helper memeriksa key ke endpoint `/v1/models`, menampilkan model ID yang dikembalikan 9Router, lalu meminta ID model yang akan digunakan. Masukkan ID yang persis sama dengan salah satu ID dari daftar.
6. Setelah konfigurasi selesai, mulai Hermes:

   ```bash
   hermes
   ```

Helper menyimpan endpoint provider sebagai `http://127.0.0.1:20128/v1`; koneksi ini tetap berada di perangkat, tidak perlu melewati LAN. API key ditaruh pada file environment pribadi Hermes dengan permission `0600`, bukan ditulis sebagai argumen proses.

Jika mengganti API key di kemudian hari, buat key baru di 9Router lalu jalankan lagi `sudo dbai-ai-setup --connect-hermes`.

## 6. Pembaruan

### Memperbarui 9Router

Firmware menyediakan helper untuk menarik image 9Router terbaru dan membuat ulang container:

```bash
sudo dbai-ai-setup --update-router
```

Jalankan pada image `9router` atau `hermes-9router`. Perintah ini menarik tag upstream `ghcr.io/decolua/9router:latest`; perilaku dan perubahan versi mengikuti rilis upstream. Setelah pembaruan, buka dashboard dan uji kembali provider, endpoint, serta autentikasi API. Docker named volume digunakan untuk menyimpan data aplikasi.

### Memperbarui Hermes

Versi firmware saat ini **belum menyediakan shortcut pembaruan Hermes tersendiri**. Jangan berasumsi bahwa perintah update 9Router juga memperbarui Hermes. Ikuti dokumentasi resmi/upstream Hermes untuk prosedur versi yang terpasang dan buat cadangan konfigurasi sebelum melakukan perubahan manual: https://hermes-agent.nousresearch.com/docs.

## 7. Diagnostik dan pemulihan

### Provisioning belum selesai

```bash
sudo systemctl status dbai-ai-stack-firstboot.service
sudo journalctl -u dbai-ai-stack-firstboot.service -n 200 --no-pager
sudo tail -n 200 /var/log/dbai-ai-stack-install.log
```

Pastikan perangkat mendapat internet dan DNS berfungsi. Proses memerlukan akses ke repositori paket OS, server installer resmi Hermes (untuk image yang menyertakan Hermes), serta GitHub Container Registry (untuk 9Router). Perbaiki penyebab koneksi atau repository terlebih dahulu; systemd akan mencoba lagi setelah kegagalan.

Untuk memicu upaya service lagi setelah memperbaiki koneksi:

```bash
sudo systemctl restart dbai-ai-stack-firstboot.service
```

Perintah di atas menjalankan ulang provisioning jika marker sukses belum dibuat. Jangan jalankan pengulangan tanpa melihat log ketika penyebab kegagalan belum diketahui.

### 9Router dashboard tidak bisa dibuka

1. Jalankan `sudo dbai-ai-setup` untuk melihat IP dan status keamanan.
2. Periksa `sudo systemctl status docker.service`.
3. Periksa `sudo docker compose -f /opt/dbai-ai-stack/compose.yaml ps`.
4. Lihat `sudo docker logs --tail 100 dbai-9router`.
5. Pastikan perangkat klien dan STB berada pada jaringan yang bisa saling menjangkau, dan firewall tidak memblokir TCP port 20128.

### Hermes belum mengenali provider atau model

Jalankan `hermes model` untuk membuka pemilih provider/model. Untuk varian gabungan, pastikan 9Router hidup, API key aktif, dan model yang dipilih adalah ID yang benar-benar dikembalikan endpoint 9Router. Ulangi `sudo dbai-ai-setup --connect-hermes` jika key berubah atau provider khusus perlu dikonfigurasi ulang.

### Perintah tidak ditemukan

Jika `hermes` atau `dbai-ai-setup` belum tersedia, first-boot kemungkinan belum selesai atau gagal. Periksa service dan log terlebih dahulu; jangan langsung memasang salinan kedua menggunakan installer lain karena dapat membuat konfigurasi serta permission bertabrakan.

## 8. Catatan penting

- Firmware tidak menyematkan kredensial provider pribadi ke dalam image. Pengguna mengonfigurasinya setelah boot pertama.
- First-boot memerlukan internet dan bisa memakan waktu cukup lama; kegagalan download bukan bukti bahwa image rusak.
- Hermes bersifat native/host OS, tetapi instalasinya dilakukan saat boot pertama. 9Router dijalankan sebagai container Docker.
- Dashboard 9Router tersedia melalui HTTP di LAN, jadi gunakan jaringan tepercaya. Jangan membuka port 20128 langsung ke internet.
- Sebelum mengunggah log untuk meminta bantuan, periksa agar tidak ada API key, password, token, atau isi `/etc/dbai/9router.env` di dalam log yang dibagikan.
- Panduan terkait: [AI Stack Firmware](AI-STACK-FIRMWARE.md), [troubleshooting partisi boot Windows](IMAGE-PARTITIONS-WINDOWS.md), dan [workflow build DBAI](../.github/workflows/armbian-build.yml).
