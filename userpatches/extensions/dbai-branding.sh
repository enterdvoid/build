# @description Apply DBAI-2K26 identity to /etc/os-release while preserving the Debian release fields.

function post_family_tweaks__500_dbai_os_release() {
	local os_release="${SDCARD}/etc/os-release"
	local pretty_name="DBAI-2K26 ${RELEASE}"
	local firmware_repo_url="https://github.com/armarchindo/build"
	local armbian_release="${SDCARD}/etc/armbian-release"

	if [[ ! -f "${os_release}" ]]; then
		exit_with_error "DBAI branding" "Expected file not found: ${os_release}"
	fi

	# Armbian's generated base-files package writes PRETTY_NAME with the
	# image revision. Replace only the two display-name fields; preserve NAME,
	# VERSION_ID, VERSION, VERSION_CODENAME, ID, and URL fields from Debian.
	for key in PRETTY_NAME ARMBIAN_PRETTY_NAME; do
		if grep -q "^${key}=" "${os_release}"; then
			sed -i "s|^${key}=.*|${key}=\"${pretty_name}\"|" "${os_release}"
		else
			printf '%s="%s"\n' "${key}" "${pretty_name}" >> "${os_release}"
		fi
	done


	# The image should advertise the DBAI maintainer URL, while the actual source
	# checkout and GitHub Actions repository remain unchanged at enterdvoid/build.
	# This affects only the metadata files placed inside the firmware image.
	if [[ -f "${armbian_release}" ]]; then
		if grep -q '^BUILD_REPOSITORY_URL=' "${armbian_release}"; then
			sed -i "s|^BUILD_REPOSITORY_URL=.*|BUILD_REPOSITORY_URL=${firmware_repo_url}|" "${armbian_release}"
		else
			printf 'BUILD_REPOSITORY_URL=%s\\n' "${firmware_repo_url}" >> "${armbian_release}"
		fi
	else
		exit_with_error "DBAI branding" "Expected file not found: ${armbian_release}"
	fi

	# If the image snapshot file already exists at this stage, keep it consistent.
	local image_release="${SDCARD}/etc/armbian-image-release"
	if [[ -f "${image_release}" ]]; then
		sed -i "s|^BUILD_REPOSITORY_URL=.*|BUILD_REPOSITORY_URL=${firmware_repo_url}|" "${image_release}"
	fi

	display_alert "Applied DBAI OS branding" "${pretty_name}" "info"
}
