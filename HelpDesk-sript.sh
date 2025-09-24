#!/bin/bash

# Step 1: Update System and Install MySQL server and client
echo "Updating system and installing MySQL server and client..."
export DEBIAN_FRONTEND=noninteractive
apt update
apt upgrade -y
apt-get install -y mysql-server mysql-client

# Configure MySQL to skip the password validation prompt
echo "Configuring MySQL server..."
cat <<EOF | debconf-set-selections
mysql-server mysql-server/root_password password ''
mysql-server mysql-server/root_password_again password ''
mysql-server mysql-server-5.7/root_password password ''
mysql-server mysql-server-5.7/root_password_again password ''
EOF

# Step 2: Start MySQL service and create database and user
echo "Starting MySQL service..."
service mysql start

echo "Creating MySQL database and user..."
mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE itop CHARACTER SET UTF8 COLLATE UTF8_BIN;
CREATE USER 'itop'@'%' IDENTIFIED BY 'Admin@123';
GRANT ALL PRIVILEGES ON itop.* TO 'itop'@'%';
FLUSH PRIVILEGES;
quit;
MYSQL_SCRIPT

# Step 3: Add PHP 8.1 repository and install PHP and required extensions
echo "Adding PHP 8.1 repository and installing PHP..."
add-apt-repository ppa:ondrej/php -y
apt update
apt-get install -y php8.1 php8.1-mysql php8.1-ldap php8.1-soap php8.1-mbstring php8.1-zip php8.1-curl php8.1-dom php8.1-gd php8.1-xml libapache2-mod-php8.1 php-json

# Step 4: Install Graphviz for iTop diagrams
echo "Installing Graphviz..."
apt-get install -y graphviz

# Step 5: Installing Apache on Ubuntu Linux
echo "Installing Apache..."
apt-get install -y apache2
a2enmod rewrite

# Step 6: Update database and edit some configuration in php.ini file
echo "Configuring PHP settings..."
PHP_INI=$(php -i | grep 'Loaded Configuration File' | cut -d' ' -f 5)
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 32M/" $PHP_INI
sed -i "s/post_max_size = .*/post_max_size = 33M/" $PHP_INI # Ensure post_max_size > upload_max_filesize
sed -i "s/memory_limit = .*/memory_limit = 256M/" $PHP_INI
sed -i "s/max_execution_time = .*/max_execution_time = 300/" $PHP_INI
sed -i "s/max_input_time = .*/max_input_time = 60/" $PHP_INI
sed -i "s/;max_input_vars = .*/max_input_vars = 4440/" $PHP_INI
sed -i "s/;date.timezone =.*/date.timezone = Asia\/Kolkata/" $PHP_INI

# Step 7: Install Composer
echo "Installing Composer..."
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

# Step 8: Installing iTop on Ubuntu Linux
echo "Installing iTop..."
apt-get install -y unzip software-properties-common
cd /tmp
wget https://sourceforge.net/projects/itop/files/latest/download -O itop.zip
unzip itop.zip

# Step 9: Moving iTop to the web directory and setting ownership
echo "Configuring iTop directory and setting permissions..."
mkdir -p /var/www/html/mctsm
mv /tmp/web/* /var/www/html/mctsm/
chown -R www-data:www-data /var/www/html/mctsm

# Step 10: Restart services
echo "Restarting Apache and MySQL services..."
service apache2 restart
service mysql restart

# Step 11: Instructions to complete the setup via the web interface
echo "Installation complete. Please open your browser and navigate to http://<your_ip>/mctsm to complete the setup."
echo "Configuration of database:"
echo "Server Name - localhost"
echo "Login - itop"
echo "Password - Admin@123"
echo "(Press enter after entering these credentials)"
echo "Follow the prompts to complete the iTop installation."

echo "After completing the web setup, you can follow the steps to create service management entities as required."
