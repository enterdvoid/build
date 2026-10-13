# Runners requirements

- big (6-16 cores, 64Gb SSD, 16Gb memory, 2Gb swap)
- small (4 cores, 64Gb SSD, 8Gb memory, 2Gb swap)

## Preparation



Adding x86 runner to your Jammy VM (check [here](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners) if any changes):

    $ mkdir actions-runner 
    $ cd actions-runner
    $ curl -o actions-runner-linux-x64-2.294.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.294.0/actions-runner-linux-x64-2.294.0.tar.gz
    $ tar xzf ./actions-runner-linux-x64-2.294.0.tar.gz

## Configuration

Once asked, tag your runner accordingly:

- small
- big
- arm64

Start the configuration experience

    $ ./config.sh --url https://github.com/armbian --token XXXXXXXXXXXXXXXXXXXXXXXXXXX

You need to get a valid token from our DevOps team to proceed.

## Create startup scripts

    sudo ./svc.sh install # install
    sudo ./svc.sh start   # start
    sudo ./svc.sh status  # check

## Use workflows in forked repositories

`forked-helper.yml` workflow helper can help to run custom workflows on the forked repositories.

1. Create a [fine-grained Personal Access Token (PAT)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token) with the `repo` scope and store it as a secret. It needs the following permissions on the target repositories:
    - `contents`: read & write
    - `metadata`: read only (automatically selected when selecting the contents permission)
2. Create a secret named `ARMBIAN_SELF_DISPATCH_TOKEN` on your repository with `security_events` permissions. To do this, head to your forked repository, go to `Settings` on the top bar, select `Secrets and variables` and then `Actions`. From here you can create a new repository secret.
    - `Name`: `ARMBIAN_SELF_DISPATCH_TOKEN`
    - `Secret`: Paste your fine-grained Personal Access Token that you created in step 1 here
3. Helper will dispatch `repository_dispatch` event `armbian` on `push`, `release`, `deployment`, 
   `pull_request` and `workflow_dispatch` events. All needed event details you can find in `client_payload` property of the event.
4. Create empty default branch in forked repository
5. Create workflow with `repository_dispatch` in default branch.
6. Run any need actions in this workflow.

Workflow example:
```yaml
name: Test Armbian dispatch

on:
  repository_dispatch:
    types: ["armbian"]

jobs:
  show-dispatch:
    name: Show dispatch event details
    runs-on: ubuntu-latest
    steps:
      - uses: hmarr/debug-action@v2
```

## DBAI Armbian Build matrix

Workflow khusus fork ini: [`.github/workflows/armbian-build.yml`](./armbian-build.yml). Jalankan dari **Actions → DBAI Armbian Build → Run workflow**.

### Pilihan utama

- **Filesystem** — default `both`, menghasilkan ext4 dan Btrfs untuk setiap kombinasi yang dipilih.
- **OS release group** — `all` (Bookworm, Trixie, Forky, Jammy, Noble, Resolute), `debian`, `ubuntu`, atau `trixie`.
- **FULL BUILD** — default aktif. Mengabaikan checkbox profil lain dan memilih Server, Minimal, semua aplikasi yang kompatibel, serta semua desktop yang aktif dan kompatibel dengan OS terpilih.
- Untuk build sebagian, matikan **FULL BUILD**, lalu centang profil/aplikasi/desktop yang dibutuhkan. Server dan Minimal menghasilkan image untuk setiap release dalam kelompok OS terpilih.

### Cakupan kompatibilitas

- Server dan Minimal: semua release yang terdaftar dalam kelompok OS.
- Home Assistant dan OpenMediaVault: Debian Bookworm/Trixie.
- Kali: Debian Bookworm/Trixie/Forky.
- Docker CE: Debian Bookworm/Trixie dan Ubuntu Jammy/Noble/Resolute.
- Desktop aktif: XFCE, MATE, GNOME, Cinnamon, KDE Plasma, i3-wm, dan Enlightenment pada semua release terdaftar; Budgie pada Bookworm, Trixie, dan Noble.
- KDE Neon, Xmonad, dan Deepin tidak dimasukkan ke matriks karena saat ini ditandai tidak didukung/nonaktif oleh konfigurasi desktop Armbian yang dipakai.

Kombinasi aplikasi sengaja dibatasi sesuai dukungan extension-nya. Karena itu, **all** berarti semua profil yang kompatibel untuk setiap OS, bukan memaksakan aplikasi ke release yang tidak didukung.

### Ukuran full build

Dengan default `OS release group=all`, `Filesystem=both`, dan `FULL BUILD=on`, matriks menghitung **138 job**: 69 kombinasi per filesystem × dua filesystem. Untuk setiap job, Actions membangun image dan checksum SHA-256, lalu mengunggahnya ke Release jika build sukses. Nama asset memuat filesystem, release OS, profil, dan varian agar hasilnya mudah dibedakan.

Workflow menjalankan maksimal dua job build sekaligus dan tiap job memiliki timeout enam jam. Full build dapat memerlukan waktu lama; gunakan kelompok OS atau subset profil untuk test yang lebih cepat.
