#!/usr/bin/env bash

BORGBACKUP_VERSION="1.1.14"

set -e

build_container=$(buildah from --override-arch="" debian:buster)
build_mount=$(buildah mount $build_container)
runtime_container=$(buildah from --override-arch="" debian:buster-slim)
runtime_mount=$(buildah mount $runtime_container)

echo "======================================================================="
echo "BorgBackup v$BORGBACKUP_VERSION"
echo "" 
echo "build_container=$build_container"
echo "build_mount=$build_mount"
echo ""
echo "runtime_container=$runtime_container"
echo "runtime_mount=$runtime_mount"
echo "======================================================================="


#
# Build Container
#

buildah run $build_container bash -e << EOF
    apt-get update
    apt-get upgrade -y
    apt-get install -y python3 python3-dev python3-pip python-virtualenv \
        libssl-dev openssl libacl1-dev libacl1 build-essential \
        libfuse-dev fuse pkg-config git libffi-dev zlib1g-dev wget
    git clone -b ${BORGBACKUP_VERSION} https://github.com/borgbackup/borg.git
    wget https://github.com/pyinstaller/pyinstaller/releases/download/v4.0/PyInstaller-4.0.tar.gz
    virtualenv --python=python3 borg-env
    source borg-env/bin/activate
    tar xf PyInstaller-4.0.tar.gz
    cd /pyinstaller-4.0/bootloader
    python ./waf all
    cd /pyinstaller-4.0
    pip install -e .
    cd /borg
    pip install -r requirements.d/development.txt
    pip install -r requirements.d/docs.txt
    pip install -r requirements.d/fuse.txt
    pip install -e .
    pyinstaller --clean --distpath=/dist/borg scripts/borg.exe.spec
EOF


#
# Runtime Container
#

buildah run $runtime_container bash -e << EOF
    apt-get update
    apt-get upgrade -y
    apt-get install -y bash openssh-server augeas-tools
    mkdir -p /etc/ssh/host_keys /etc/ssh/keys/authorized /run/sshd
    augtool 'set /files/etc/ssh/sshd_config/AuthorizedKeysFile "ssh/authorized_keys"'
    augtool 'set /files/etc/ssh/sshd_config/HostKey[1] /etc/ssh/host_keys/ssh_host_rsa_key'
    augtool 'set /files/etc/ssh/sshd_config/HostKey[2] /etc/ssh/host_keys/ssh_host_dsa_key'
    augtool 'set /files/etc/ssh/sshd_config/HostKey[3] /etc/ssh/host_keys/ssh_host_ecdsa_key'
    augtool 'set /files/etc/ssh/sshd_config/HostKey[4] /etc/ssh/host_keys/ssh_host_ed25519_key'
    augtool 'set /files/etc/ssh/sshd_config/PermitRootLogin no'
    augtool 'set /files/etc/ssh/sshd_config/PasswordAuthentication no'
    augtool 'set /files/etc/ssh/sshd_config/ClientAliveInterval 10'
    augtool 'set /files/etc/ssh/sshd_config/ClientAliveCountMax 30'
    useradd -p '' -m -d /data -c 'BorkBackup User' borgbackup
    mkdir -p /data/ssh
    echo "# command=\"borg serve --restrict-to-repository ~/repo1 --append-only\",restrict ssh-rsa AAAA..." > /data/ssh/authorized_keys
    chown -R borgbackup: /data
EOF
cp -av $build_mount/dist/borg/borg.exe $runtime_mount/usr/bin/borg

# Image configuration
buildah config --user root:root $runtime_container
buildah copy $runtime_container entrypoint.sh /entrypoint.sh
buildah config --entrypoint '["/entrypoint.sh"]' $runtime_container
buildah config --cmd '/usr/sbin/sshd -D -e -f /etc/ssh/sshd_config' $runtime_container

# Volumes
buildah config --volume /etc/ssh/host_keys $runtime_container
buildah config --volume /data $runtime_container

# Ports
buildah config --port 22 $runtime_container

# Commit
ARCH=$(buildah info --format {{".host.arch"}})
if [[ $ARCH -eq arm ]]; then
  case $(grep -i -m1 "CPU architecture" /proc/cpuinfo | cut -f3 -d" ") in
    7) VARIANT="v7";;
  esac
  ARCH="$ARCH$VARIANT"
fi
TAG="$ARCH-$BORGBACKUP_VERSION"
buildah commit $runtime_container borgbackup-server:$TAG

# Clean up
#buildah unmount $build_container
#buildah unmount $runtime_container
#buildah rm $build_container $runtime_container

