# Shared implementation for the three DBAI Hermes / 9Router firmware variants.
# This file is sourced by ai-hermes.sh, ai-router9.sh, or ai-hermes-router9.sh;
# it is not enabled as a standalone extension.

case "${DBAI_AI_STACK_MODE:-}" in
	hermes) ;;
	9router|both) enable_extension "docker-ce" ;;
	*) exit_with_error "Unknown DBAI_AI_STACK_MODE: ${DBAI_AI_STACK_MODE:-unset}" ;;
esac

function dbai_ai_stack_prepare_config() {
	local label="$1"
	local suffix="$2"
	case "${RELEASE}" in
		bookworm|trixie|jammy|noble|resolute) ;;
		*) exit_with_error "AI stack variant ${label} supports Bookworm, Trixie, Jammy, Noble, and Resolute; got ${RELEASE}" ;;
	esac
	[[ "${ARCH}" == "arm64" ]] || exit_with_error "AI stack variant ${label} requires ARM64; got ${ARCH}"
	display_alert "Target image will provision ${label} on first boot" "${RELEASE} ${EXTENSION}" "info"
	EXTRA_IMAGE_SUFFIXES+=("${suffix}")
}

function dbai_ai_stack_prepare_image() {
	display_alert "Preparing first-boot setup for DBAI AI mode ${DBAI_AI_STACK_MODE}" "${EXTENSION}" "info"
	run_host_command_logged install -m 0755 -d \
		"${SDCARD}/etc/dbai" \
		"${SDCARD}/opt/dbai-ai-stack" \
		"${SDCARD}/var/lib/dbai-ai-stack" \
		"${SDCARD}/usr/local/sbin" \
		"${SDCARD}/usr/local/bin" \
		"${SDCARD}/etc/systemd/system/multi-user.target.wants" \
		"${SDCARD}/etc/update-motd.d"

	cat > "${SDCARD}/etc/dbai/ai-stack-mode" <<DBAI_AI_MODE
${DBAI_AI_STACK_MODE}
DBAI_AI_MODE
	run_host_command_logged chmod 0644 "${SDCARD}/etc/dbai/ai-stack-mode"

	cat > "${SDCARD}/usr/local/sbin/dbai-ai-stack-firstboot" <<'DBAI_AI_FIRSTBOOT'
#!/usr/bin/env bash
set -Eeuo pipefail
exec >> /var/log/dbai-ai-stack-install.log 2>&1
umask 077

MODE="$(cat /etc/dbai/ai-stack-mode)"
STATE_DIR=/var/lib/dbai-ai-stack
MARKER="$STATE_DIR/firstboot-complete"
HERMES_USER=dbai-hermes
HERMES_HOME=/var/lib/dbai-hermes
HERMES_BIN="$HERMES_HOME/.local/bin/hermes"
ROUTER_ENV=/etc/dbai/9router.env
INSTALLER=/run/dbai-hermes-install.sh

if [[ -e "$MARKER" ]]; then
	echo "DBAI AI stack already provisioned."
	exit 0
fi

echo "=== DBAI AI stack first-boot provisioning: $(date -Is) ==="
echo "Selected mode: $MODE"

apt_updated=false
for attempt in 1 2 3 4 5; do
	if apt-get update; then
		apt_updated=true
		break
	fi
	echo "APT update attempt $attempt failed; retrying in 15 seconds."
	sleep 15
done
if [[ "$apt_updated" != true ]]; then
	echo "ERROR: apt-get update failed after retries."
	exit 1
fi
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
	ca-certificates curl git python3 python3-venv python3-pip build-essential ripgrep openssl

router_enabled=false
hermes_enabled=false
case "$MODE" in
	hermes) hermes_enabled=true ;;
	9router) router_enabled=true ;;
	both) router_enabled=true; hermes_enabled=true ;;
	*) echo "ERROR: unknown AI stack mode '$MODE'."; exit 1 ;;
esac

