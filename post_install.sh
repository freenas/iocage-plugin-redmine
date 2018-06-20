#!/bin/sh

# Enable the service
sysrc -f /etc/rc.conf mysql_enable="YES"
sysrc -f /etc/rc.conf redmine_enable="YES"
sysrc -f /etc/rc.conf nginx_enable="YES"

if [ ! -d "/usr/local/www/redmine" ] ; then
  mkdir -p /usr/local/www/redmine
fi

chown -R www:www /usr/local/www/redmine

# Start the service
service mysql-server start 2>/dev/null
service redmine start 2>/dev/null
service nginx start 2>/dev/null

USER="redmine"
DB="redmine"

# Save the config values
echo "$DB" > /root/dbname
echo "$USER" > /root/dbuser
export LC_ALL=C
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1 > /root/dbpassword
PASS=`cat /root/dbpassword`

echo "Database Name: $DB"
echo "Database User: $USER"
echo "Database Password: $PASS"

# Configure mysql
mysql -u root <<-EOF
UPDATE mysql.user SET Password=PASSWORD('${PASS}') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
CREATE DATABASE ${DB} CHARACTER SET utf8;
CREATE USER '${USER}'@'localhost' IDENTIFIED BY '${PASS}';
GRANT ALL PRIVILEGES ON ${DB}.* TO '${USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

cp /usr/local/www/redmine/config/database.yml.sample /usr/local/www/redmine/config/database.yml

# Setup Redmine
#if [ -n "$IOCAGE_PLUGIN_IP" ] ; then
#  sed -i '' "s|host: localhost|host: ${IOCAGE_PLUGIN_IP}|g" /usr/local/www/redmine/config/database.yml
#fi

# Set db password for redmine
sed -i '' "s|secure password|${PASS}|g" /usr/local/www/redmine/config/database.yml

# Precompile the assets
cd /usr/local/www/redmine
bundle install --without development test
bundle exec rake generate_secret_token
export RAILS_ENV=production
bundle exec rake db:migrate

chmod o-rwx /usr/local/www/redmine


echo "Database Name: $DB"
echo "Database User: $USER"
echo "Database Password: $PASS"
echo "Please open the URL to set your username and password."
