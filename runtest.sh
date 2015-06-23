#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#	runtest.sh of /CoreOS/selinux-change-test.git/Sanity/tests-covering-SELinuxPolicyStoreMigration-change
#	Description: tests covering SELinuxPolicyStoreMigration change
#	Author: Petr Lautrbach <plautrba@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#	Copyright (c) 2015 Red Hat, Inc.
#
#	This program is free software: you can redistribute it and/or
#	modify it under the terms of the GNU General Public License as
#	published by the Free Software Foundation, either version 2 of
#	the License, or (at your option) any later version.
#
#	This program is distributed in the hope that it will be
#	useful, but WITHOUT ANY WARRANTY; without even the implied
#	warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#	PURPOSE.	See the GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
# . /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="selinux-change-test.git"

if [ -z "$TEST_GUEST" ]; then
	TEST_GUEST=fedora-cloud
fi

function prepare_and_run_snapshot() {
	virsh start $TEST_GUEST
	rlWaitForCmd "ssh fedora@$TEST_GUEST sleep 5" -t 60
	virsh snapshot-create $TEST_GUEST
}

function revert_snapshot() {
	virsh snapshot-revert $TEST_GUEST --current
}

function delete_snapshot() {
	virsh snapshot-delete $TEST_GUEST --current
}

function run_remote_command() {
	ssh fedora@$TEST_GUEST $*
}

function update_packages() {
	# rlRun "run_remote_command sudo dnf -y copr enable plautrba/selinux"
	# rlRun "run_remote_command sudo dnf -y update selinux-policy --disablerepo=rawhide"
	rlRun "scp -r rpms fedora@$TEST_GUEST:; run_remote_command sudo dnf -y update rpms/\*"
}

rlJournalStart
	rlPhaseStartSetup
		rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
		rlRun "cp -r rpms $TmpDir/"
		rlRun "pushd $TmpDir"

		rlRun prepare_and_run_snapshot

		# uncomment for update from copr plautrba/selinux repo
		if [ -n "$TEST_SYNC_REPO" ]; then
			rlRun "run_remote_command 'mkdir rpms; cd rpms; sudo dnf -y copr enable plautrba/selinux; dnf download --disablerepo=rawhide libselinux libselinux-python libselinux-python3 libselinux-utils libsemanage libsemanage-python libsemanage-python3 libsepol policycoreutils policycoreutils-python policycoreutils-python3 selinux-policy selinux-policy-targeted selinux-policy-minimal selinux-policy-mls'"
			rlRun "scp -r fedora@$TEST_GUEST:rpms ."
			rm rpms/*src.rpm; rm rpms/*i686.rpm
		fi
		rlRun revert_snapshot
	rlPhaseEnd

	rlPhaseStartTest "simple update test"

# 0. disable random module, set random variable, make random login change
# 1. check set of modules, booleans, users, ... in distribution package
# 2. update selinux-policy-targeted package
# 3. check if userspace packages are updated
# 4. check if SELinux state is same as before update
# 5. same but update userspace and check if selinux-policy is updated
		# rlRun prepare_and_run_snapshot
		
		rlRun "old_package_version=\$(run_remote_command rpm -q selinux-policy)"
		
		# set booleans
		rlRun "run_remote_command sudo setsebool -P xdm_bind_vnc_tcp_port 1"
		# disable modules
		rlRun "run_remote_command sudo semodule -d zabbix -d zarafa"
		# install 3rd part modules
		rlRun "scp rpms/gcl-selinux* fedora@$TEST_GUEST:; run_remote_command sudo dnf -y install gcl-selinux\*"

		rlRun "run_remote_command sudo getsebool -a | sort > $old_package_version.boolean-list"
		rlRun "run_remote_command sudo semodule -l | grep -v Disabled | cut -f 1 | sort > $old_package_version.modules-list"

		update_packages

		rlRun "new_package_version=\$(run_remote_command rpm -q selinux-policy)"
		rlRun "run_remote_command sudo semodule -l |grep -v Disabled | cut -f 1 | sort > $new_package_version.modules-list"
		rlRun "run_remote_command sudo getsebool -a | sort > $new_package_version.boolean-list"

		rlRun "diff -u $old_package_version.modules-list $new_package_version.modules-list"
		rlAssertNotDiffer $old_package_version.modules-list $new_package_version.modules-list

		rlRun "diff -u $old_package_version.boolean-list $new_package_version.boolean-list"
		rlAssertNotDiffer $old_package_version.boolean-list $new_package_version.boolean-list

		rlRun "run_remote_command sudo semodule -l | grep gcl"

		rlRun "rm *-list"
		rlRun revert_snapshot
	rlPhaseEnd

	rlPhaseStartCleanup
		rlRun revert_snapshot
		rlRun delete_snapshot
		rlRun "virsh shutdown $TEST_GUEST"
		rlRun "popd"
		if [ -n "$TEST_SYNC_REPO" ]; then
			mv rpms rpms-`date +%y%m%d%H%M%S`
			cp -r $TmpDir/rpms .
		fi
		rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
	rlPhaseEnd
rlJournalEnd
rlJournalPrintText