if [[ "$router_enabled" == true ]]; then
	echo "Preparing 9Router credentials and persistent Docker service."
	install -m 0755 -d /etc/dbai
	if [[ ! -s "$ROUTER_ENV" ]]; then
		INITIAL_PASSWORD="$(openssl rand -hex 16)"
		JWT_SECRET="$(openssl rand -hex 32)"
		API_KEY_SECRET="$(openssl rand -hex 32)"
		MACHINE_ID_SALT="$(openssl rand -hex 32)"
		{
			printf 'INITIAL_PASSWORD=%s\n' "$INITIAL_PASSWORD"
			printf 'JWT_SECRET=%s\n' "$JWT_SECRET"
			printf 'API_KEY_SECRET=%s\n' "$API_KEY_SECRET"
			printf 'MACHINE_ID_SALT=%s\n' "$MACHINE_ID_SALT"
			printf 'DATA_DIR=/app/data\nPORT=20128\nHOSTNAME=0.0.0.0\nNODE_ENV=production\n'
			printf 'AUTH_COOKIE_SECURE=false\nREQUIRE_API_KEY=true\n'
			printf 'BASE_URL=http://localhost:20128\nNEXT_PUBLIC_BASE_URL=http://localhost:20128\n'
		} > "$ROUTER_ENV"
	fi
	chown root:root "$ROUTER_ENV"
	chmod 0600 "$ROUTER_ENV"

	systemctl enable --now docker.service
	docker_ready=false
	for attempt in 1 2 3 4 5 6 7 8 9 10; do
		if docker info >/dev/null 2>&1; then
			docker_ready=true
			break
		fi
		echo "Docker not ready (attempt $attempt/10); waiting 10 seconds."
		sleep 10
	done
	if [[ "$docker_ready" != true ]]; then
		echo "ERROR: Docker did not become ready."
		exit 1
	fi

	cd /opt/dbai-ai-stack
	router_started=false
	for attempt in 1 2 3 4 5; do
		if docker compose pull && docker compose up -d --remove-orphans; then
			router_started=true
			break
		fi
		echo "9Router pull/start attempt $attempt/5 failed; retrying in 30 seconds."
		sleep 30
	done
	if [[ "$router_started" != true ]]; then
		echo "ERROR: could not start 9Router. Check Docker/network and retry this unit."
		exit 1
	fi
	echo "9Router container started; dashboard listens on port 20128."
fi

if [[ "$hermes_enabled" == true ]]; then
	echo "Installing Hermes Agent as an unprivileged dedicated account."
	if ! id "$HERMES_USER" >/dev/null 2>&1; then
		useradd --system --user-group --create-home --home-dir "$HERMES_HOME" --shell /bin/bash "$HERMES_USER"
	fi
	install -d -o "$HERMES_USER" -g "$HERMES_USER" -m 0750 "$HERMES_HOME"
	if [[ ! -x "$HERMES_BIN" ]]; then
		rm -f "$INSTALLER"
		curl -4 --fail --location --silent --show-error --connect-timeout 20 --max-time 300 --retry 3 --retry-delay 5 \
			https://hermes-agent.nousresearch.com/install.sh -o "$INSTALLER"
		chmod 0644 "$INSTALLER"
		runuser --user "$HERMES_USER" -- env HOME="$HERMES_HOME" USER="$HERMES_USER" LOGNAME="$HERMES_USER" \
			PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
			bash "$INSTALLER" --non-interactive --skip-browser
		rm -f "$INSTALLER"
	fi
	if [[ ! -x "$HERMES_BIN" ]]; then
		echo "ERROR: Hermes installer finished but $HERMES_BIN was not created."
		exit 1
	fi

	cat > /usr/local/bin/hermes <<'DBAI_HERMES_WRAPPER'
#!/usr/bin/env bash
set -Eeuo pipefail
HERMES_USER=dbai-hermes
HERMES_HOME=/var/lib/dbai-hermes
HERMES_BIN="$HERMES_HOME/.local/bin/hermes"
CONFIGURED_MARKER="$HERMES_HOME/.dbai-model-configured"

as_hermes() {
	if [[ "$(id -un)" == "$HERMES_USER" ]]; then
		"$@"
	elif [[ "$EUID" -eq 0 ]]; then
		runuser --user "$HERMES_USER" -- env HOME="$HERMES_HOME" PATH="/var/lib/dbai-hermes/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" "$@"
	else
		sudo -u "$HERMES_USER" -H env HOME="$HERMES_HOME" PATH="/var/lib/dbai-hermes/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" "$@"
	fi
}

if [[ ! -x "$HERMES_BIN" ]]; then
	echo "Hermes Agent is not installed yet. Check: sudo systemctl status dbai-ai-stack-firstboot.service" >&2
	exit 1
fi

