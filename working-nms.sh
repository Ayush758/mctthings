cat nms.sh
#!/bin/bash
set -e  # Exit on error unless explicitly handled
echo "=== [ STEP 2 ] Installing Required Packages ==="
sudo apt update
sudo apt install -y openjdk-11-jdk git perl postgresql
echo "=== [ STEP 3 ] Enabling and Starting PostgreSQL ==="
sudo systemctl enable --now postgresql
echo "=== [ STEP 4 ] Creating Linux User 'opennms' ==="
if ! id "opennms" &>/dev/null; then
    sudo adduser --disabled-password --gecos "" opennms
    echo "opennms:admin" | sudo chpasswd
else
    echo "User 'opennms' already exists."
fi
echo "=== [ STEP 5 ] Creating Application Directory ==="
sudo mkdir -p /usr/share/.mctnms
sudo chown -R opennms:opennms /usr/share/.mctnms
echo "=== [ STEP 6 ] Cloning the MCTNMS Repo ==="
cd /usr/share/
if [ ! -d "nms-build" ]; then
    sudo git clone http://vikas123:redhat%40123@192.168.100.72/mct_projects/mct-nms/nms-build.git
else
    echo "Repo already cloned."
fi
cd nms-build
sudo git checkout master
echo "=== [ STEP 7 ] Copying Build to Application Directory ==="
sudo cp -rvf target /usr/share/.mctnms/
sudo chmod -R 755 /usr/share/.mctnms/
sudo chown -R opennms:opennms /usr/share/.mctnms/
echo "=== [ STEP 8 ] Creating PostgreSQL User and DB ==="
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='opennms'" | grep -q 1; then
    sudo -u postgres psql -c "CREATE USER opennms WITH PASSWORD 'Admin@123';"
else
    echo "PostgreSQL user 'opennms' already exists."
fi
if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw opennms; then
    sudo -u postgres createdb -O opennms opennms
else
    echo "Database 'opennms' already exists."
fi
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'Admin@123';"
echo "=== [ STEP 9 ] Replacing Database Passwords in Configuration ==="
CONFIG_FILE="/usr/share/.mctnms/target/opennms-32.0.2/etc/opennms-datasources.xml"
sudo sed -i 's/password="admin"/password="Admin@123"/g' "$CONFIG_FILE"
echo "=== [ STEP 10 ] Updating version.display in properties ==="
VERSION_PROPERTIES="/usr/share/.mctnms/target/opennms-32.0.2/jetty-webapps/mctnms/WEB-INF/version.properties"
sudo sed -i 's/^version\.display=.*/version.display=v1.0/' "$VERSION_PROPERTIES"
echo "=== [ STEP 12 ] Initializing Java for OpenNMS ==="
sudo /usr/share/.mctnms/target/opennms-32.0.2/bin/runjava -s
echo "=== [ STEP 13 ] Installing OpenNMS Application ==="
sudo /usr/share/.mctnms/target/opennms-32.0.2/bin/install -dis
echo "=== [ STEP 14 ] Checking PostgreSQL Port ==="
sudo ss -tunlp | grep 5432 || echo "PostgreSQL not listening on 5432"
echo "=== [ STEP 14.1 ] Inserting Freemarker Comment Tags ==="
NAVBAR_FILE="/usr/share/.mctnms/target/opennms-32.0.2/jetty-webapps/mctnms/WEB-INF/templates/navbar.ftl"
sudo sed -i '105a\                      <#--' "$NAVBAR_FILE"
sudo sed -i '111a\                      -->' "$NAVBAR_FILE"
echo "=== [ STEP 15 ] Starting OpenNMS as root ==="
sudo /usr/share/.mctnms/target/opennms-32.0.2/bin/opennms -vt start
echo "=== :white_check_mark: NMS Deployment Complete ==="
