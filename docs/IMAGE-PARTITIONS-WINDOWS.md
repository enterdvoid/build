# Visibilitas partisi boot firmware DBAI di Windows

Dokumen ini mencatat penyebab label **`234`** di 7-Zip dan perubahan layout partisi untuk image board `aml-s9xx-box`.

## Gejala

Setelah image DBAI Armbian di-burn ke SD card, Windows tidak menampilkan partisi boot sebagai drive yang bisa dibuka. Ketika image diperiksa di 7-Zip, kolom **Filesystem** menampilkan `234`, sementara image pembanding (misalnya build yang menampilkan `FAT32-LBA`) memakai tipe partisi MBR yang dikenali Windows.

## Penyebab

Angka `234` adalah nilai desimal dari kode tipe partisi MBR `0xEA`. Kode ini dipakai Armbian pada layout umum untuk **Linux Extended Boot/XBOOTLDR**. Angka itu adalah *partition type ID*, bukan nama filesystem yang ditemukan di dalam partisi.

Konfigurasi board DBAI `config/boards/aml-s9xx-box.tvb` sudah menentukan `BOOTFS_TYPE="fat"`. Namun, kode partisi generik di `lib/functions/image/partitioning.sh` sebelumnya tetap menandai partisi boot MBR sebagai `0xEA`. Kombinasi tersebut membuat tabel partisi menyatakan “Linux Extended Boot”, meskipun isi partisi boot diformat sebagai filesystem FAT oleh builder. Windows dapat menyembunyikan partisi dengan tipe tersebut atau tidak memberinya drive letter otomatis.

Untuk pembanding, tipe MBR `0x0C` dikenal sebagai **W95 FAT32 (LBA)/FAT32-LBA**.

## Perbaikan di source

Untuk menghindari perubahan perilaku board lain, pengecualian dibatasi pada kombinasi berikut:

- Board: `aml-s9xx-box`
- Partition table: MBR/DOS (`IMAGE_PARTITION_TABLE != gpt`)
- Filesystem boot: `fat`

Pada kombinasi ini, builder sekarang menggunakan tipe MBR `0x0C` untuk partisi boot, agar sesuai dengan layout FAT yang diharapkan dan bisa dikenali Windows. Layout GPT dan tipe partisi untuk board lain tetap menggunakan aturan generik Armbian.

Perubahan ini **hanya mengubah tipe partisi dalam tabel MBR**. Cara memformat partisi boot, ukuran partisi, konfigurasi rootfs ext4/Btrfs, kernel, DTB, dan boot script tidak diubah oleh perbaikan tersebut.

## Cara memverifikasi image hasil build

Lakukan pemeriksaan pada image baru yang belum di-burn atau pada file image hasil build. Jika file masih `.img.xz`, ekstrak terlebih dahulu, misalnya memakai 7-Zip.

Dari Linux atau WSL dengan utilitas `util-linux`, jalankan:

```bash
sfdisk --dump aml-s9xx-box-ext4-bookworm-server.img
```

Nama file di atas hanya contoh; ganti dengan image yang diperiksa. Baris partisi boot pertama seharusnya menunjukkan tipe `c` atau `0c` (representasi `0x0C` dari `FAT32-LBA`), bukan `ea`.

Untuk memeriksa filesystem di dalam image juga, jalankan:

```bash
loopdev=$(sudo losetup --find --show --partscan aml-s9xx-box-ext4-bookworm-server.img)
lsblk -o NAME,SIZE,FSTYPE,PARTTYPE,LABEL "$loopdev"
sudo losetup -d "$loopdev"
```

Ganti nama file contoh dengan image yang sebenarnya. Untuk partisi boot, hasil yang diharapkan adalah filesystem FAT (umumnya ditampilkan sebagai `vfat`) dan partition type `0x0c`. Rootfs ext4 atau Btrfs memang tidak bisa dibaca langsung oleh Windows Explorer tanpa perangkat lunak tambahan.

**Peringatan:** jika Windows menawarkan untuk memformat partisi Linux/rootfs, pilih **Cancel**. Jangan memformat partisi rootfs hanya agar Windows dapat membacanya.

## Apa dampaknya pada firmware yang sudah di-burn?

Perubahan source tidak memperbaiki SD card atau file image lama secara otomatis. Buat image baru dari commit yang berisi perbaikan ini, periksa tabel partisinya, lalu burn ulang. Jika image lama masih bisa boot di STB, nilai `234` saja tidak membuktikan bahwa firmware rusak; itu menunjukkan tipe partisi MBR yang dipakai oleh image lama.

## Status validasi

- **Source fix:** diterapkan khusus untuk `aml-s9xx-box` dengan boot filesystem `fat`.
- **Validasi kode:** perlu dipastikan lewat workflow CI setelah perubahan ini.
- **Build image dan uji burn di perangkat nyata:** belum dianggap lulus sampai ada image baru yang berhasil diperiksa dan diuji boot di STB serta partisi boot dapat diakses di Windows.

Referensi upstream: [Armbian partitioning implementation](https://github.com/armbian/build/blob/main/lib/functions/image/partitioning.sh) dan [UAPI Boot Loader Specification — XBOOTLDR type `0xEA`](https://uapi-group.org/specifications/specs/boot_loader_specification/).