# First invocation opens the supported provider/model picker, then enters chat.
if [[ "$#" -eq 0 && ! -e "$CONFIGURED_MARKER" ]]; then
	echo "Welcome to DBAI Hermes. First, choose your AI provider and model."
	if as_hermes "$HERMES_BIN" model; then
		as_hermes /usr/bin/touch "$CONFIGURED_MARKER"
		echo "Provider selection saved. Starting Hermes chat..."
		exec "$0" chat
	else
		echo "Provider setup was not completed. Run 'hermes model' when ready." >&2
		exit 1
	fi
fi

if [[ "${1:-}" == "model" ]]; then
	if as_hermes "$HERMES_BIN" "$@"; then
		as_hermes /usr/bin/touch "$CONFIGURED_MARKER"
		exit 0
	else
		exit $?
	fi
fi

as_hermes "$HERMES_BIN" "$@"
DBAI_HERMES_WRAPPER
	chmod 0755 /usr/local/bin/hermes
	chown -R "$HERMES_USER:$HERMES_USER" "$HERMES_HOME"
	echo "Hermes Agent installed. The 'hermes' command runs it as an unprivileged account."
fi

touch "$MARKER"
chmod 0644 "$MARKER"
echo "First-boot provisioning completed successfully at $(date -Is)."
DBAI_AI_FIRSTBOOT
	run_host_command_logged chmod 0755 "${SDCARD}/usr/local/sbin/dbai-ai-stack-firstboot"

	cat > "${SDCARD}/usr/local/sbin/dbai-ai-setup" <<'DBAI_AI_SETUP'
#!/usr/bin/env bash
set -Eeuo pipefail
MODE="$(cat /etc/dbai/ai-stack-mode 2>/dev/null || echo unknown)"
ROUTER_ENV=/etc/dbai/9router.env
HERMES_HOME=/var/lib/dbai-hermes
HERMES_BIN="$HERMES_HOME/.local/bin/hermes"

if [[ "$EUID" -ne 0 ]]; then
	exec sudo /usr/local/sbin/dbai-ai-setup "$@"
fi

find_ip() {
	local addr=""
	addr="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src" && i<NF) {print $(i+1); exit}}' || true)"
	if [[ -z "$addr" ]]; then
		addr="$(ip -o -4 addr show scope global 2>/dev/null | awk '$2 !~ /^(docker|br-|veth|virbr)/ {split($4,a,"/"); print a[1]; exit}' || true)"
	fi
	printf '%s' "$addr"
}

case "${1:-}" in
	--update-router)
		[[ "$MODE" == "9router" || "$MODE" == "both" ]] || { echo "This image does not include 9Router."; exit 1; }
		cd /opt/dbai-ai-stack
		docker compose pull
		docker compose up -d --remove-orphans
		echo "9Router updated."
		exit 0
		;;
	--connect-hermes)
		[[ "$MODE" == "both" ]] || { echo "This option is available only on the Hermes + 9Router image."; exit 1; }
		[[ -x "$HERMES_BIN" ]] || { echo "Hermes is still installing. Check: systemctl status dbai-ai-stack-firstboot.service"; exit 1; }
		[[ -s "$ROUTER_ENV" ]] || { echo "9Router setup is not ready. Check: systemctl status dbai-ai-stack-firstboot.service"; exit 1; }
		echo "Create an API key in the 9Router dashboard first (Settings / API Keys)."
		read -r -s -p "Paste 9Router API key: " api_key
		printf '\n'
		[[ -n "$api_key" ]] || { echo "API key cannot be empty."; exit 1; }
		if ! models_json="$(curl -4 -fsS --connect-timeout 5 --max-time 20 -H "Authorization: Bearer $api_key" http://127.0.0.1:20128/v1/models)"; then
			echo "9Router rejected the API key or its API is not ready. Check the key and try again." >&2
			exit 1
		fi
		models="$(printf '%s' "$models_json" | python3 -c 'import json,sys; p=json.load(sys.stdin); rows=p.get("data", []) if isinstance(p, dict) else []; print("\n".join(str(x.get("id","")) for x in rows if isinstance(x, dict) and x.get("id")))' )"
		if [[ -n "$models" ]]; then
			printf '\nModels returned by 9Router:\n%s\n\n' "$models" | sed -n '1,30p'
		fi
		read -r -p "Model ID to use in Hermes: " model
		[[ -n "$model" ]] || { echo "Model ID cannot be empty."; exit 1; }
		if [[ -n "$models" ]] && ! grep -Fxq -- "$model" <<< "$models"; then
			echo "That model ID was not returned by 9Router. Copy one of the exact IDs above and retry." >&2
			exit 1
		fi
		as_hermes_config() {
			runuser --user dbai-hermes -- env HOME="$HERMES_HOME" PATH="$HERMES_HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" "$HERMES_BIN" config set "$1" "$2" >/dev/null
		}
		# Send the secret over stdin rather than exposing it in a process argument list.
		if ! printf '%s' "$api_key" | runuser --user dbai-hermes -- env HOME="$HERMES_HOME" python3 -c '
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
key = sys.stdin.read().strip()
if not re.fullmatch(r"[A-Za-z0-9_.-]{8,512}", key):
    raise SystemExit("API key has an unsupported format.")
