# @description Builds a lightweight standalone Openbox X11 session with a graphical login, LXPanel application menu, PCManFM file manager, terminal, and NetworkManager tray. Used by the DBAI Armbian workflow as an independent WM variant rather than an Armbian configng desktop environment.

function extension_prepare_config__openbox() {
	case "${RELEASE}" in
		bullseye|bookworm|trixie|forky|jammy|noble|resolute)
			display_alert "Target image will have the lightweight Openbox window manager" "${RELEASE} ${EXTENSION}" "info"
			;;
		*)
			exit_with_error "Openbox WM is not configured for ${DISTRIBUTION} ${RELEASE}"
			;;
	esac

	EXTRA_IMAGE_SUFFIXES+=("-openbox")
}

function post_repo_customize_image__install_openbox_session() {
	display_alert "Installing Openbox standalone graphical session" "${EXTENSION}" "info"

	chroot_sdcard_apt_get_install \
		dbus-x11 \
		fonts-dejavu-core \
		lightdm \
		lightdm-gtk-greeter \
		lxappearance \
		lxpanel \
		lxpolkit \
		lxterminal \
		network-manager-gnome \
		openbox \
		pcmanfm \
		x11-xserver-utils \
		xinit \
		xserver-xorg

	# Keep the session lightweight while still providing a panel, app menu,
	# file-manager desktop, polkit agent, and NetworkManager tray applet.
	run_host_command_logged mkdir -p "${SDCARD}/etc/xdg/openbox"
	run_host_command_logged cat <<'OPENBOX_AUTOSTART' > "${SDCARD}/etc/xdg/openbox/autostart"
# DBAI Openbox standalone session
if command -v lxpanel >/dev/null 2>&1; then
	lxpanel --profile default &
fi
if command -v pcmanfm >/dev/null 2>&1; then
	pcmanfm --desktop --profile=openbox &
fi
if command -v lxpolkit >/dev/null 2>&1; then
	lxpolkit &
fi
if command -v nm-applet >/dev/null 2>&1; then
	nm-applet --indicator &
fi
OPENBOX_AUTOSTART
	run_host_command_logged chmod 0644 "${SDCARD}/etc/xdg/openbox/autostart"

	display_alert "Openbox session installed; select Openbox at the LightDM login screen" "${EXTENSION}" "info"
}
