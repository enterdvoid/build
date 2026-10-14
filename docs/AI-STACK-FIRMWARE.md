# DBAI Armbian AI Stack Firmware

The AI firmware variants are ARM64 images for `aml-s9xx-box`. Supported releases are Debian Bookworm/Trixie and Ubuntu Jammy/Noble/Resolute. Each variant uses the workflow-selected filesystem (ext4, btrfs, or both) and an 8 GiB image target.

## Build selection

In **DBAI Armbian Build → Applications preset**:

| Pilihan di menu | Arti sebenarnya |
|---|---|
| `all — Semua aplikasi standar + 3 varian AI` | Membuat **semua aplikasi standar** (Home Assistant, OpenMediaVault, Kali, Docker CE, CasaOS, LightNVR jika release cocok) **dan semua 3 varian AI**. Checkbox aplikasi standar di bawahnya diabaikan karena semua aplikasi standar sudah dipilih. |
| `ai-all — 3 varian AI + aplikasi yang dicentang` | Membuat **Hermes saja, 9Router saja, dan gabungan Hermes + 9Router**. Checkbox aplikasi standar yang dicentang tetap ikut dibuat; yang tidak dicentang tidak ikut. |
| `none — Hanya aplikasi yang dicentang (tanpa preset AI)` | Tidak otomatis menambahkan varian AI atau semua aplikasi standar. Hanya aplikasi standar yang dicentang di bawahnya yang dibuat. Jika tidak ada checkbox aplikasi dipilih, tidak ada image aplikasi dari bagian ini. |
| `hermes — Hermes + aplikasi yang dicentang` | Varian Hermes saja, ditambah aplikasi standar yang dicentang. |
| `9router — 9Router + aplikasi yang dicentang` | Varian 9Router saja, ditambah aplikasi standar yang dicentang. |
| `both — Hermes + 9Router (satu image) + aplikasi yang dicentang` | Satu image yang mengintegrasikan Hermes dan 9Router, ditambah aplikasi standar yang dicentang. |

**Penting:** pilihan ini hanya mengatur kelompok aplikasi. Checkbox **Server**, **Minimal**, dan pilihan **Desktop** terpisah dan tetap berpengaruh. Dengan default saat ini, `all` dipilih, sedangkan Server dan Minimal juga dicentang. Jadi untuk build hanya tiga varian AI, pilih `ai-all`, matikan Server dan Minimal, biarkan checkbox aplikasi standar tidak dicentang, dan pastikan Desktop mode = `none`.

AI variant asset names include `hermes-agent`, `9router`, or `hermes-9router`. AI selections deliberately reuse the existing Applications input, preserving GitHub Actions' 25-input limit.

For a focused first test, choose `ai-all`, uncheck the **Server** and **Minimal** profile boxes (both are checked by default), leave individual application boxes unchecked, keep Desktop mode at `none`, and choose one OS release and filesystem. This builds all three AI variants without extra profiles. Select both filesystems and OS group `all` when you want every supported AI image.

## Is there an AI desktop firmware?

**Not yet as a single integrated desktop image.** The three AI extensions currently generate headless/server-style application images. Selecting a Desktop/DE mode in the same Actions run generates separate desktop images; it does not inject Hermes/9Router into those desktop images.

