# MediaRemote Adapter — provenance

## Upstream

- URL: https://github.com/ungive/mediaremote-adapter
- Vendored commit: `0e82bf1c44ec39554fbfc402ec88a48c6ae2a0fd`
  (`0e82bf1`, 2026-10-17, "Sort projects alphabetically")
- License: BSD 3-Clause. See `LICENSE`.
  Copyright (c) 2025, Jonas van den Berg and contributors.

## What BilouNook uses

BilouNook uses the Perl CLI and the helper framework, not the upstream build
system:

- `bin/mediaremote-adapter.pl` — the CLI script.
- `include/MediaRemoteAdapter.h` — the adapter API used when building the
  framework.
- `src/adapter/*.m`, `src/private/MediaRemote.m`, `src/utility/*.m` — compiled
  by `scripts/build-mediaremote-adapter.sh` into
  `Vendor/MediaRemoteAdapter/build/MediaRemoteAdapter.framework`.
- `scripts/prepare-nowplaying-runtime.sh` copies the script and the built
  framework into the app's `NowPlaying` resources.

`Vendor/MediaRemoteAdapter/build/` is generated and ignored by git.

## Provenance check

On 2026-10-30 the upstream repository was cloned into the ignored
`build/vendor-check/` directory, checked out at the vendored commit, and
compared with:

    diff -r --exclude=.git --exclude=.gitmodules --exclude=build \
      Vendor/MediaRemoteAdapter build/vendor-check

Result: exit 0, no differences. The local `build/` directory was excluded
because it is generated, not vendored.

## How to update

1. Clone upstream into a temporary directory and check out the target commit.
2. Copy the tracked source and script files into `Vendor/MediaRemoteAdapter/`
   (everything except upstream `.git` and generated build output).
3. Update the commit hash in this file.
4. Rebuild the framework: `scripts/build-mediaremote-adapter.sh`.
5. Run `./scripts/smoke.sh` and the app-level `--smoke-test` and
   `--notch-selfcheck` flags.