path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
lines = [line for line in lines if not line.startswith("DBAI_9ROUTER_API_KEY=")]
lines.append("DBAI_9ROUTER_API_KEY=" + key)
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
path.chmod(0o600)
' "$HERMES_HOME/.hermes/.env"; then
			echo "Could not store the API key in Hermes' private environment file." >&2
			exit 1
		fi
		as_hermes_config "providers.dbai-9router.api" "http://127.0.0.1:20128/v1"
		as_hermes_config "providers.dbai-9router.key_env" "DBAI_9ROUTER_API_KEY"
		as_hermes_config "model.provider" "custom:dbai-9router"
		as_hermes_config "model.default" "$model"
		chmod 0600 "$HERMES_HOME/.hermes/.env"
		chown dbai-hermes:dbai-hermes "$HERMES_HOME/.hermes/.env" "$HERMES_HOME/.hermes/config.yaml"
		touch "$HERMES_HOME/.dbai-model-configured"
		chown dbai-hermes:dbai-hermes "$HERMES_HOME/.dbai-model-configured"
		unset api_key models_json
		echo "Hermes is now configured to use local 9Router at http://127.0.0.1:20128/v1."
		echo "Run 'hermes' to start chatting."
		exit 0
		;;
	"") ;;
	*)
		echo "Usage: sudo dbai-ai-setup [--connect-hermes|--update-router]"
		exit 2
		;;
esac

echo
echo "=== DBAI AI Stack ==="
echo "Mode: $MODE"
if [[ -e /var/lib/dbai-ai-stack/firstboot-complete ]]; then
	echo "First-boot installation: complete"
else
	echo "First-boot installation: pending or retrying"
	echo "Status:      sudo systemctl status dbai-ai-stack-firstboot.service"
	echo "Logs:        sudo journalctl -u dbai-ai-stack-firstboot.service -n 100 --no-pager"
	echo "Install log: sudo tail -n 100 /var/log/dbai-ai-stack-install.log"
fi

if [[ "$MODE" == "9router" || "$MODE" == "both" ]]; then
	ip_addr="$(find_ip)"
	if [[ -n "$ip_addr" ]]; then
		echo "9Router dashboard: http://$ip_addr:20128/dashboard"
		echo "9Router API:       http://$ip_addr:20128/v1"
	else
		echo "9Router dashboard: http://<device-IP>:20128/dashboard"
		echo "9Router API:       http://<device-IP>:20128/v1"
	fi
	if [[ -s "$ROUTER_ENV" ]]; then
		initial_password="$(sed -n 's/^INITIAL_PASSWORD=//p' "$ROUTER_ENV" | head -n 1)"
		printf 'Initial dashboard password: %s\n' "$initial_password"
		echo "Log in, connect a provider, create an API key in Settings / API Keys, and change the initial password."
		echo "The dashboard uses HTTP on your trusted LAN. Do not forward port 20128 directly to the internet; use a VPN or authenticated HTTPS reverse proxy for remote access."
	else
		echo "The random initial dashboard password will be generated by the first-boot service."
	fi
fi

if [[ "$MODE" == "hermes" || "$MODE" == "both" ]]; then
	echo
	echo "Hermes command: hermes"
	echo "The first 'hermes' invocation opens an interactive provider/model picker."
	if [[ "$MODE" == "both" ]]; then
		echo "For Hermes to use 9Router, connect a provider and create a 9Router API key first, then run:"
		echo "  sudo dbai-ai-setup --connect-hermes"
	fi
fi
echo
echo "9Router updates: sudo dbai-ai-setup --update-router (9Router images only)."
DBAI_AI_SETUP
	run_host_command_logged chmod 0755 "${SDCARD}/usr/local/sbin/dbai-ai-setup"

	cat > "${SDCARD}/etc/update-motd.d/98-dbai-ai-stack" <<'DBAI_AI_MOTD'
