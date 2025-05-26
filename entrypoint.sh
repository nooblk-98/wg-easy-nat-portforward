#!/bin/bash

#!/bin/bash

# Helper function to show animations
echo_with_animation() {
    local message=$1
    local delay=0.05
    for ((i=0; i<${#message}; i++)); do
        printf "%s" "${message:$i:1}"
        sleep $delay
    done
    printf "\n"
}

# Log everything for debugging
exec > >(tee -i /var/log/wireguard_setup.log) 2>&1

# Update and upgrade system
echo_with_animation "Updating and upgrading the system..."
apt update -y && apt upgrade -y || { echo "Failed to update/upgrade system. Exiting."; exit 1; }

# Install Docker
echo_with_animation "Installing Docker..."
apt install -y docker.io || { echo "Failed to install Docker. Exiting."; exit 1; }

# Enable and start Docker service
systemctl enable docker --now || { echo "Failed to enable/start Docker. Exiting."; exit 1; }

# Install Docker Compose
echo_with_animation "Installing Docker Compose..."
apt install -y docker-compose || { echo "Failed to install Docker Compose. Exiting."; exit 1; }

# Create necessary directories
echo_with_animation "Creating directory for WireGuard..."
mkdir -p /opt/wireguard

# Dynamically determine the VPS IP
WG_HOST=$(hostname -I | awk '{print $1}')
if [[ -z "$WG_HOST" ]]; then
    echo "Failed to detect VPS IP. Exiting."
    exit 1
fi
echo_with_animation "Detected VPS IP: $WG_HOST"

# Create Docker Compose file
echo_with_animation "Creating Docker Compose file for WireGuard..."
cat <<EOF > /opt/wireguard/docker-compose.yml
version: '3.8'

volumes:
  etc_wireguard:

services:
  wg-easy:
    environment:
      - LANG=en
      - WG_HOST=${WG_HOST}
    image: ghcr.io/wg-easy/wg-easy
    container_name: wg-easy
    volumes:
      - etc_wireguard:/etc/wireguard
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
      - "5500:5500/tcp"
      - "5050:5050/tcp"
      - "5051:5051/tcp"
      - "5052:5052/tcp"
      - "5053:5053/tcp"
      - "5054:5054/tcp"
      - "5055:5055/tcp"
      - "6666:6666/tcp"
      - "7777:7777/tcp"
      - "8888:8888/tcp"
      - "9090:9090/tcp"
      - "25565:25565/udp"
      - "25565:25565/tcp"
EOF

# Restrict permissions
chmod 600 /opt/wireguard/docker-compose.yml

# Start the WireGuard service
echo_with_animation "Starting WireGuard with Docker Compose..."
docker-compose -f /opt/wireguard/docker-compose.yml up -d || { echo "Failed to start WireGuard. Exiting."; exit 1; }

# Configure port forwarding inside the container
echo_with_animation "Configuring port forwarding inside the Docker container..."
# Docker container name
CONTAINER_NAME="wg-easy"

# External interface
EXT_IFACE="eth0"

# VPN client IP (inside the container)
VPN_CLIENT_IP="10.8.0.2"

# List of ports to forward
PORTS=(5050 5051 5052 5053 5054 5055 6666 7777 8888 9090 25565)

# Loop through each port and add iptables rules inside the container
for PORT in "${PORTS[@]}"; do
    echo "Forwarding port $PORT..."
    docker exec -it $CONTAINER_NAME iptables -t nat -A PREROUTING -i $EXT_IFACE -p tcp --dport $PORT -j DNAT --to-destination $VPN_CLIENT_IP:$PORT
    docker exec -it $CONTAINER_NAME iptables -A FORWARD -p tcp -d $VPN_CLIENT_IP --dport $PORT -j ACCEPT


    echo "Forwarding UDP port $PORT..."
    docker exec -it $CONTAINER_NAME iptables -t nat -A PREROUTING -i $EXT_IFACE -p udp --dport $PORT -j DNAT --to-destination $VPN_CLIENT_IP:$PORT
    docker exec -it $CONTAINER_NAME iptables -A FORWARD -p udp -d $VPN_CLIENT_IP --dport $PORT -j ACCEPT    
done

echo "All rules added inside the container!"


# Final message
echo_with_animation "Installation, setup, and port forwarding complete! WireGuard is up and running."
echo "Access it via your browser at http://$WG_HOST:51821"
echo "Please Create Only one user"

# 🟢 Start the Node.js server using dumb-init
echo_with_animation "Launching application..."
exec /usr/bin/dumb-init node server/index.mjs