DevSwift
========
Building the latest OpenStack Swift All-in-One development environment with a simple shell script.

1. Introduction
---------------
This script copies the step-by-step tutorial provided by OpenStack Swift Documentation, but it provides a more straightforward way to streamline the installation and configuration procedures.

The original website is http://docs.openstack.org/developer/swift/development_saio.html

This script sets up a virtual machine for doing Swift development. The virtual machine will emulate running a four node Swift cluster.

The prerequisites:

        (1) Support for the latest Ubuntu Server LTS/Fedora/CentOS.
        (2) Make sure 5GB disk space is available.
        (3) The loop device support is enabled.

Notes:

        (1) The script will generate a loop device for storage nodes with default size 2GB. You can also change it to support huge objects by xfs_growfs tool after deployment or directly changing the parameter in the script file before deployment.
        (2) The original loop device is created at /mnt/sdb1. Please make sure it is not existed before running the script and you can also change it to meet your environment.
        (3) All the options for the script are located at the beginning of the script file.

2. Tutorial
---------------
        $ git clone https://github.com/li-ma/DevSwift.git
        $ sudo -s
        # ./devswift.sh

3. Configuration
----------------
        (1) target: The target loop device for object storage.
        (2) target_size: The total disk size of the loop device.
