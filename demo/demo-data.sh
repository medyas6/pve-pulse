# pve-pulse - demo/demo-data.sh
# Realistic fake dataset used by the demo backend.
# Lets you explore every menu of pve-pulse without a Proxmox server.
#
# Guest record: type|vmid|name|status|node|cpus|ram_mb|disk_gb|ip|uptime_s
# Snapshot:     type/vmid|name|description|date
# Backup:       file|size|date
#
# Author: Mohamed Yassine (github.com/medyas6) - 2026
# License: MIT

[ -n "${_PVE_PULSE_DEMO_DATA_SH:-}" ] && return 0
_PVE_PULSE_DEMO_DATA_SH=1

# --- node info ----------------------------------------------------------------
DEMO_NODE_HOST="pve-lab"
DEMO_NODE_UPTIME=1048576        # ~12 days
DEMO_NODE_CPU=23
DEMO_NODE_RAM_USED=18432
DEMO_NODE_RAM_TOTAL=65536
DEMO_NODE_DISK_USED=412
DEMO_NODE_DISK_TOTAL=930

# --- guests: 6 VMs + 4 CTs across 2 nodes -------------------------------------
DEMO_GUESTS=(
  # type|vmid|name        |status |node    |cpu|ram  |disk|ip            |uptime
  "vm|100|web-prod     |running|pve-lab |4  |8192 |60  |192.168.1.10  |864000"
  "vm|101|db-main      |running|pve-lab |8  |16384|120 |192.168.1.11  |860000"
  "vm|102|win-test     |stopped|pve-lab |4  |8192 |80  |              |0"
  "vm|200|k3s-master   |running|pve-lab2|4  |8192 |40  |192.168.2.20  |432000"
  "vm|201|k3s-worker1  |running|pve-lab2|4  |8192 |40  |192.168.2.21  |432000"
  "vm|202|k3s-worker2  |stopped|pve-lab2|4 |8192 |40  |              |0"
  "ct|300|pihole       |running|pve-lab |1  |512  |4   |192.168.1.30  |900000"
  "ct|301|nfs-share    |running|pve-lab |2  |2048 |200 |192.168.1.31  |700000"
  "ct|302|docker-lab   |running|pve-lab2|4  |4096 |32  |192.168.2.30  |200000"
  "ct|303|old-test     |stopped|pve-lab2|1  |512  |8   |              |0"
)

# --- snapshots ----------------------------------------------------------------
DEMO_SNAPS=(
  "vm/100|before-update|before apt upgrade|2026-10-10 09:12"
  "vm/100|baseline|first clean install|2026-09-01 14:00"
  "vm/101|pre-migration|before moving to pve-lab2|2026-10-05 22:30"
  "ct/300|clean|fresh pihole install|2026-08-20 11:05"
  "ct/302|docker-ok|all containers running|2026-10-12 18:44"
)

# --- backups ------------------------------------------------------------------
DEMO_BACKUPS=(
  "vzdump-qemu-100-2026_10_13-02_00_00.vma.zst|18.2 GB|2026-10-13 02:00"
  "vzdump-qemu-101-2026_10_13-02_30_00.vma.zst|42.7 GB|2026-10-13 02:30"
  "vzdump-lxc-300-2026_10_13-03_00_00.tar.zst|1.1 GB|2026-10-13 03:00"
  "vzdump-lxc-301-2026_10_12-03_00_00.tar.zst|96.4 GB|2026-10-12 03:00"
  "vzdump-qemu-200-2026_10_11-02_00_00.vma.zst|9.8 GB|2026-10-11 02:00"
)
