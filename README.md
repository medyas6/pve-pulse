# pve-pulse

```
 ____   __   __  _____        ____  _   _ _     ____  _____
|  _ \  \ \ / / | ____|      |  _ \| | | | |   / ___|| ____|
| |_) |  \ V /  |  _|   _____| |_) | | | | |   \___ \|  _|
|  __/    | |   | |___ |_____|  __/| |_| | |___ ___) | |___
|_|       |_|   |_____|      |_|    \___/|_____|____/|_____|
```

A small terminal UI for managing a Proxmox VE homelab: list VMs and
containers, start/stop/restart them, manage snapshots, run backups, spin up
new guests with a wizard, and see a node dashboard. Pure bash, no
dependencies.

I built pve-pulse because I wanted a simple way to manage my Proxmox homelab
from the terminal without opening the web UI for every little thing. It
started as a weekend project while studying for my infrastructure diploma.

Inspired by [proxmox-manager](https://github.com/TimInTech/proxmox-manager)
by TimInTech — I liked the idea and reimplemented it my own way, as a set of
small modules instead of one big script, with a demo mode so you can try
everything without a server.

![pve-pulse demo](demo.gif)

## Features

| # | Menu entry | What it does |
|---|-----------|--------------|
| 1 | List guests | table of all VMs/CTs with status, resources, IPs |
| 2 | Guest actions | start / stop / restart / show IPs / open console |
| 3 | Snapshots | list, create, rollback, delete (with confirmation) |
| 4 | Create VM/CT wizard **(new)** | interactive `qm create` / `pct create` builder with preview |
| 5 | Backups **(new)** | list vzdump archives, backup a guest now, scheduling hints |
| 6 | Node dashboard **(new)** | hostname, uptime, CPU/RAM/disk bars, guest counts |
| 7 | Bulk actions **(new)** | start-all / stop-all with typed confirmation |
| 8 | View action log | every action is logged with a timestamp |
| 9 | Settings | show active backend and config location |

Also: `--json` prints the guest list as JSON (handy for scripts),
`--demo` runs everything against fake data.

## Install

```bash
git clone https://github.com/medyas6/pve-pulse.git
cd pve-pulse
./install.sh            # installs to ~/.local/bin
pve-pulse --demo        # safe mode, try everything
```

Or run it straight from the repo:

```bash
./pve-pulse.sh --demo
```

`--system` installs to `/usr/local/bin` instead (needs sudo):

```bash
sudo ./install.sh --system
```

## Backends

pve-pulse talks to Proxmox in three ways. It picks one automatically,
or you can force it with `PVE_BACKEND` in the config file.

- **local** — you're on the Proxmox node itself, it just calls
  `qm`, `pct`, `pvesh` and `vzdump`. This is the backend with the most
  features (wizard, console attach, real backups).
- **api** — talks to `https://PVE_HOST:8006` with an API token.
  Set `PVE_HOST`, `PVE_TOKEN` and `PVE_NODE` in
  `~/.config/pve-pulse/config` (see `config.example`). Guest *creation*
  isn't implemented for this backend yet.
- **demo** — fake dataset (2 nodes, 6 VMs, 4 CTs, snapshots, backups).
  Every write action prints `[DEMO] simulated` instead of doing anything.
  Force it with `--demo`.

Config lives at `~/.config/pve-pulse/config`, actions are logged to
`~/.local/share/pve-pulse/actions.log`.

## Example session

```
$ ./pve-pulse.sh --demo

 == Main menu ==  [demo backend]

   1) List guests
   2) Guest actions (start/stop/console/...)
   3) Snapshots
   4) Create VM/CT wizard
   5) Backups
   6) Node dashboard
   7) Bulk actions
   8) View action log
   9) Settings
   0) Quit

choice > 1

ID   TYPE  NAME        STATUS   NODE      CPUs  RAM MB  DISK GB  IP
---  ----  ----------  -------  --------  ----  ------  -------  -------------
100  vm    web-prod    running  pve-lab   4     8192    60       192.168.1.10
101  vm    db-main     running  pve-lab   8     16384   120      192.168.1.11
102  vm    win-test    stopped  pve-lab   4     8192    80       -
...

Total: 10 guests (7 running, 3 stopped)
```

```bash
$ ./pve-pulse.sh --demo --json | head -5
[
  {"type":"vm","vmid":"100","name":"web-prod","status":"running","node":"pve-lab","cpus":"4","ram_mb":"8192","disk_gb":"60","ip":"192.168.1.10"},
  ...
]
```

## Limitations (honest ones)

- The **api backend is basic**: listing, power actions, snapshots and
  backups work, but guest creation doesn't yet, and it shells out to
  `python3` for JSON parsing.
- Tested mostly in **demo mode and local mode** — I don't have a
  cluster to test HA or multi-node quirks against.
- Console attach only works on the local backend (`qm terminal` /
  `pct enter`); over API it just points you at the web UI.
- `local_backup_list` guesses the dump directory instead of reading
  `storage.cfg` (there's a TODO in the code).

## Roadmap

- guest creation over the API backend
- Proxmox Backup Server (PBS) datastore support
- a `--watch` mode that refreshes the dashboard every few seconds
- maybe a simple `pve-pulse top`-style live view, if I find the time

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE). Copyright 2026 Mohamed Yassine.
