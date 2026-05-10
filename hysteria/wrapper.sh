#!/usr/bin/env bash

UDP_PORT_START=20000
UDP_PORT_END=30000
REDIRECT_PORT=4430
HYSTERIA_BIN="/usr/local/bin/hysteria"
CONFIG_FILE="/etc/hysteria/config.yaml"

# Check if nftables is available
USE_NFT=false
if command -v nft >/dev/null 2>&1; then
    USE_NFT=true
fi

start_rules() {
    if [ "$USE_NFT" = true ]; then
        # Create table and chain if not exists
        nft add table inet hysteria_nat
        nft add chain inet hysteria_nat prerouting { type nat hook prerouting priority dstnat \; }
        # Add IPv4 and IPv6 redirect rules
        nft add rule inet hysteria_nat prerouting udp dport $UDP_PORT_START-$UDP_PORT_END redirect to :$REDIRECT_PORT
    else
        # Fallback to iptables (IPv4)
        iptables -t nat -A PREROUTING -p udp --dport $UDP_PORT_START:$UDP_PORT_END -j REDIRECT --to-ports $REDIRECT_PORT
        # Fallback to ip6tables (IPv6)
        ip6tables -t nat -A PREROUTING -p udp --dport $UDP_PORT_START:$UDP_PORT_END -j REDIRECT --to-ports $REDIRECT_PORT
    fi
}

stop_rules() {
    if [ "$USE_NFT" = true ]; then
        nft delete table inet hysteria_nat 2>/dev/null
    else
        # Clean IPv4 rules
        while iptables -t nat -D PREROUTING -p udp --dport $UDP_PORT_START:$UDP_PORT_END -j REDIRECT --to-ports $REDIRECT_PORT 2>/dev/null; do :; done
        # Clean IPv6 rules
        while ip6tables -t nat -D PREROUTING -p udp --dport $UDP_PORT_START:$UDP_PORT_END -j REDIRECT --to-ports $REDIRECT_PORT 2>/dev/null; do :; done
    fi
}

case "$1" in
start)
    stop_rules
    start_rules
    exec $HYSTERIA_BIN server -c $CONFIG_FILE
    ;;
stop)
    stop_rules
    ;;
*)
    echo "Usage: $0 {start|stop}"
    exit 1
    ;;
esac
