# @description Prepares a dedicated LightNVR CCTV image. Installs Docker CE in the image and enables a first-boot Compose stack using the official ARM64 LightNVR container. LightNVR embeds/manages go2rtc, so a duplicate standalone go2rtc process is not started.

enable_extension "docker-ce"

function extension_prepare_config__dbai_cctv_lightnvr() {
	case "${RELEASE}" in
		trixie) ;;
		*) exit_with_error "LightNVR + go2rtc is currently configured for Debian Trixie; got ${RELEASE}" ;;
	esac
	[[ "${ARCH}" == "arm64" ]] || exit_with_error "LightNVR CCTV image requires ARM64; got ${ARCH}"
	display_alert "Target image will start LightNVR with integrated go2rtc on first boot" "${RELEASE} ${EXTENSION}" "info"
	EXTRA_IMAGE_SUFFIXES+=("-lightnvr-go2rtc")
}

function post_repo_customize_image__dbai_prepare_lightnvr_stack() {
	display_alert "Preparing pinned LightNVR + go2rtc Docker stack" "${EXTENSION}" "info"
	run_host_command_logged install -m 0755 -d \
		"${SDCARD}/opt/dbai-cctv/config" \
		"${SDCARD}/opt/dbai-cctv/data/recordings" \
		"${SDCARD}/usr/local/sbin" \
		"${SDCARD}/etc/systemd/system/multi-user.target.wants"

	cat > "${SDCARD}/opt/dbai-cctv/compose.yaml" <<'DBAI_LIGHTNVR_COMPOSE'
services:
  lightnvr:
    image: ghcr.io/opensensor/lightnvr:0.43.2
    container_name: lightnvr
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./config:/etc/lightnvr
      - ./data:/var/lib/lightnvr/data
    environment:
      TZ: Asia/Jakarta
      GO2RTC_CONFIG_PERSIST: "true"
      LIGHTNVR_AUTO_INIT: "true"
      # For ONVIF discovery, set LIGHTNVR_ONVIF_NETWORK to your LAN CIDR,
      # e.g. 192.168.1.0/24, in this file after first boot.
DBAI_LIGHTNVR_COMPOSE
	run_host_command_logged chmod 0644 "${SDCARD}/opt/dbai-cctv/compose.yaml"

	cat > "${SDCARD}/usr/local/sbin/dbai-start-lightnvr" <<'DBAI_LIGHTNVR_START'
#!/bin/bash
set -Eeuo pipefail
cd /opt/dbai-cctv
logger -t dbai-lightnvr "Starting LightNVR + integrated go2rtc Compose stack."
for attempt in {1..10}; do
	if docker info >/dev/null 2>&1; then
		if docker compose pull && docker compose up -d; then
			logger -t dbai-lightnvr "LightNVR stack started. Web UI: http://<device-ip>:8080; go2rtc API: http://<device-ip>:1984."
			exit 0
		fi
	fi
	logger -t dbai-lightnvr "Attempt $attempt failed; retrying in 30 seconds."
	sleep 30
done
logger -t dbai-lightnvr "ERROR: failed to pull/start LightNVR container after 10 attempts."
exit 1
DBAI_LIGHTNVR_START
	run_host_command_logged chmod 0755 "${SDCARD}/usr/local/sbin/dbai-start-lightnvr"

	cat > "${SDCARD}/etc/systemd/system/dbai-lightnvr.service" <<'DBAI_LIGHTNVR_SERVICE'
[Unit]
Description=DBAI LightNVR CCTV recorder with integrated go2rtc
Wants=network-online.target
After=network-online.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/dbai-start-lightnvr
ExecStop=/usr/bin/docker compose --project-directory /opt/dbai-cctv down
TimeoutStartSec=0
Restart=on-failure
RestartSec=60s

[Install]
WantedBy=multi-user.target
DBAI_LIGHTNVR_SERVICE
	run_host_command_logged chmod 0644 "${SDCARD}/etc/systemd/system/dbai-lightnvr.service"
	ln -sfn ../dbai-lightnvr.service "${SDCARD}/etc/systemd/system/multi-user.target.wants/dbai-lightnvr.service"
	display_alert "LightNVR stack prepared; first boot requires internet to pull the ARM64 container" "${EXTENSION}" "info"
}
