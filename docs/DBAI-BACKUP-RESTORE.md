# DBAI Repository Backup and Recovery

This document describes the backup workflow in `.github/workflows/dbai-backup.yml`.

## What it backs up

The workflow creates a versioned GitHub Release containing:

- `dbai-source-snapshot.tar.gz`: a snapshot of the checked-out repository, including documentation, workflows, patches, configuration, and tracked source files.
- `dbai-git-mirror.bundle`: a Git bundle containing all refs available to the mirror clone, preserving branches, tags, and reachable history.
- `release-metadata.json`: metadata for existing GitHub Releases and their assets (not the binary assets themselves).
- `tracked-files.txt`: a sorted list of files tracked by Git at the backed-up commit.
- `SHA256SUMS`: SHA-256 checksums for all backup artifacts.

The workflow does not include GitHub Actions secrets, environment secrets, external repository settings, runner caches, expired workflow artifacts, or existing release binaries. These are not part of the Git repository and must be backed up separately if required. Secrets must never be written into backup artifacts.

## Run

Open **Actions → DBAI Repository Backup → Run workflow**. Use the default settings for a complete repository backup.

The workflow is also configured to run when its workflow file is pushed to `main`, where GitHub permits the event to start a workflow. If a commit is made using a token that suppresses workflow-triggering events, manually run it from Actions.

## Validation and failure cleanup

Before publishing, the workflow verifies the gzip archive can be listed, verifies the Git bundle, and checks every generated artifact with SHA-256. It creates the release only after local validation passes. If release creation or asset upload leaves a partial release, the failure handler attempts to delete that release and its tag.

A successful workflow run and a visible release with all expected assets are required before treating the backup as verified.

## Restore

1. Download `dbai-git-mirror.bundle` and inspect it with `git bundle verify dbai-git-mirror.bundle`.
2. Clone the bundle with `git clone dbai-git-mirror.bundle dbai-build-restored`.
3. Download and extract `dbai-source-snapshot.tar.gz` when a plain source snapshot is more convenient.
4. Verify artifact integrity using `sha256sum -c SHA256SUMS`.

The mirror bundle is the preferred artifact for restoring Git history. The tarball is a convenient source snapshot, not a replacement for the bundle.
