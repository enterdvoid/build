# @description Apply DBAI-2K26 identity to /etc/os-release while preserving the Debian release fields.

function post_family_tweaks__500_dbai_os_release() {
	local os_release="${SDCARD}/etc/os-release"
	local pretty_name="DBAI-2K26 ${RELEASE}"

	if [[ ! -f "${os_release}" ]]; then
		exit_with_error "DBAI branding" "Expected file not found: ${os_release}"
	fi

	# Armbian's generated base-files package writes PRETTY_NAME with the
	# image revision. Replace only the two display-name fields; preserve NAME,
	# VERSION_ID, VERSION, VERSION_CODENAME, ID, and URL fields from Debian.
	for key in PRETTY_NAME ARMBIAN_PRETTY_NAME; do
		if grep -q "^\${key}=" "${os_release}"; then
			sed -i "s|^\${key}=.*|\${key}=\"${pretty_name}\"|" "${os_release}"
		else
			printf '%s="%s"\n' "${key}" "${pretty_name}" >> "${os_release}"
		fi
	done

	display_alert "Applied DBAI OS branding" "${pretty_name}" "info"
}
