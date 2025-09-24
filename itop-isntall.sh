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

# Step 4: Installing Apache on Ubuntu Linux with PHP
echo "Installing Apache and PHP..."
apt-get update
apt-get install -y apache2 php-mysql libapache2-mod-php mysql-server
service apache2 restart

apt-get install -y php-mysql php-ldap php-soap php-json php-mbstring

# Step 5: Update database and edit some configuration in php.ini file
echo "Configuring PHP settings..."
apt install -y locate
updatedb
PHP_INI=$(locate php.ini | grep 'apache2/php.ini')

sed -i "s/upload_max_filesize = .*/upload_max_filesize = 32M/" $PHP_INI
sed -i "s/post_max_size = .*/post_max_size = 32M/" $PHP_INI
sed -i "s/memory_limit = .*/memory_limit = 256M/" $PHP_INI
sed -i "s/max_execution_time = .*/max_execution_time = 300/" $PHP_INI
sed -i "s/max_input_time = .*/max_input_time = 60/" $PHP_INI
sed -i "s/;max_input_vars = .*/max_input_vars = 4440/" $PHP_INI
sed -i "s/;date.timezone =.*/date.timezone = Asia\/Kolkata/" $PHP_INI

# Step 6: Restart Apache service
echo "Restarting Apache service..."
service apache2 restart

# Step 7: Installing iTop on Ubuntu Linux
echo "Installing iTop..."
apt-get install -y unzip software-properties-common
cd /tmp
wget https://sourceforge.net/projects/itop/files/latest/download -O itop.zip
unzip itop.zip

# Step 8: Moving iTop to the web directory
echo "Configuring iTop directory..."
mkdir -p /var/www/html/mctsm
mv /tmp/web/* /var/www/html/mctsm/
cd /var/www/html/mctsm
mkdir conf data env-production env-production-build log
chown www-data:www-data /var/www/html/mctsm/* -R

# Step 9: Instructions to complete the setup via the web interface
echo "Installation complete. Please open your browser and navigate to http://<your_ip>/mctsm to complete the setup."
echo "Configuration of database:"
echo "Server Name - localhost"
echo "Login - itop"
echo "Password - Admin@123"
echo "(Press enter after entering these credentials)"
echo "Follow the prompts to complete the iTop installation."

echo "After completing the web setup, you can follow the steps to create service management entities as required."

# Additional steps can be added here as needed to further configure the iTop instance via the web interface or API.

