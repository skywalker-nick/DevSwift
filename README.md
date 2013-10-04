DevSwift
========
Building the latest Swift All-in-One development environment with a simple stupid BASH shell script

1. Introduction
---------------
This script copies the step-by-step tutorial provided by OpenStack Swift Documentation, but it provides a more straightforward way to streamline the installation and configuration procedures.

The original website is http://docs.openstack.org/developer/swift/development_saio.html

This script sets up a virtual machine for doing Swift development. The virtual machine will emulate running a four node Swift cluster.

The prerequisites:
    1. Support for Ubuntu Linux Server LTS
    2. Make sure 5GB disk space is available

Notes:
    1. If you would like to deploy it in another Linux distribution, for example, Fedora/CentOS, you have to change "apt-get" way to "yum" manually.
    2. The script will generate a loop device for storage nodes with default size 1GB. You can also change it to support huge objects.

2. Tutorial
---------------
