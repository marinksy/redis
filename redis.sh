#!/bin/bash

# Script to install and configure Redis on AlmaLinux 9 with cPanel

# Ensure the script is run as root or with sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or with sudo privileges."
    exit 1
fi

# Step 1: Update the system
echo "Updating the system..."
dnf update -y

# Step 2: Install the EPEL repository
echo "Installing the EPEL repository..."
dnf install epel-release -y

# Step 3: Install Redis
echo "Installing Redis..."
dnf install redis -y

# Step 4: Start and enable Redis service
echo "Starting and enabling Redis service..."
systemctl start redis
systemctl enable redis

# Step 5: Verify Redis installation
echo "Verifying Redis installation..."
systemctl status redis | grep "Active: active (running)" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "Redis is running successfully."
else
    echo "Failed to start Redis. Please check the system logs for more information."
    exit 1
fi

# Step 6: Test Redis
echo "Testing Redis installation..."
redis-cli ping | grep "PONG" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "Redis responded with PONG. Installation successful."
else
    echo "Redis did not respond as expected. Please troubleshoot."
    exit 1
fi

# Step 7: Configure Redis
echo "Configuring Redis..."

REDIS_CONF="/etc/redis.conf"

# Backup the original Redis configuration
cp $REDIS_CONF ${REDIS_CONF}.backup

# Step 7.1: Leave only "save 300 10"
sed -i '/^save /d' $REDIS_CONF
echo "save 300 10" >> $REDIS_CONF

# Step 7.2: Add or edit maxclients to 2000
if grep -q "^maxclients" $REDIS_CONF; then
    sed -i "s/^maxclients.*/maxclients 2000/" $REDIS_CONF
else
    echo "maxclients 2000" >> $REDIS_CONF
fi

# Step 7.3: Set maxmemory to one-quarter of total RAM
total_ram=$(free -m | awk '/Mem:/ { print $2 }')
quarter_ram=$(($total_ram / 4))M
if grep -q "^maxmemory" $REDIS_CONF; then
    sed -i "s/^maxmemory.*/maxmemory $quarter_ram/" $REDIS_CONF
else
    echo "maxmemory $quarter_ram" >> $REDIS_CONF
fi

# Step 7.4: Set maxmemory-policy to allkeys-lru
if grep -q "^maxmemory-policy" $REDIS_CONF; then
    sed -i "s/^maxmemory-policy.*/maxmemory-policy allkeys-lru/" $REDIS_CONF
else
    echo "maxmemory-policy allkeys-lru" >> $REDIS_CONF
fi

# Step 8: Configure CSF to open port 6379
echo "Opening port 6379 in CSF..."
csf_config="/etc/csf/csf.conf"

# Allow port 6379 in TCP_IN and TCP_OUT
sed -i "/^TCP_IN =/ s/\"/\",6379/" $csf_config
sed -i "/^TCP_OUT =/ s/\"/\",6379/" $csf_config

# Restart CSF to apply changes
csf -r

# Step 9: Restart Redis to apply configuration changes
echo "Restarting Redis to apply configuration changes..."
systemctl restart redis

# Final message
echo "Redis installation and configuration completed successfully."
echo "Redis is now installed and running on your AlmaLinux 9 system with cPanel."
