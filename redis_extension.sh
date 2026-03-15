# Fetch and install Redis for each PHP version
for phpver in $(ls -1 /opt/cpanel/ | grep ea-php | sed 's/ea-php//g'); do
    echo "=== Installing Redis for PHP $phpver ==="
    cd ~ || exit

    # Download stable Redis extension (avoid RC builds)
    wget -O redis.tgz https://pecl.php.net/get/redis-5.3.7.tgz

    # Extract
    tar -xzf redis.tgz
    REDIS_DIR=$(find . -maxdepth 1 -type d -name "redis*" | head -n 1)
    cd "$REDIS_DIR" || { echo "Redis directory not found"; exit 1; }

    # Prepare PHP build environment
    /opt/cpanel/ea-php"$phpver"/root/usr/bin/phpize
    ./configure --with-php-config=/opt/cpanel/ea-php"$phpver"/root/usr/bin/php-config

    # Compile & install
    make && make install

    # Enable the module
    echo 'extension=redis.so' > /opt/cpanel/ea-php"$phpver"/root/etc/php.d/redis.ini

    # Clean up
    cd ~
    rm -rf "$REDIS_DIR" redis.tgz
done

# Restart Apache and PHP-FPM
/scripts/restartsrv_httpd
/scripts/restartsrv_apache_php_fpm

echo "✅ Redis extension installed successfully for all PHP versions."
