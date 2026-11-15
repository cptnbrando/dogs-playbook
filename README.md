<h1 align="center">

Dogs Playbook 🐕

</h1>

Dogs Playbook is an [AME Wizard](https://amelabs.net) playbook for debloating and
hardening a fresh Windows 10/11 install, built to work **fully offline**. It is
the debloat layer of [Phoenix](https://github.com/cptnbrando/phoenix): Phoenix's
answer file gets a wiped machine to the desktop, and this playbook strips what
the answer file can't.

It is a fork of the [ReviOS Playbook](https://github.com/meetrevision/playbook)
by Revision, with an offline build mode added.

## ✨ Features

- 🎯 Drag and drop the `.apbx` into [AME Wizard](https://amelabs.net)
- ✈️ Offline build: every installer is bundled, nothing is downloaded during the run
- 🗑 Removes bloatware and unnecessary system components
- ⚡ Optimizes for performance and privacy
- 🔧 Installs the [Revision Tool](https://github.com/meetrevision/revision-tool) for further tweaks
- 🧪 Optional, off by default: **GPU tensor unlock check** (see below)

## 💻 System requirements

Same as upstream ReviOS: AMD64 and ARM64 builds of Windows 10 `19044`/`19045`
and Windows 11 `22631`/`26100`/`26200`. The offline build does not enforce the
build list.

## 🚀 Build and run

Requires [7-Zip](https://www.7-zip.org/) on `PATH`.

```powershell
./build.ps1          # answer "y" for the offline build
```

`y` runs `src/Executables/Offline/getapps.ps1` once to download the bundled
installers, then produces `dogs-playbook.apbx`. Drag it into AME Wizard.

> [!CAUTION]
> Start from a fresh, stock Windows install. AME Wizard will flag this playbook
> as unverified because it is a modified fork; that is expected.

## 🧪 GPU tensor unlock check (optional)

[gpu-unlock](https://github.com/Zagitta/gpu-unlock) removes the half-rate cap
NVIDIA puts on FP16/BF16/TF32 tensor math on GeForce RTX 20/30/40 cards. It is
a **Linux** kernel module. On Windows the only route is an experimental UEFI
port, [Windows-GPU-UNLOCK](https://github.com/impacifist/Windows-GPU-UNLOCK),
which needs Secure Boot off, BitLocker off and a separate EFI partition, and
has success reports only for specific desktop RTX 30 setups.

Neither can be applied safely from inside a playbook, so the option
**"Check GPU tensor unlock support (read-only)"** only reports where you stand.
It changes nothing and uses no network. It writes:

- `%SystemDrive%\DogsPlaybook\GPU-UNLOCK\report.txt` and `report.json`
- `%PUBLIC%\Desktop\GPU-Unlock-Report.txt`

Each NVIDIA GPU gets one verdict: `not-supported`, `linux-only`, or
`windows-port-candidate` (desktop Ampere only). Laptops get a warning, because
the unlock resets every time the dGPU powers down.

The device list comes from a pinned upstream snapshot in
[`third_party/gpu-unlock`](third_party/gpu-unlock/UPSTREAM.md). That snapshot is
reference only and is not packed into the `.apbx`. To refresh it:

```powershell
./tools/Update-GpuUnlock.ps1            # pin upstream main, regenerate the table
./tools/Update-GpuUnlock.ps1 -SkipDownload   # regenerate from the current snapshot
```

## 📝 License

[![License](https://img.shields.io/static/v1?label=LICENSE&message=CC%20BY-SA&logo=creativecommons)](https://creativecommons.org/licenses/by-sa/4.0/)

Dogs Playbook is licensed under
[Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/),
as is the [ReviOS Playbook](https://github.com/meetrevision/playbook) it is
adapted from (© Revision). Changes: rebranding, offline build mode, and the
optional GPU unlock check.

`third_party/gpu-unlock` is a separate work under GPL-2.0-only, included
unmodified with its own license files.

> [!NOTE]
> This is a personal fork. Don't take issues with it to Revision.
