# oci-image-borgbackup-server

OCI image for the BorkBackup tool

Container started from this image will start an OpenSSH server, and then Borg
clients can connect to the OpenSSH server to create backups.

## How to use the image

### Docker Hub

Builded images for amd64 and armv7 architectures are available on Docker Hub:

* https://hub.docker.com/r/lmeunier/borgbackup-server

### Volumes

* /data: data directory (BorgBackup repositories)
* /etc/ssh/host_keys: SSH hosts keys

### Ports

* 22: SSH port

### systemd integration

* create a new container

```
podman create                                     \
  --volume borgbackup_data:/data                  \
  --volume borgbackup_ssh_keys:/etc/ssh/host_keys \
  --network host-bridge                           \
  --ip 192.168.1.221                              \
  --name borgbackup-server                        \
  docker.io/lmeunier/borgbackup-server:1.1.16
```

* generate a systemd unit file

```
podman generate systemd --restart-policy=always -t 10 borgbackup-server \
  > /etc/systemd/system/container_borgbackup-server.service
```

* use the `container_borgbackup-server` service like any other systemd service

```
systemctl status container_borgbackup-server
systemctl start  container_borgbackup-server
systemctl enable container_borgbackup-server
```

## How to backup data

### Add an SSH public key

The `/data` volume is initilized with an empty file `ssh/authorized_keys`. This
file contains all SSH public keys allowed to authenticate with the `borgbackup`
account on the container. Before initializing a Borg repository, you must add a
line in this file.

* for example, to allow Alice on the repo1 repository, add this line to the
  `ssh/authorized_keys` file:

```
# replace "alice_ssh_public_key" with the real Alice SSH public key ("ssh-rsa AAAA.... alice@example.com")
command="borg serve --restrict-to-repository ~/repo1 --append-only",restrict alice_ssh_public_key
```

### Initialize a Borg repository

Use the `borg init` command to initialize a repository:

```
borg init -e repokey borgbackup@CONTAINER_IP:repo1
```

### First backup

```
borg create borgbackup@CONTAINER_IP:repo1::'{hostname}-{now}' $HOME
```

## How to build the image

* make sure that bash, [Podman](https://podman.io/) and
  [Buildah](https://buildah.io/) are installed

* clone this repository

```
git clone https://github.com/lmeunier/oci-image-borgbackup-server.git
cd oci-image-borgbackup-server
```

* run the `build.sh` script
 * for rootfull builds, just execute the `build.sh` script

  ```
  ./build.sh
  ```

 * for rootless builds, you need to run the `build.sh` script in a [buildah
unshare](https://github.com/containers/buildah/blob/master/docs/buildah-unshare.md)
namespace:

  ```
  buildah unshare ./build.sh
  ```

The `build.sh` script will create an OCI image named `localhost/borgbackup-server` with a
TAG based on the current CPU architecture and the BorgBackup version.

```
$ podman images
REPOSITORY                   TAG           IMAGE ID      CREATED            SIZE
localhost/borgbackup-server  armv7-1.1.16  70d3d8f85367  About an hour ago  145 MB
```

* test the builed OCI image

```
podman run -it --rm borgbackup-server:armv7-1.1.16
```


## Push images to Docker Hub

### Login to the Docker Hub registry

```
buildah login docker.io
```

### Push an architecture specific image to Docker Hub


```
TAG="armv7-1.1.16"
USERNAME="lmeunier"

buildah push borgbackup-server:$TAG docker://docker.io/$USERNAME/borgbackup-server:$TAG
```

### Push a multi-arch image to Docker Hub

```
BORGBACKUP_VERSION="1.1.16"
USERNAME="lmeunier"

ARCHS="amd64 armv7"

buildah manifest create borgbackup-server:$BORGBACKUP_VERSION
for ARCH in $ARCHS; do
  VARIANT=""
  if [[ $ARCH == arm* ]]; then
    VARIANT="--variant ${ARCH:3}"
  fi
  TAG="$ARCH-$BORGBACKUP_VERSION"
  buildah pull docker.io/$USERNAME/borgbackup-server:$TAG
  buildah manifest add $VARIANT borgbackup-server:$BORGBACKUP_VERSION docker.io/$USERNAME/borgbackup-server:$TAG
done
buildah manifest inspect borgbackup-server:$BORGBACKUP_VERSION
buildah manifest push --all --format v2s2 borgbackup-server:$BORGBACKUP_VERSION docker://docker.io/$USERNAME/borgbackup-server:$BORGBACKUP_VERSION
```
