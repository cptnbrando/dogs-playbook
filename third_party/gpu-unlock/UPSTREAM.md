# Vendored upstream: gpu-unlock

- Source: https://github.com/Zagitta/gpu-unlock
- Commit: `7eb51bccae0a0b7e599e084d971170e9a1e82d0c`
- Fetched: 2026-11-14
- License: GPL-2.0-only (see `licenses/` and `firmware/NOTICE.md` in this folder)

This folder is an unmodified snapshot, kept for reference and auditing. It is
a **Linux** kernel module: nothing here runs on Windows, and nothing here is
packed into the playbook `.apbx`. The playbook only ships
`src/Executables/GPU-UNLOCK/supported-devices.json`, generated from
`kernel/gpu_unlock/recipes.c` by `tools/Update-GpuUnlock.ps1`.

Do not edit files in this folder; re-run the updater instead.
