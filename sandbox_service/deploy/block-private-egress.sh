#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${1:-link-scanner-chromium-sandbox}"
IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER")"
if [[ -z "$IP" ]]; then
  echo "Could not determine container IP. Start the Compose service first." >&2
  exit 1
fi
if ! iptables -nL DOCKER-USER >/dev/null 2>&1; then
  echo "DOCKER-USER chain is unavailable; enable Docker's iptables integration before exposing this scanner." >&2
  exit 1
fi

# Defense in depth against DNS rebinding and browser requests to private networks.
# Re-run after the container is recreated because Docker may assign a new IP.
for CIDR in \
  0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 \
  172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.168.0.0/16 \
  192.88.99.0/24 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4; do
  iptables -C DOCKER-USER -s "$IP" -d "$CIDR" -j DROP 2>/dev/null || \
    iptables -I DOCKER-USER 1 -s "$IP" -d "$CIDR" -j DROP
done

IP6="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPv6Address}}{{end}}' "$CONTAINER")"
if [[ -n "$IP6" ]]; then
  if ! command -v ip6tables >/dev/null 2>&1 || ! ip6tables -nL DOCKER-USER >/dev/null 2>&1; then
    echo "Container has IPv6 ($IP6) but the IPv6 DOCKER-USER chain is unavailable; disable IPv6 egress or configure equivalent IPv6 filtering." >&2
    exit 1
  fi
  # Block both the local-use and well-known NAT64 prefixes. The latter can
  # otherwise translate an apparently global IPv6 destination into private IPv4.
  for CIDR in ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8 100::/64 64:ff9b::/96 64:ff9b:1::/48 2001::/23 2001:db8::/32 2002::/16; do
    ip6tables -C DOCKER-USER -s "$IP6" -d "$CIDR" -j DROP 2>/dev/null || \
      ip6tables -I DOCKER-USER 1 -s "$IP6" -d "$CIDR" -j DROP
  done
fi

echo "Private/reserved IPv4 egress blocked for container $CONTAINER ($IP)."
if [[ -n "$IP6" ]]; then echo "Private/reserved IPv6 egress blocked for $IP6."; else echo "Container has no global IPv6 address."; fi
