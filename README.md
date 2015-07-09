# SELinuxPolicyStoreMigration-tests
simple test suite for https://fedoraproject.org/wiki/Changes/SELinuxPolicyStoreMigration

# Usage

## Prepare a guest

* download Fedora Cloud Base qcow2 image from https://getfedora.org/cs/cloud/download/, e.g.  https://download.fedoraproject.org/pub/fedora/linux/releases/22/Cloud/x86_64/Images/Fedora-Cloud-Base-22-20150521.x86_64.qcow2
* prepare init.iso according to the chapter chapter *Logging In To Your Atomic Machine*  http://www.projectatomic.io/docs/quickstart/

```
$ cat meta-data 
instance-id: id-fedora-cloud
local-hostname: fedora-cloud
network-interfaces: |
  iface eth0 inet static
  address 192.168.122.41
  network 192.168.122.0
  netmask 255.255.255.0
  broadcast 192.168.122.255
  gateway 192.168.122.1

$ cat user-data
#cloud-config
password: r 
ssh_pwauth: True
chpasswd: { expire: False }

ssh_authorized_keys: 
  - ssh-rsa ... /home/plautrba/.ssh/id_rsa
```

* import the downloaded image using virt-manager
	* check *Customize configuration before install* and add cdrom device with attached init.iso
* adjust your ~/.ssh/config
	
```
$ cat >> ~/.ssh/config <<EOF
host fedora-cloud
    hostname 192.168.122.41
	identityfile /home/plautrba/.ssh/id_rsa
EOF
```

* boot, login and update to Rawhide

```
$ ssh fedora@fedora-cloud
fedora-cloud $ sudo dnf install fedora-repos-rawhide
fedora-cloud $ sudo dnf update --enablerepo=rawhide
```

## run tests

`make run`

* If you use other guest name, use `TEST_GUEST` environment variable to your name
* If you want to use local copy of rpm set `TEST_SYNC_REPO` variable to `no`
