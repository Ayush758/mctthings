#!/usr/bin/env bash
set -euo pipefail

NETWORK="192.168.100.0/24"
ARP_INTERFACE="vmbr0"

declare -A mac_to_info   # mac -> "vmid,name,status,ram,cores,os"

echo "Collecting VM info from this Proxmox host..."

qm list 2>/dev/null | awk 'NR>1 {print $1","$2","$3}' > vm_list.txt

if [[ ! -s vm_list.txt ]]; then
  echo "No VMs found on this Proxmox host"
  exit 1
fi

while IFS=',' read -r vmid vmname status; do
  config=$(qm config "${vmid}" 2>/dev/null)

  net_lines=$(echo "$config" | grep -i '^net[0-9]')
  if [[ -z "$net_lines" ]]; then
    echo "  VM $vmid ($vmname) has no network interfaces."
    continue
  fi

  ram=$(echo "$config" | awk -F ': ' '/^memory:/ {print $2}')
  cores=$(echo "$config" | awk -F ': ' '/^cores:/ {print $2}')
  ram="${ram:-N/A}"
  cores="${cores:-N/A}"

  # Try to get OS info
  if [[ "$status" == "running" ]]; then
    if os_info=$(qm guest cmd "$vmid" get-osinfo 2>/dev/null); then
      os=$(echo "$os_info" | jq -r 'if has("pretty-name") then .["pretty-name"] elif has("name") then .["name"] else "Unknown" end')
    else
      os="Agent not running"
    fi
  else
    os="VM is stopped"
  fi

  while IFS= read -r line; do
    macaddr=$(echo "$line" | sed -n 's/.*=\([0-9A-Fa-f:]\{17\}\).*/\1/p')
    if [[ -n "$macaddr" ]]; then
      mac_lc=$(echo "$macaddr" | tr 'A-F' 'a-f')
      mac_to_info["$mac_lc"]="$vmid,$vmname,$status,$ram,$cores,$os"
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

declare -A mac_to_ip
while read -r ip mac rest; do
  [[ -z "$ip" || -z "$mac" ]] && continue
  mac_lc=$(echo "$mac" | tr 'A-F' 'a-f')

  if [[ "$mac_lc" =~ ^([0-9a-f]{2}:){5}[0-9a-f]{2}$ ]]; then
    mac_to_ip["$mac_lc"]="$ip"
  fi
done <<< "$(echo "$arp_results" | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {print $1, $2}')"

echo
printf "%-6s %-30s %-18s %-17s %-7s %-5s %-30s %s\n" "VMID" "Name" "MAC" "IP" "RAM(MB)" "CPU" "OS" "Status"
printf "%-6s %-30s %-18s %-17s %-7s %-5s %-30s %s\n" "-----" "----" "----" "--" "-------" "----" "------------------------------" "------"

output_lines=()

for mac in "${!mac_to_info[@]}"; do
  IFS=',' read -r vmid vmname status ram cores os <<< "${mac_to_info[$mac]}"
  ip="${mac_to_ip[$mac]:-N/A}"
  output_lines+=("$vmid|$vmname|$mac|$ip|$ram|$cores|$os|$status")
done

for line in $(printf '%s\n' "${output_lines[@]}" | sort -n -t'|' -k1); do
  IFS='|' read -r vmid vmname mac ip ram cores os status <<< "$line"
  printf "%-6s %-30s %-18s %-17s %-7s %-5s %-30s %s\n" "$vmid" "$vmname" "$mac" "$ip" "$ram" "$cores" "$os" "$status"
done

