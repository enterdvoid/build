# DBAI Armbian AI Stack Firmware

The AI firmware variants are ARM64 images for `aml-s9xx-box`. Supported releases are Debian Bookworm/Trixie and Ubuntu Jammy/Noble/Resolute. Each variant uses the workflow-selected filesystem (ext4, btrfs, or both) and an 8 GiB image target.

## Build selection

In **DBAI Armbian Build → Applications preset**:

| Preset | Output |
|---|---|
| `all` | All standard application variants plus Hermes-only, 9Router-only, and combined Hermes + 9Router images |
| `hermes` | Hermes Agent only (other individually checked application options are still additive) |
| `9router` | 9Router only (other individually checked application options are still additive) |
| `both` | Hermes Agent + 9Router in one image (other individually checked application options are still additive) |
| `none` | Only the individually checked application options |

AI variant asset names include `hermes-agent`, `9router`, or `hermes-9router`. AI selections deliberately reuse the existing Applications input, preserving GitHub Actions' 25-input limit.

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

Open the URL printed by `sudo dbai-ai-setup` from a computer on the same LAN, log in with the generated initial password, change it, and connect the provider you want to use. The OpenAI-compatible endpoint is `http://<device-IP>:20128/v1`. The API requires an API key.

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
- The 9Router runtime requires API keys. Its dashboard uses HTTP for convenient initial LAN access, so use it only on a trusted LAN. **Do not forward port 20128 directly to the public internet.** Use a VPN or an authenticated HTTPS reverse proxy for remote access.
- Provider accounts and credentials are user-supplied. The firmware does not guarantee that any provider or model has a free tier, and external API usage may incur charges.
- The 9Router container tag is `latest`; `sudo dbai-ai-setup --update-router` pulls the currently published image. Review upstream release notes before updating production devices.

## Diagnostics

```bash
sudo systemctl status dbai-ai-stack-firstboot.service
sudo journalctl -u dbai-ai-stack-firstboot.service -n 100 --no-pager
sudo tail -n 100 /var/log/dbai-ai-stack-install.log
```

For combined images, create a fresh 9Router API key and rerun `sudo dbai-ai-setup --connect-hermes` if you rotate that key.
