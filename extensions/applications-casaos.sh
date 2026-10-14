# @description Prepares CasaOS on Debian Bookworm ARM64. The official CasaOS installer runs on first boot (not inside the build chroot) so Docker/systemd services can initialize correctly. Requires internet access on first boot.

function extension_prepare_config__casaos() {
	case "${RELEASE}" in
		bookworm) ;;
		*) exit_with_error "CasaOS is currently enabled only for Debian Bookworm; got ${RELEASE}" ;;
	esac
	[[ "${ARCH}" == "arm64" ]] || exit_with_error "CasaOS requires ARM64 in this DBAI image; got ${ARCH}"
	display_alert "Target image will install CasaOS automatically on first boot" "${RELEASE} ${EXTENSION}" "info"
	EXTRA_IMAGE_SUFFIXES+=("-casaos")
}

function post_repo_customize_image__dbai_prepare_casaos_firstboot() {
	display_alert "Preparing the official CasaOS first-boot installer" "${EXTENSION}" "info"
	run_host_command_logged install -m 0755 -d \
		"${SDCARD}/usr/local/sbin" \
		"${SDCARD}/etc/systemd/system/multi-user.target.wants" \
		"${SDCARD}/var/lib/dbai"

	cat > "${SDCARD}/usr/local/sbin/dbai-install-casaos" <<'DBAI_CASAOS_INSTALL'
#!/bin/bash
set -Eeuo pipefail
exec >> /var/log/dbai-casaos-install.log 2>&1
mkdir -p /var/lib/dbai
marker=/var/lib/dbai/casaos-install-complete
if [[ -e "$marker" ]]; then
	echo "CasaOS was already installed successfully; nothing to do."
	exit 0
fi
echo "=== DBAI CasaOS first-boot installation: $(date -Is) ==="
echo "This step downloads the official installer from https://get.casaos.io."
export DEBIAN_FRONTEND=noninteractive
if ! command -v curl >/dev/null 2>&1; then
	apt-get update
	apt-get install -y ca-certificates curl
fi
installer=/run/dbai-casaos-install.sh
downloaded=false
for attempt in {1..5}; do
	if curl -4 -fL --connect-timeout 20 --max-time 300 --retry 2 --retry-delay 3 https://get.casaos.io -o "$installer"; then
		downloaded=true
		break
	fi
	echo "Installer download attempt $attempt failed; waiting before retry."
	sleep 15
done
if [[ "$downloaded" != true ]]; then
	echo "ERROR: unable to download the official CasaOS installer."
	exit 1
fi
bash "$installer"
touch "$marker"
rm -f "$installer"
echo "CasaOS installer completed successfully at $(date -Is)."
DBAI_CASAOS_INSTALL
	run_host_command_logged chmod 0755 "${SDCARD}/usr/local/sbin/dbai-install-casaos"

	cat > "${SDCARD}/etc/systemd/system/dbai-casaos-firstboot.service" <<'DBAI_CASAOS_SERVICE'
[Unit]
Description=DBAI CasaOS first-boot installation
Wants=network-online.target
After=network-online.target
ConditionPathExists=!/var/lib/dbai/casaos-install-complete

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/dbai-install-casaos
RemainAfterExit=yes
Restart=on-failure
RestartSec=60s
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
DBAI_CASAOS_SERVICE
	run_host_command_logged chmod 0644 "${SDCARD}/etc/systemd/system/dbai-casaos-firstboot.service"
	ln -sfn ../dbai-casaos-firstboot.service "${SDCARD}/etc/systemd/system/multi-user.target.wants/dbai-casaos-firstboot.service"
}
