#!/bin/bash

# options
target=sdb1
target_size=2GB

user=swift
group=swift
uid=2525
gid=2525

# using loopback device for storage
prepare_loop_dev() {
mkdir -p /srv
mkdir -p /mnt/$target
truncate -s $target_size /srv/swift-disk
mkfs.xfs -i size=1024 /srv/swift-disk
echo "/srv/swift-disk   /mnt/$target xfs loop,noatime,nobarrier,logbufs=8 0 0" >> /etc/fstab
mount /mnt/$target
mkdir /mnt/$target/1 /mnt/$target/2 /mnt/$target/3 /mnt/$target/4
chown $user:$group /mnt/$target/*
for x in {1..4};
    do ln -s /mnt/$target/$x /srv/$x;
done
mkdir -p /etc/swift/object-server /etc/swift/container-server /etc/swift/account-server /srv/1/node/sdb1 /srv/2/node/sdb2 /srv/3/node/sdb3 /srv/4/node/sdb4 /var/run/swift
chown -R $user:$group /etc/swift /srv/[1-4]/ /var/run/swift
}

# make sure the temporary directories are existed
prepare_boot_script() {
cat << EOF > /etc/rc.local
#!/bin/sh
mkdir -p /var/cache/swift1 /var/cache/swift2 /var/cache/swift3 /var/cache/swift4
chown $user:$group /var/cache/swift*
mkdir -p /var/run/swift
chown $user:$group /var/run/swift
exit 0
EOF
bash /etc/rc.local
}

# set up rsync env
setup_rsync() {
cat << EOF > /etc/rsyncd.conf

uid = $user
gid = $group
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = 127.0.0.1

[account6012]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/account6012.lock

[account6022]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/account6022.lock

[account6032]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/account6032.lock

[account6042]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/account6042.lock

[container6011]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/container6011.lock

[container6021]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/container6021.lock

[container6031]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/container6031.lock

[container6041]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/container6041.lock

[object6010]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/object6010.lock

[object6020]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/object6020.lock

[object6030]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/object6030.lock

[object6040]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/object6040.lock

EOF
}

# setup rsyslog for individual logging
setup_rsyslog() {
cat << EOF > /etc/rsyslog.d/10-swift.conf
# Uncomment the following to have a log containing all logs together
#local1,local2,local3,local4,local5.*   /var/log/swift/all.log

# Uncomment the following to have hourly proxy logs for stats processing
#$template HourlyProxyLog,"/var/log/swift/hourly/%$YEAR%%$MONTH%%$DAY%%$HOUR%"
#local1.*;local1.!notice ?HourlyProxyLog

local1.*;local1.!notice /var/log/swift/proxy.log
local1.notice           /var/log/swift/proxy.error
local1.*                ~

local2.*;local2.!notice /var/log/swift/storage1.log
local2.notice           /var/log/swift/storage1.error
local2.*                ~

local3.*;local3.!notice /var/log/swift/storage2.log
local3.notice           /var/log/swift/storage2.error
local3.*                ~

local4.*;local4.!notice /var/log/swift/storage3.log
local4.notice           /var/log/swift/storage3.error
local4.*                ~

local5.*;local5.!notice /var/log/swift/storage4.log
local5.notice           /var/log/swift/storage4.error
local5.*                ~
EOF

sed -e '/$PrivDropToGroup/c\$PrivDropToGroup adm' /etc/rsyslog.conf
mkdir -p /var/log/swift/hourly
}

# get the code and setup the environment
install_swift() {
mkdir ~/bin
git clone https://github.com/openstack/python-swiftclient.git
cd ~/python-swiftclient
python setup.py install
cd ~
git clone https://github.com/openstack/swift.git
cd ~/swift
python setup.py install
cd ~
pip install -r swift/test-requirements.txt
}

# configure swift nodes
config_swift() {
echo "export SWIFT_TEST_CONFIG_FILE=/etc/swift/test.conf" >> ~/.bashrc
echo "export PATH=${PATH}:`pwd`/bin:`pwd`/swift/bin" >> ~/.bashrc
. ~/.bashrc

# configure each node
cat << EOF > /etc/swift/proxy-server.conf
[DEFAULT]
bind_port = 8080
user = $user
log_facility = LOG_LOCAL1
eventlet_debug = true

[pipeline:main]
pipeline = healthcheck cache tempauth proxy-logging proxy-server

[app:proxy-server]
use = egg:swift#proxy
allow_account_management = true
account_autocreate = true

[filter:tempauth]
use = egg:swift#tempauth
user_admin_admin = admin .admin .reseller_admin
user_test_tester = testing .admin
user_test2_tester2 = testing2 .admin
user_test_tester3 = testing3

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:cache]
use = egg:swift#memcache

[filter:proxy-logging]
use = egg:swift#proxy_logging

EOF

cat << EOF > /etc/swift/swift.conf
[swift-hash]
# random unique strings that can never change (DO NOT LOSE)
swift_hash_path_prefix = opqrstuvwxyz
swift_hash_path_suffix = abcdefghijklmn
EOF

cat << EOF > /etc/swift/account-server/1.conf
[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6012
user = $user
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift1
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]
EOF

cat << EOF > /etc/swift/account-server/2.conf
[DEFAULT]
devices = /srv/2/node
mount_check = false
disable_fallocate = true
bind_port = 6022
user = $user
log_facility = LOG_LOCAL3
recon_cache_path = /var/cache/swift2
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]
EOF

cat << EOF > /etc/swift/account-server/3.conf
[DEFAULT]
devices = /srv/3/node
mount_check = false
disable_fallocate = true
bind_port = 6032
user = $user
log_facility = LOG_LOCAL4
recon_cache_path = /var/cache/swift3
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]
EOF

cat << EOF > /etc/swift/account-server/4.conf
[DEFAULT]
devices = /srv/4/node
mount_check = false
disable_fallocate = true
bind_port = 6042
user = $user
log_facility = LOG_LOCAL5
recon_cache_path = /var/cache/swift4
eventlet_debug = true

[pipeline:main]
pipeline = recon account-server

[app:account-server]
use = egg:swift#account

[filter:recon]
use = egg:swift#recon

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]
EOF

cat << EOF > /etc/swift/container-server/1.conf
[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6011
user = $user
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift1
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]
EOF

cat << EOF > /etc/swift/container-server/2.conf
[DEFAULT]
devices = /srv/2/node
mount_check = false
disable_fallocate = true
bind_port = 6021
user = $user
log_facility = LOG_LOCAL3
recon_cache_path = /var/cache/swift2
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]
EOF

cat << EOF > /etc/swift/container-server/3.conf
[DEFAULT]
devices = /srv/3/node
mount_check = false
disable_fallocate = true
bind_port = 6031
user = $user
log_facility = LOG_LOCAL4
recon_cache_path = /var/cache/swift3
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]
EOF

cat << EOF > /etc/swift/container-server/4.conf
[DEFAULT]
devices = /srv/4/node
mount_check = false
disable_fallocate = true
bind_port = 6041
user = $user
log_facility = LOG_LOCAL5
recon_cache_path = /var/cache/swift4
eventlet_debug = true

[pipeline:main]
pipeline = recon container-server

[app:container-server]
use = egg:swift#container

[filter:recon]
use = egg:swift#recon

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]
EOF

cat << EOF > /etc/swift/object-server/1.conf
[DEFAULT]
devices = /srv/1/node
mount_check = false
disable_fallocate = true
bind_port = 6010
user = $user
log_facility = LOG_LOCAL2
recon_cache_path = /var/cache/swift1
eventlet_debug = true

[pipeline:main]
pipeline = recon object-server

[app:object-server]
use = egg:swift#object

[filter:recon]
use = egg:swift#recon

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]
EOF

cat << EOF > /etc/swift/object-server/2.conf
[DEFAULT]
devices = /srv/2/node
mount_check = false
disable_fallocate = true
bind_port = 6020
user = $user
log_facility = LOG_LOCAL3
recon_cache_path = /var/cache/swift2
eventlet_debug = true

[pipeline:main]
pipeline = recon object-server

[app:object-server]
use = egg:swift#object

[filter:recon]
use = egg:swift#recon

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]
EOF

cat << EOF > /etc/swift/object-server/3.conf
[DEFAULT]
devices = /srv/3/node
mount_check = false
disable_fallocate = true
bind_port = 6030
user = $user
log_facility = LOG_LOCAL4
recon_cache_path = /var/cache/swift3
eventlet_debug = true

[pipeline:main]
pipeline = recon object-server

[app:object-server]
use = egg:swift#object

[filter:recon]
use = egg:swift#recon

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]
EOF

cat << EOF > /etc/swift/object-server/4.conf
[DEFAULT]
devices = /srv/4/node
mount_check = false
disable_fallocate = true
bind_port = 6040
user = $user
log_facility = LOG_LOCAL5
recon_cache_path = /var/cache/swift4
eventlet_debug = true

[pipeline:main]
pipeline = recon object-server

[app:object-server]
use = egg:swift#object

[filter:recon]
use = egg:swift#recon

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]
EOF

cat << EOF > /etc/swift/object-expirer.conf
[DEFAULT]
swift_dir = /etc/swift
user = $user
# You can specify default log routing here if you want:
log_name = swift
log_facility = LOG_LOCAL0
log_level = INFO

[object-expirer]
interval = 300

[pipeline:main]
pipeline = catch_errors cache proxy-server

[app:proxy-server]
use = egg:swift#proxy
# See proxy-server.conf-sample for options

[filter:cache]
use = egg:swift#memcache
# See proxy-server.conf-sample for options

[filter:catch_errors]
use = egg:swift#catch_errors
# See proxy-server.conf-sample for options
EOF
}

create_swift_scripts() {
# clean the Swift environment
cat << EOF > ~/bin/resetswift
#!/bin/bash
swift-init all stop
sudo find /var/log/swift -type f -exec rm -f {} \;
sudo umount /mnt/$target
sudo mkfs.xfs -f -i size=1024 /srv/swift-disk
sudo mount /mnt/$target
sudo mkdir /mnt/$target/1 /mnt/$target/2 /mnt/$target/3 /mnt/$target/4
sudo chown $user:$group /mnt/$target/*
sudo find /var/cache/swift* -type f -name *.recon -exec rm -f {} \;
sudo service rsyslog restart
sudo service memcached restart
EOF

# make the Swift rings
cat << EOF > ~/bin/remakerings
cd /etc/swift
rm -f *.builder *.ring.gz backups/*.builder backups/*.ring.gz
swift-ring-builder object.builder create 18 3 1
swift-ring-builder object.builder add z1-127.0.0.1:6010/sdb1 1
swift-ring-builder object.builder add z2-127.0.0.1:6020/sdb2 1
swift-ring-builder object.builder add z3-127.0.0.1:6030/sdb3 1
swift-ring-builder object.builder add z4-127.0.0.1:6040/sdb4 1
swift-ring-builder object.builder rebalance
swift-ring-builder container.builder create 18 3 1
swift-ring-builder container.builder add z1-127.0.0.1:6011/sdb1 1
swift-ring-builder container.builder add z2-127.0.0.1:6021/sdb2 1
swift-ring-builder container.builder add z3-127.0.0.1:6031/sdb3 1
swift-ring-builder container.builder add z4-127.0.0.1:6041/sdb4 1
swift-ring-builder container.builder rebalance
swift-ring-builder account.builder create 18 3 1
swift-ring-builder account.builder add z1-127.0.0.1:6012/sdb1 1
swift-ring-builder account.builder add z2-127.0.0.1:6022/sdb2 1
swift-ring-builder account.builder add z3-127.0.0.1:6032/sdb3 1
swift-ring-builder account.builder add z4-127.0.0.1:6042/sdb4 1
swift-ring-builder account.builder rebalance
EOF

# start the main processes
cat << EOF > ~/bin/startmain
#!/bin/bash
swift-init main start
EOF

# start the rest processes
cat << EOF > ~/bin/startrest
#!/bin/bash
swift-init rest start
EOF

# stop all the running processes
cat << EOF > ~/bin/stopall
#!/bin/bash
swift-init all stop
EOF

# make all the scripts executable
chmod +x ~/bin/*
}

# build test env
init_test() {

# init the swift rings
remakerings

# run unit test
cp ~/swift/test/sample.conf /etc/swift/test.conf
cd ~/swift; ./.unittests
}

start_swift() {
# start all the swift processes
startmain
startrest
}
