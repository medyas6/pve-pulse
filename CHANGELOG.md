# Changelog

## 1.0.0 - 2026-10-14

First release. Everything below is new, obviously.

- terminal UI with numbered menus, no dependencies beyond bash
- three backends: local (qm/pct), Proxmox API via token, demo with fake data
- guest list with --json output for scripting
- start/stop/restart, IP lookup, console attach
- snapshot list/create/rollback/delete with confirmation
- VM/CT creation wizard (builds the qm/pct command, shows preview, asks first)
- backup list + run-vzdump-now + scheduling hints
- node dashboard with usage bars
- bulk start-all/stop-all (typed YES confirmation)
- every action logged to ~/.local/share/pve-pulse/actions.log

### Fixed

- menu loop on empty input (just redraws instead of erroring)
- json escaping in --json output for names with quotes
- quoted --boot order properly in the vm wizard (was splitting the command)
