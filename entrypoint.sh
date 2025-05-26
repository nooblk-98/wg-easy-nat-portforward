#!/bin/bash

# External interface
EXT_IFACE="eth0"

# VPN client IP inside container
VPN_CLIENT_IP="10.8.0.2"

# Read PORTS from the environment variable
IFS=',' read -ra PORTS_ARRAY <<< "$PORTS"

# Loop through each port and apply iptables rules
for PORT in "${PORTS_ARRAY[@]}"; do
    echo "Forwarding port $PORT..."

    iptables -t nat -A PREROUTING -i $EXT_IFACE -p tcp --dport $PORT -j DNAT --to-destination $VPN_CLIENT_IP:$PORT
    iptables -A FORWARD -p tcp -d $VPN_CLIENT_IP --dport $PORT -j ACCEPT

    echo "Forwarding UDP port $PORT..."
    iptables -t nat -A PREROUTING -i $EXT_IFACE -p udp --dport $PORT -j DNAT --to-destination $VPN_CLIENT_IP:$PORT
    iptables -A FORWARD -p udp -d $VPN_CLIENT_IP --dport $PORT -j ACCEPT
done

echo "✅ All port forwarding rules added."

# Optional message (if you have a terminal UI or output animation)
echo "🌐 WireGuard setup complete! Access at: http://$WG_HOST:51821"
echo "⚠️ Please create only one user to avoid conflicts."

# Start the Node.js server
exec /usr/bin/dumb-init node server/index.mjs