#!/bin/sh
mode="$(cat /etc/dbai/ai-stack-mode 2>/dev/null || true)"
[ -n "$mode" ] || exit 0
printf '\nDBAI AI firmware (%s)\n' "$mode"
if [ -e /var/lib/dbai-ai-stack/firstboot-complete ]; then
	printf 'Setup/status: run sudo dbai-ai-setup\n'
else
	printf 'First-boot setup is automatic; status/details: sudo dbai-ai-setup\n'
fi
case "$mode" in
	hermes|both) printf 'AI agent: run hermes (first run guides provider/model setup)\n' ;;
esac
case "$mode" in
	9router|both) printf '9Router dashboard: http://<device-IP>:20128/dashboard\n' ;;
esac
DBAI_AI_MOTD
	run_host_command_logged chmod 0755 "${SDCARD}/etc/update-motd.d/98-dbai-ai-stack"

	cat > "${SDCARD}/etc/systemd/system/dbai-ai-stack-firstboot.service" <<'DBAI_AI_SERVICE'
[Unit]
Description=DBAI AI stack first-boot provisioning (Hermes Agent / 9Router)
Wants=network-online.target
After=network-online.target
ConditionPathExists=!/var/lib/dbai-ai-stack/firstboot-complete
StartLimitIntervalSec=0

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/dbai-ai-stack-firstboot
TimeoutStartSec=0
Restart=on-failure
RestartSec=60s

[Install]
WantedBy=multi-user.target
DBAI_AI_SERVICE
	run_host_command_logged chmod 0644 "${SDCARD}/etc/systemd/system/dbai-ai-stack-firstboot.service"
	ln -sfn ../dbai-ai-stack-firstboot.service "${SDCARD}/etc/systemd/system/multi-user.target.wants/dbai-ai-stack-firstboot.service"

	cat > "${SDCARD}/opt/dbai-ai-stack/README.txt" <<'DBAI_AI_README'
DBAI AI firmware first steps
============================

No provider credentials are embedded in the firmware. At first boot, the AI stack
installs automatically and keeps user data/configuration across reboots.

1. Finish normal Armbian first-login/network setup and make sure the device has internet.
2. Run: sudo dbai-ai-setup
   - On 9Router images this shows the dashboard URL and the randomly generated initial password.
   - Log in, connect an AI provider, create a 9Router API key, and change the initial password.
3. Hermes-only: run "hermes" and use the guided provider/model picker.
4. Hermes + 9Router: create the 9Router API key first, then run "sudo dbai-ai-setup --connect-hermes".
   The helper lists available model IDs and configures Hermes to use the local router endpoint.
5. 9Router updates: sudo dbai-ai-setup --update-router

9Router dashboard: http://<device-IP>:20128/dashboard
OpenAI-compatible endpoint: http://<device-IP>:20128/v1
Do not forward port 20128 directly to the internet; use a VPN or authenticated reverse proxy for remote access.

Diagnostics:
  sudo systemctl status dbai-ai-stack-firstboot.service
  sudo journalctl -u dbai-ai-stack-firstboot.service -n 100 --no-pager
  sudo tail -n 100 /var/log/dbai-ai-stack-install.log
DBAI_AI_README
	run_host_command_logged chmod 0644 "${SDCARD}/opt/dbai-ai-stack/README.txt"

	if [[ "${DBAI_AI_STACK_MODE}" == "9router" || "${DBAI_AI_STACK_MODE}" == "both" ]]; then
		cat > "${SDCARD}/opt/dbai-ai-stack/compose.yaml" <<'DBAI_AI_COMPOSE'
services:
  router:
    image: ghcr.io/decolua/9router:latest
    container_name: dbai-9router
    restart: unless-stopped
    env_file:
      - /etc/dbai/9router.env
    ports:
      - "20128:20128"
    volumes:
      - dbai_9router_data:/app/data
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  dbai_9router_data:
DBAI_AI_COMPOSE
		run_host_command_logged chmod 0644 "${SDCARD}/opt/dbai-ai-stack/compose.yaml"
	fi

	run_host_command_logged chmod 0755 "${SDCARD}/usr/local/sbin/dbai-ai-stack-firstboot"
	run_host_command_logged chmod 0644 "${SDCARD}/opt/dbai-ai-stack/README.txt"
	display_alert "DBAI AI stack prepared; first boot installs software and generates credentials securely" "${EXTENSION}" "info"
}
