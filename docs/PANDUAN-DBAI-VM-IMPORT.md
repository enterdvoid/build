# DBAI VM Image Importer

**Script utama:** [`tools/dbai-vm-import`](../tools/dbai-vm-import)  
**Berlaku untuk:** Proxmox VE Official dan Proxmox Community/PXVIRT yang dibangun melalui workflow DBAI.

## 1. Fungsi

`dbai-vm-import` adalah wizard terminal untuk impor disk virtual. Pengguna memberikan path file lokal atau URL HTTP(S), lalu memilih VMID, nama VM, RAM, vCPU, storage image, dan bridge jaringan. Tool memvalidasi format menggunakan `qemu-img`, membuat konfigurasi VM, mengimpor disk melalui perintah Proxmox, memasang disk boot, dan memeriksa bridge sebelum menawarkan start.

Tool yang sama dipasang di kedua extension Proxmox, sehingga perilakunya tidak berbeda hanya karena varian Official atau Community. Paket Hypervisor tetap dikelola extension masing-masing.

## 2. Coba langsung pada firmware Proxmox yang sudah terpasang

Sambungkan melalui SSH atau console sebagai root. Pastikan host memiliki koneksi internet, lalu jalankan:

```bash
curl -fsSL https://raw.githubusercontent.com/enterdvoid/build/main/tools/dbai-vm-import -o /usr/local/sbin/dbai-vm-import
chmod 0755 /usr/local/sbin/dbai-vm-import
bash -n /usr/local/sbin/dbai-vm-import
dbai-vm-import --help
dbai-vm-import --check
dbai-vm-import
```

Pada firmware yang dibangun sebelum integrasi ini, dependensi mungkin belum tersedia. Pasang paket yang diperlukan terlebih dahulu:

```bash
apt update
apt install -y qemu-utils curl wget whiptail unzip xz-utils zstd gzip bzip2 python3
```

**Catatan:** bila wizard harus dijalankan dari SSH, jalankan pada terminal interaktif biasa. Jika koneksi SSH tidak stabil, gunakan console lokal agar proses impor tidak terputus.

## 3. Format yang dikenali

| Jenis input | Perilaku |
|---|---|
| RAW / `.img` / `.raw` | Pemeriksaan dan impor disk |
| `.qcow2` | Pemeriksaan dan impor disk |
| `.vdi` | Pemeriksaan dan impor disk VirtualBox |
| `.vmdk` | Pemeriksaan dan impor disk VMware |
| `.vhd` / `.vhdx` | Pemeriksaan dan impor disk Hyper-V |
| `.img.xz`, `.img.gz`, `.img.zst`, `.img.bz2` serta kompresi sejenis yang dikenali | Ekstrak dahulu, lalu periksa disk |
| `.zip` | Ekstrak dan pilih salah satu disk yang dikenali |
| `.ova` / `.ovf` | Cari file disk yang dirujuk, lalu impor disk yang dipilih |

Untuk OVA/OVF, versi saat ini hanya mengimpor disk yang dipilih. CPU, RAM, firmware boot, dan perangkat jaringan yang tersimpan sebagai metadata appliance tidak dipulihkan otomatis; pilih pengaturan di wizard dan tinjau hasilnya sebelum menjalankan VM. ISO installer bukan disk siap boot dan harus dipasang melalui alur pembuatan VM installer biasa.

Format akhir yang benar-benar dapat dibaca diverifikasi oleh `qemu-img info`; ekstensi file saja tidak cukup. Format output disk mengikuti mekanisme impor Proxmox dan kemampuan storage yang dipilih.

## 4. Jaringan dan keamanan

