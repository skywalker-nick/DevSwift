#!/bin/bash

# load the common functions
source common.sh

# add swift user
add_user_ubuntu() {
deluser $user
delgroup $group
addgroup --gid $gid --quiet $group
useradd --gid $gid --uid $uid $user
}
add_user_ubuntu

# installing software packages and their dependencies
install_env_ubuntu() {
apt-get -y install python-software-properties software-properties-common
add-apt-repository ppa:swift-core/release
apt-get update
apt-get -y install curl gcc vim screen git-core memcached python-coverage python-dev python-nose python-setuptools python-pip python-simplejson python-xattr sqlite3 xfsprogs python-eventlet python-greenlet python-pastedeploy python-netifaces
pip install mock
pip install dnspython
}
install_env_ubuntu

prepare_loop_dev

prepare_boot_script

setup_rsync

config_rsync_service_ubuntu() {
sed -i 's/RSYNC_ENABLE=false/RSYNC_ENABLE=true/g' /etc/default/rsync
service rsync restart
}
config_rsync_service_ubuntu

# start memcached
setup_memcached_ubuntu() {
service memcached start
}
setup_memcached_ubuntu

# setup rsyslog for individual logging
setup_rsyslog

config_rsyslog_service_ubuntu() {
chown -R syslog.adm /var/log/swift
chmod -R g+w /var/log/swift
service rsyslog restart
}
config_rsyslog_service_ubuntu

# get the code and setting the environment
install_swift

# configure swift
config_swift

# setting up scripts for running swift
create_swift_scripts

# run unit tests for swift
init_test

# start swift processes
start_swift
