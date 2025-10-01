apt update
apt install -y arp-scan

#!/usr/bin/env bash
set -euo pipefail

NETWORK="192.168.100.0/24"    # Adjust to your VM subnet
ARP_INTERFACE="vmbr0"         # Proxmox bridge interface

declare -A mac_to_info   # mac -> "vmid,name,status"

echo "Collecting VM MAC addresses locally from this Proxmox host..."

# Get all VMs (not just running), with status, name, and ID
qm list 2>/dev/null | awk 'NR>1 {print $1","$2","$3}' > vm_list.txt

if [[ ! -s vm_list.txt ]]; then
  echo "No VMs found on this Proxmox host"
  exit 1
fi

# Get MACs for each VM
while IFS=',' read -r vmid vmname status; do
  net_lines=$(qm config "${vmid}" 2>/dev/null | grep -i '^net[0-9]')
  if [[ -z "$net_lines" ]]; then
    echo "  VM $vmid ($vmname) has no network interfaces."
    continue
  fi

  while IFS= read -r line; do
    macaddr=$(echo "$line" | sed -n 's/.*=\([0-9A-Fa-f:]\{17\}\).*/\1/p')
    if [[ -n "$macaddr" ]]; then
      mac_lc=$(echo "$macaddr" | tr 'A-F' 'a-f')
      mac_to_info["$mac_lc"]="$vmid,$vmname,$status"
    fi
  done <<< "$net_lines"
done < vm_list.txt

if [[ ${#mac_to_info[@]} -eq 0 ]]; then
  echo "No MAC addresses collected from VMs on this Proxmox host"
  exit 1
fi

echo
echo "Scanning network $NETWORK on interface $ARP_INTERFACE with arp-scan..."
arp_results=$(arp-scan --interface="$ARP_INTERFACE" "$NETWORK" 2>/dev/null || true)

# Parse arp-scan output and map MAC to IP
declare -A mac_to_ip
while read -r ip mac rest; do
  [[ -z "$ip" || -z "$mac" ]] && continue
  mac_lc=$(echo "$mac" | tr 'A-F' 'a-f')

  if [[ "$mac_lc" =~ ^([0-9a-f]{2}:){5}[0-9a-f]{2}$ ]]; then
    mac_to_ip["$mac_lc"]="$ip"
  fi
done <<< "$(echo "$arp_results" | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $1, $2}')"

echo
printf "%-6s %-30s %-18s %-17s %s\n" "VMID" "Name" "MAC" "IP" "Status"
printf "%-6s %-30s %-18s %-17s %s\n" "-----" "----" "----" "--" "------"

output_lines=()

for mac in "${!mac_to_info[@]}"; do
  IFS=',' read -r vmid vmname status <<< "${mac_to_info[$mac]}"
  ip="${mac_to_ip[$mac]:-N/A}"
  output_lines+=("$vmid|$vmname|$mac|$ip|$status")
done

# Sort and print
for line in $(printf '%s\n' "${output_lines[@]}" | sort -n -t'|' -k1); do
  IFS='|' read -r vmid vmname mac ip status <<< "$line"
  printf "%-6s %-30s %-18s %-17s %s\n" "$vmid" "$vmname" "$mac" "$ip" "$status"
done