- Wizard hanya menawarkan storage aktif yang menerima content `images`.
- Wizard mendeteksi bridge Linux yang sudah ada, misalnya `vmbr0`. Ia tidak berasumsi bahwa nama itu pasti tersedia.
- Wizard **tidak membuat atau mengganti konfigurasi jaringan host**. Jika tidak ada bridge, pengguna dapat membuat VM tanpa NIC dan mengatur jaringan kemudian melalui Web UI.
- Start VM tidak otomatis dilakukan secara default. Tinjau ringkasan konfigurasi lebih dahulu.
- VMID diperiksa agar tidak menimpa VM yang sudah ada. Jika impor gagal setelah VM kosong dibuat, tool mencoba membersihkan VM sementara tersebut.
- Log ditulis ke `/var/log/dbai-vm-import.log`.
- File yang diunduh atau diekstrak memakai direktori sementara. Pastikan filesystem sementara memiliki ruang yang cukup untuk image terkompresi dan hasil ekstraksinya.

## 5. Arsitektur guest dan batas kompatibilitas

`qemu-img` mendeteksi **format disk**, bukan CPU guest, firmware boot, atau kompatibilitas kernel. Pada host ARM64, pastikan image juga ditujukan untuk ARM64/aarch64; disk x86_64 tidak otomatis dapat berjalan sebagai guest ARM64. Wizard meminta konfirmasi arsitektur pada host ARM64, menggunakan machine type `virt`, dan memberi peringatan jika `/dev/kvm` tidak tersedia.

Keberhasilan impor bukan bukti bahwa guest bisa boot. Image tertentu membutuhkan UEFI, serial console, controller disk, NIC, atau konfigurasi machine yang spesifik. Jika VM tidak start, lihat task log Proxmox dan periksa konfigurasi VM sebelum mencoba mengubah host network.

### Catatan khusus MikroTik CHR

Unduhan CHR MikroTik saat ini menampilkan pilihan RAW/VDI ARM64, tetapi dokumentasi instalasi CHR juga masih menjelaskan CHR sebagai produk virtual x86_64. Periksa arsitektur dan catatan rilis pada image yang benar-benar diunduh; jangan menyimpulkan kompatibilitas hanya dari nama format. Sumber:

- https://mikrotik.com/download/chr
- https://manual.mikrotik.com/docs/getting-started/installation-and-upgrade/install/chr-installation/

## 6. Pemeriksaan dan pemecahan masalah

```bash
# Lingkungan, storage, bridge, KVM
dbai-vm-import --check

# Tampilkan storage dan bridge saja
dbai-vm-import --list

# Periksa log operasi terakhir
tail -n 200 /var/log/dbai-vm-import.log

# Lihat konfigurasi VM setelah impor (ganti 100 dengan VMID)
qm config 100

# Status VM
qm status 100
```

Jika storage tidak muncul, buka **Datacenter → Storage** dan pastikan tipe storage aktif serta content **Disk image** diaktifkan. Jika tidak ada bridge, atur bridge secara terpisah dengan mengikuti panduan jaringan yang sesuai untuk pengelola jaringan firmware tersebut. Jangan mengubah NIC host secara otomatis saat terhubung melalui SSH tanpa mekanisme pemulihan.

## 7. Instalasi saat build firmware

Workflow `DBAI Armbian Build` menyertakan script dan dependensi ketika membangun salah satu varian Proxmox:

- **Proxmox VE Official:** extension `proxmox-official`, basis Debian Trixie.
- **Proxmox Community:** extension `proxmox-community`, basis Debian Bookworm.

File sumber yang dipasang ke image: `tools/dbai-vm-import`. Validasi CI memeriksa sintaks script, halaman bantuan, daftar format, dan pemasangan pada kedua extension. Tes statis tersebut tidak menggantikan build firmware penuh atau pengujian VM di perangkat fisik.

## Status validasi

Integrasi source telah ditambahkan ke branch `main`. Sampai workflow CI dan build firmware berikutnya benar-benar selesai, jangan menganggap semua format sudah lulus end-to-end. Uji awal yang disarankan: impor image kecil, verifikasi konfigurasi VM, boot tanpa mengubah bridge host, kemudian uji setiap jenis format yang memang dibutuhkan.