- **9Router** already provides a browser dashboard. On the AI image it is reachable on the trusted LAN at `http://<device-IP>:20128/dashboard`.
- **Hermes** is currently installed as a CLI/headless agent in this firmware (the installer runs with `--skip-browser`). The upstream project also documents a native desktop app for Linux, Windows, and macOS, plus a web dashboard; see the [official Hermes Desktop documentation](https://hermes-agent.nousresearch.com/docs/user-guide/desktop) and [Web Dashboard documentation](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard).
- The upstream Linux desktop app has **not** yet been built and validated as an integrated GUI for this project's Amlogic ARM64 Armbian desktop image. Do not assume that choosing a DE today gives you a desktop image with the AI stack preinstalled.

To create a true AI desktop firmware, the build matrix needs an explicit combined target that installs the chosen DE and the AI extension in the **same** output image, followed by an ARM64 GUI build and first-login test. Until that work is done, choose either the headless AI variant or a regular desktop image.

## First boot: automatic provisioning

An internet connection is required on first boot. The systemd service installs the selected software, then records completion so a normal reboot does not reinstall it. No provider API keys are embedded in the downloadable image.

After Armbian's normal first-login/network setup, run:

```bash
sudo dbai-ai-setup
```

This command shows installation status, the device's dashboard URL, and (for 9Router images) the randomly generated initial dashboard password. The password and other 9Router secrets are stored in `/etc/dbai/9router.env`, owned by root with mode `0600`. The database lives in a persistent Docker named volume. Container logs are rotated to limit disk use.

### Hermes Agent image

Run:

```bash
hermes
```

The first invocation opens Hermes' supported provider/model picker and starts a chat after configuration. Hermes is installed under a dedicated unprivileged account and runs as that account; its configuration persists in `/var/lib/dbai-hermes/.hermes`. The image uses the official Hermes installer with browser dependencies skipped for a headless server.

### 9Router image

Open the URL printed by `sudo dbai-ai-setup` from a computer on the same LAN, log in with the generated initial password, change it, and connect the provider you want to use. The OpenAI-compatible endpoint is `http://<device-IP>:20128/v1`. An API key should be used by API clients, but do not assume that `REQUIRE_API_KEY=true` is enforced by every upstream image version: upstream issue [decolua/9router #2834](https://github.com/decolua/9router/issues/2834) documents versions where this environment flag is ignored.

At first boot and whenever you run `sudo dbai-ai-setup`, the firmware checks whether `/v1/models` rejects a request without a bearer token. If it returns HTTP 200, open **Dashboard → Endpoint**, enable the API-key requirement, and re-run `sudo dbai-ai-setup` until the check reports HTTP 401/403. This protects the OpenAI-compatible API; keep the dashboard and service on a trusted LAN and never port-forward 20128 directly to the public internet.

To update the container to the publisher's current image:

```bash
sudo dbai-ai-setup --update-router
```

### Combined Hermes + 9Router image

1. Open the 9Router dashboard, change the initial password, and connect a provider.
2. In the 9Router dashboard, create an API key in **Settings → API Keys**.
3. Run:

```bash
sudo dbai-ai-setup --connect-hermes
```

The helper validates the key against `/v1/models`, lists model IDs returned by 9Router, and writes Hermes' custom-provider configuration. The key is written to Hermes' private `.env` file without putting the secret in the process argument list. Hermes then uses the loopback endpoint `http://127.0.0.1:20128/v1`, which stays on the same device.

## Security notes

- 9Router's initial dashboard password, JWT secret, API-key signing secret, and machine ID salt are generated randomly on first boot, not during image build.
- The firmware generates random secrets for 9Router and sets `REQUIRE_API_KEY=true`, then checks the actual unauthenticated API response at startup and when running `sudo dbai-ai-setup`. As upstream issue [#2834](https://github.com/decolua/9router/issues/2834) documents, some versions may ignore that environment flag; follow the runtime check and enable the Endpoint API-key requirement in the dashboard if needed.
- Its dashboard uses HTTP for convenient initial LAN access, so use it only on a trusted LAN. **Do not forward port 20128 directly to the public internet.** Use a VPN or an authenticated HTTPS reverse proxy for remote access.
- Provider accounts and credentials are user-supplied. The firmware does not guarantee that any provider or model has a free tier, and external API usage may incur charges.
- The 9Router container tag is `latest`; `sudo dbai-ai-setup --update-router` pulls the currently published image. Review upstream release notes before updating production devices.

## Diagnostics

```bash
sudo systemctl status dbai-ai-stack-firstboot.service
sudo journalctl -u dbai-ai-stack-firstboot.service -n 100 --no-pager
sudo tail -n 100 /var/log/dbai-ai-stack-install.log
```

For combined images, create a fresh 9Router API key and rerun `sudo dbai-ai-setup --connect-hermes` if you rotate that key.
