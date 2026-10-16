# DBAI Unified Builder — Architecture Plan

Status: design baseline; not yet implemented as a dedicated repository.

## 1. Goal

Create a standalone DBAI builder repository that downloads a pinned revision of the official Armbian build framework at runtime, overlays DBAI-maintained extensions, and builds images in one pipeline. Do not make a completed official image and then pass it through the ophub repacker as the main workflow.

The official Armbian build framework remains the base. ophub code and device database are treated as upstream components to audit, adapt, and version separately. Preserve provenance and licenses for every imported component.

## 2. Repository boundaries

Proposed repository: `enterdvoid/dbai-unified-builder`.

- `.github/workflows/dbai-build.yml`: manual UI-driven build workflow.
- `.github/workflows/dbai-backup.yml`: source and Git history backup.
- `.github/workflows/dbai-validate.yml`: static validation and image sanity checks.
- `config/boards/board-catalog.json`: curated board choices and exact Armbian board IDs.
- `config/kernels/kernel-inputs.json`: official-vs-custom kernel policy and four custom-kernel input slots.
- `config/apps/`: application compatibility declarations and installation hooks.
- `ophub/patches/` and `ophub/database/`: adapted scripts/database, with upstream revision and license notices.
- `extensions/dbai/`: Armbian extension and hook integration.
- `scripts/`: source checkout, preflight, kernel installation, image validation, manifest, and release tooling.
- `docs/`: architecture, supported boards, kernel format, build and recovery guides.

## 3. Source acquisition and reproducibility

1. Fetch official `armbian/build` at an explicit ref or commit; do not silently follow a moving branch in production builds.
2. Fetch or vendor the selected ophub scripts/database at an explicit commit.
3. Apply DBAI extensions as a separate overlay rather than rewriting upstream source indiscriminately.
4. Record all source URLs, commit IDs, kernel identity, selected board, release, filesystem, applications, and build parameters in the output manifest.
5. Keep source downloads, caches, and output artifacts separate so failed builds can be diagnosed and repeated.

## 4. Board picker

The workflow UI should have a `board` choice followed immediately by a `custom_board_name` text input. GitHub Actions does not dynamically hide/show inputs, so the help text must say: fill in the text field only when `board=custom`. When a predefined board is selected, ignore the custom text field.

Initial curated choices:

- `aml-s9xx-box` — DBAI/ophub Amlogic TV-box target; not present as a standard `config/boards/*.conf` file in current upstream Armbian and must use the dedicated compatibility path.
- `orangepi5-plus`
- `orangepi5`
- `orangepi3-lts`
- `odroidn2`
- `odroidm1`
- `odroidc4`
- `khadas-vim4`
- `nanopi-r4s`
- `bananapim5`
- `rock-5b`

The ten SBC identifiers above were checked against the current upstream `armbian/build/config/boards/` directory. They are an initial curated menu, not a promise that every release, desktop, kernel mode, or application is supported on every board. The build must validate the selected board against the chosen source revision before compiling. `custom` accepts a user-supplied exact board identifier; the user is responsible for finding the correct name, and the workflow should fail early with a useful list of available identifiers when it is invalid.

## 5. Optional kernel policy

Expose a choice: `official` (default) or `custom-four-part`.

- `official`: use the normal kernel and boot-artifact flow for the selected Armbian board. Do not require custom kernel files.
- `custom-four-part`: require all four custom kernel inputs matching the established ophub-style format. Their exact filenames and semantics must be confirmed from the user's real artifacts before implementing extraction.
- Preflight must reject missing, empty, malformed, or incompatible parts before the expensive image build.
- The integration layer must map the four inputs to their actual roles only after inspection; do not infer roles from filenames alone.
- Validate kernel release/configuration, module `vermagic`, architecture, DTB availability, firmware, headers, initramfs (if used), and boot configuration.
- Skip or override official kernel package installation only at a verified Armbian extension/hook point. Do not disable unrelated bootloader, partitioning, rootfs, image-finalization, or compression stages.
- The final image manifest must say whether official or custom kernel mode was used.

## 6. Image and filesystem policy

Keep the official build pipeline responsible for image layout and final assembly. Apply DBAI changes at the earliest supported hook where required files and target rootfs are available. Prefer in-rootfs package/configuration hooks for OS customizations and a narrowly scoped final-image hook only for changes that truly require mounted partitions.

Use copy-on-write or a fresh build output for every attempt. Never mutate the only copy of a source image. Mount read-write only when the relevant image stage requires it; flush writes and unmount before validating image metadata and checksums.

## 7. Ready-to-use application profiles

Application integration should be modular and architecture-aware, with choices such as:

- Core server utilities and Docker
- Hermes
- 9Router
- Hermes + 9Router
- Home Assistant
- OpenMediaVault
- CasaOS
- LightNVR + go2rtc
- Proxmox-related tools/images only where the target architecture and deployment model are genuinely supported

Do not claim that Proxmox VE is installable as a native supported package on every ARM SBC. Separate x86 VM images, ARM SBC packages, and containerized services in the UI. Each app declares supported architecture, OS release, board constraints, installation stage, first-boot actions, health checks, and known conflicts. Optional app failures should be explicit and must not silently produce a supposedly ready-to-use image.

## 8. Release and validation

Before release:

- Verify the build command completed successfully.
- Inspect image/partition layout and expected boot files.
- Verify the chosen kernel mode and required kernel artifacts.
- Run filesystem checks where safely supported.
- Generate SHA-256 checksums and a JSON manifest.
- Include concise logs and build provenance; do not upload secrets or tokens.
- Publish assets only after local validation passes. If publishing fails after creating a release/tag, delete the partial release and tag.

## 9. Implementation order

1. Finish and verify the backup release in the existing `enterdvoid/build` repository.
2. Create the dedicated `enterdvoid/dbai-unified-builder` repository.
3. Add source acquisition, board picker, and official-kernel-only baseline.
4. Validate one supported Armbian SBC and the `aml-s9xx-box` compatibility path separately.
5. Inspect the real four kernel artifacts and implement custom mode behind an optional input.
6. Integrate ophub scripts/database with provenance and license checks.
7. Add application profiles one by one with compatibility validation.
8. Expand the board/application matrix only after successful smoke tests.

## 10. Known external prerequisites

- The backup workflow requires a repository Actions secret named `DBAI_RELEASE_TOKEN` because the default Actions token in the initial test was denied permission to create GitHub Releases.
- The current GitHub integration can modify existing repositories but does not expose a repository-creation action. The dedicated repository must first be created in GitHub (or created through an authenticated bootstrap workflow with a suitable token).
- No kernel artifacts have been inspected in this task yet; custom-kernel mode must remain optional and should not be enabled by default.
