#!/bin/bash

set -e

# =====================================================
# Redis installer for AlmaLinux 9 + cPanel
# Safe + idempotent version
# =====================================================

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

echo "=== Updating system ==="
dnf -y update

echo "=== Installing EPEL (if missing) ==="
dnf -y install epel-release

echo "=== Installing Redis (if missing) ==="
if ! rpm -q redis >/dev/null 2>&1; then
    dnf -y install redis
else
    echo "Redis already installed."
fi

echo "=== Enabling and starting Redis ==="
systemctl enable redis
systemctl start redis

sleep 2

if ! systemctl is-active --quiet redis; then
    echo "Redis failed to start."
    exit 1
fi

echo "Redis is running."

echo "=== Testing Redis ==="
if ! redis-cli ping | grep -q PONG; then
    echo "Redis test failed."
    exit 1
fi

echo "Redis test successful."

REDIS_CONF="/etc/redis.conf"

echo "=== Backing up redis.conf ==="
cp -n $REDIS_CONF ${REDIS_CONF}.backup

echo "=== Configuring Redis ==="

# Remove existing save lines
sed -i '/^save /d' $REDIS_CONF
echo "save 300 10" >> $REDIS_CONF

# Secure binding (IMPORTANT for cPanel servers)
sed -i 's/^bind .*/bind 127.0.0.1/' $REDIS_CONF
sed -i 's/^protected-mode .*/protected-mode yes/' $REDIS_CONF

# Maxclients
if grep -q "^maxclients" $REDIS_CONF; then
    sed -i 's/^maxclients .*/maxclients 2000/' $REDIS_CONF
else
    echo "maxclients 2000" >> $REDIS_CONF
fi

# Calculate maxmemory = 25% RAM
total_ram=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
quarter_ram=$(($total_ram / 4))M

if grep -q "^maxmemory " $REDIS_CONF; then
    sed -i "s/^maxmemory .*/maxmemory $quarter_ram/" $REDIS_CONF
else
    echo "maxmemory $quarter_ram" >> $REDIS_CONF
fi

# Memory policy
if grep -q "^maxmemory-policy" $REDIS_CONF; then
    sed -i 's/^maxmemory-policy .*/maxmemory-policy allkeys-lru/' $REDIS_CONF
else
    echo "maxmemory-policy allkeys-lru" >> $REDIS_CONF
fi

echo "=== Restarting Redis ==="
systemctl restart redis

sleep 2

if ! redis-cli ping | grep -q PONG; then
    echo "Redis restart failed."
    exit 1
fi

echo "Redis configuration applied successfully."

# =====================================================
# OPTIONAL: Open port in CSF (NOT recommended unless needed)
# =====================================================

OPEN_EXTERNAL=false   # change to true if you REALLY need external access

if [ "$OPEN_EXTERNAL" = true ]; then
    echo "Opening port 6379 in CSF..."

    if command -v csf >/dev/null 2>&1; then
        csf -a 6379 redis
        csf -r
        echo "Port 6379 opened in CSF."
    else
        echo "CSF not installed. Skipping."
    fi
else
    echo "Redis configured for localhost only. Port 6379 NOT exposed."
fi

echo "==========================================="
echo "Redis installation complete."
echo "Bind address: 127.0.0.1"
echo "Maxmemory: $quarter_ram"
echo "Maxclients: 2000"
echo "==========================================="
