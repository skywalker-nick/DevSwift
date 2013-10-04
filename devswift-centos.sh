#!/bin/bash

# load the common functions
source common.sh

# add swift user
add_user_centos() {
userdel $user
groupdel $group
groupadd --gid $gid --force $group
useradd --gid $gid --uid $uid $user
}
add_user_centos

# installing software packages and their dependencies
install_env_centos() {
yum -y install curl gcc memcached rsync sqlite xfsprogs git-core libffi-devel xinetd wget zlib*
yum -y install python-coverage python-devel python-nose python-simplejson python-setuptools
wget --no-check-certificate https://pypi.python.org/packages/source/p/pip/pip-1.4.1.tar.gz
tar zxvf pip-1.4.1.tar.gz
cd pip-1.4.1
python setup.py install
cd ..
pip install -U xattr eventlet greenlet pastedeploy netifaces dnspython mock
}
install_env_centos

prepare_loop_dev

prepare_boot_script

setup_rsync

config_rsync_service_centos() {
# enable rsync service
sed -i -e "/disable/{ s/yes/no/ }" /etc/xinetd.d/rsync

# disable SELinux for rsync
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
setenforce Permissive
service xinetd restart
}
config_rsync_service_centos

# start memcached
setup_memcached_centos() {
service memcached start
chkconfig memcached on
}
setup_memcached_centos

# setup rsyslog for individual logging
setup_rsyslog

config_rsyslog_service_centos() {
chown -R root:adm /var/log/swift
chmod -R g+w /var/log/swift
service rsyslog restart
}
config_rsyslog_service_centos

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
