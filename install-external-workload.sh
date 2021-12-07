#!/bin/bash
CILIUM_IMAGE=${1:-quay.io/cilium/cilium:v1.10.5@sha256:0612218e28288db360c63677c09fafa2d17edda4f13867bcabf87056046b33bb}
CLUSTER_ADDR=${2:-10.128.0.20:2379}
CONFIG_OVERWRITES=${3:-}

set -e
shopt -s extglob

# Run without sudo if not available (e.g., running as root)
SUDO=
if [ ! "$(whoami)" = "root" ] ; then
    SUDO=sudo
fi

if [ "$1" = "uninstall" ] ; then
    if [ -n "$(${SUDO} docker ps -a -q -f name=cilium)" ]; then
        echo "Shutting down running Cilium agent"
        ${SUDO} docker rm -f cilium || true
    fi
    if [ -f /usr/bin/cilium ] ; then
        echo "Removing /usr/bin/cilium"
        ${SUDO} rm /usr/bin/cilium
    fi
    pushd /etc
    if [ -f resolv.conf.orig ] ; then
        echo "Restoring /etc/resolv.conf"
        ${SUDO} mv -f resolv.conf.orig resolv.conf
    elif [ -f resolv.conf.link ] && [ -f $(cat resolv.conf.link) ] ; then
        echo "Restoring systemd resolved config..."
        if [ -f /usr/lib/systemd/resolved.conf.d/cilium-kube-dns.conf ] ; then
	    ${SUDO} rm /usr/lib/systemd/resolved.conf.d/cilium-kube-dns.conf
        fi
        ${SUDO} systemctl daemon-reload
        ${SUDO} systemctl reenable systemd-resolved.service
        ${SUDO} service systemd-resolved restart
        ${SUDO} ln -fs $(cat resolv.conf.link) resolv.conf
        ${SUDO} rm resolv.conf.link
    fi
    popd
    exit 0
fi

if [ -z "$CLUSTER_ADDR" ] ; then
    echo "CLUSTER_ADDR must be defined to the IP:PORT at which the clustermesh-apiserver is reachable."
    exit 1
fi

port='@(6553[0-5]|655[0-2][0-9]|65[0-4][0-9][0-9]|6[0-4][0-9][0-9][0-9]|[1-5][0-9][0-9][0-9][0-9]|[1-9][0-9][0-9][0-9]|[1-9][0-9][0-9]|[1-9][0-9]|[1-9])'
byte='@(25[0-5]|2[0-4][0-9]|[1][0-9][0-9]|[1-9][0-9]|[0-9])'
ipv4="$byte\.$byte\.$byte\.$byte"

# Default port is for a HostPort service
case "$CLUSTER_ADDR" in
    \[+([0-9a-fA-F:])\]:$port)
	CLUSTER_PORT=${CLUSTER_ADDR##\[*\]:}
	CLUSTER_IP=${CLUSTER_ADDR#\[}
	CLUSTER_IP=${CLUSTER_IP%\]:*}
	;;
    [^[]$ipv4:$port)
	CLUSTER_PORT=${CLUSTER_ADDR##*:}
	CLUSTER_IP=${CLUSTER_ADDR%:*}
	;;
    *:*)
	echo "Malformed CLUSTER_ADDR: $CLUSTER_ADDR"
	exit 1
	;;
    *)
	CLUSTER_PORT=2379
	CLUSTER_IP=$CLUSTER_ADDR
	;;
esac

${SUDO} mkdir -p /var/lib/cilium/etcd
${SUDO} tee /var/lib/cilium/etcd/ca.crt <<EOF >/dev/null
-----BEGIN CERTIFICATE-----
MIICFDCCAbqgAwIBAgIUNdQfDwPThoe543GAuTz2fDO7NtQwCgYIKoZIzj0EAwIw
aDELMAkGA1UEBhMCVVMxFjAUBgNVBAgTDVNhbiBGcmFuY2lzY28xCzAJBgNVBAcT
AkNBMQ8wDQYDVQQKEwZDaWxpdW0xDzANBgNVBAsTBkNpbGl1bTESMBAGA1UEAxMJ
Q2lsaXVtIENBMB4XDTIxMTIwNzA3MjQwMFoXDTI2MTIwNjA3MjQwMFowaDELMAkG
A1UEBhMCVVMxFjAUBgNVBAgTDVNhbiBGcmFuY2lzY28xCzAJBgNVBAcTAkNBMQ8w
DQYDVQQKEwZDaWxpdW0xDzANBgNVBAsTBkNpbGl1bTESMBAGA1UEAxMJQ2lsaXVt
IENBMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEG1W+7glHb8L+rkFIqOxHtm+v
FZc76a5pSUVNwiP1sJ8ohahYi8iJHk+55cczYTiiog8cGBeesXKEkHyVOJ2iu6NC
MEAwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFNX1
fdNeOMxQBCNdSJC7tYMdNFrbMAoGCCqGSM49BAMCA0gAMEUCIGjFj56Tk3jeNp1m
lo5OidYUvkr8qVvjww8HGdJv+RPkAiEAgoZ1xCLF2QlKBCZI6ra1Hz8NapQqTEEl
rx21KMKH+oY=
-----END CERTIFICATE-----
EOF
${SUDO} tee /var/lib/cilium/etcd/tls.crt <<EOF >/dev/null
-----BEGIN CERTIFICATE-----
MIICRDCCAeugAwIBAgIUTr9b/dkoGr167OotcqrWTvG3NpIwCgYIKoZIzj0EAwIw
aDELMAkGA1UEBhMCVVMxFjAUBgNVBAgTDVNhbiBGcmFuY2lzY28xCzAJBgNVBAcT
AkNBMQ8wDQYDVQQKEwZDaWxpdW0xDzANBgNVBAsTBkNpbGl1bTESMBAGA1UEAxMJ
Q2lsaXVtIENBMB4XDTIxMTIwNzA3MjYwMFoXDTI2MTIwNjA3MjYwMFowTTELMAkG
A1UEBhMCVVMxFjAUBgNVBAgTDVNhbiBGcmFuY2lzY28xCzAJBgNVBAcTAkNBMRkw
FwYDVQQDExBleHRlcm5hbHdvcmtsb2FkMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcD
QgAEfGFraI3BgSi+0TDEdP5NYF6Djm10VNsdtoPslv8NGQCH5edSxrkQS5NY9NjL
6Y7d5pNLYgg7ypXR//uRiJl0+aOBjTCBijAOBgNVHQ8BAf8EBAMCBaAwHQYDVR0l
BBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYE
FGHE/EkFylm2x1Xz5cKjAfL9SwL4MB8GA1UdIwQYMBaAFNX1fdNeOMxQBCNdSJC7
tYMdNFrbMAsGA1UdEQQEMAKCADAKBggqhkjOPQQDAgNHADBEAiEAufjKeZ/VhGug
XurEMB3qohLXW1xgtiA0q5gkF3pRZkoCHzydBGGYfKypJk6zVQSiYpF6OIt4f3WT
A2RFvGrCDDQ=
-----END CERTIFICATE-----
EOF
${SUDO} tee /var/lib/cilium/etcd/tls.key <<EOF >/dev/null
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIO6QyD7XF7xZQwNiAapjF0T1NU0BhY92zr+I1+1ttamJoAoGCCqGSM49
AwEHoUQDQgAEfGFraI3BgSi+0TDEdP5NYF6Djm10VNsdtoPslv8NGQCH5edSxrkQ
S5NY9NjL6Y7d5pNLYgg7ypXR//uRiJl0+Q==
-----END EC PRIVATE KEY-----
EOF
${SUDO} tee /var/lib/cilium/etcd/config.yaml <<EOF >/dev/null
---
trusted-ca-file: /var/lib/cilium/etcd/ca.crt
cert-file: /var/lib/cilium/etcd/tls.crt
key-file: /var/lib/cilium/etcd/tls.key
endpoints:
- https://clustermesh-apiserver.cilium.io:$CLUSTER_PORT
EOF

CILIUM_OPTS=" --join-cluster --enable-host-reachable-services --enable-endpoint-health-checking=false"
CILIUM_OPTS+=" --kvstore etcd --kvstore-opt etcd.config=/var/lib/cilium/etcd/config.yaml"
if [ -n "$HOST_IP" ] ; then
    CILIUM_OPTS+=" --ipv4-node $HOST_IP"
fi
if [ -n "$CONFIG_OVERWRITES" ] ; then
    CILIUM_OPTS+=" $CONFIG_OVERWRITES"
fi

DOCKER_OPTS=" -d --log-driver local --restart always"
DOCKER_OPTS+=" --privileged --network host --cap-add NET_ADMIN --cap-add SYS_MODULE"
# Run cilium agent in the host's cgroup namespace so that
# socket-based load balancing works as expected.
# See https://github.com/cilium/cilium/pull/16259 for more details.
DOCKER_OPTS+=" --cgroupns=host"
DOCKER_OPTS+=" --volume /var/lib/cilium/etcd:/var/lib/cilium/etcd"
DOCKER_OPTS+=" --volume /var/run/cilium:/var/run/cilium"
DOCKER_OPTS+=" --volume /boot:/boot"
DOCKER_OPTS+=" --volume /lib/modules:/lib/modules"
DOCKER_OPTS+=" --volume /sys/fs/bpf:/sys/fs/bpf"
DOCKER_OPTS+=" --volume /run/xtables.lock:/run/xtables.lock"
DOCKER_OPTS+=" --add-host clustermesh-apiserver.cilium.io:$CLUSTER_IP"

cilium_started=false
retries=4
while [ $cilium_started = false ]; do
    if [ -n "$(${SUDO} docker ps -a -q -f name=cilium)" ]; then
        echo "Shutting down running Cilium agent"
        ${SUDO} docker rm -f cilium || true
    fi

    echo "Launching Cilium agent $CILIUM_IMAGE..."
    ${SUDO} docker run --name cilium $DOCKER_OPTS $CILIUM_IMAGE cilium-agent $CILIUM_OPTS

    # Copy Cilium CLI
    ${SUDO} docker cp cilium:/usr/bin/cilium /usr/bin/cilium

    # Wait for cilium agent to become available
    for ((i = 0 ; i < 12; i++)); do
        if cilium status --brief > /dev/null 2>&1; then
            cilium_started=true
            break
        fi
        sleep 5s
        echo "Waiting for Cilium daemon to come up..."
    done

    echo "Cilium status:"
    cilium status || true

    if [ "$cilium_started" = true ] ; then
        echo 'Cilium successfully started!'
    else
        if [ $retries -eq 0 ]; then
            >&2 echo 'Timeout waiting for Cilium to start, retries exhausted.'
            exit 1
        fi
        ((retries--))
        echo "Restarting Cilium..."
    fi
done

# Wait for kube-dns service to become available
kubedns=""
for ((i = 0 ; i < 24; i++)); do
    kubedns=$(cilium service list get -o jsonpath='{[?(@.spec.frontend-address.port==53)].spec.frontend-address.ip}')
    if [ -n "$kubedns" ] ; then
        break
    fi
    sleep 5s
    echo "Waiting for kube-dns service to come available..."
done

namespace=$(cilium endpoint get -l reserved:host -o jsonpath='{$[0].status.identity.labels}' | tr -d "[]\"" | tr "," "\n" | grep io.kubernetes.pod.namespace | cut -d= -f2)

if [ -n "$kubedns" ] ; then
    if grep "nameserver $kubedns" /etc/resolv.conf ; then
	echo "kube-dns IP $kubedns already in /etc/resolv.conf"
    else
	linkval=$(readlink /etc/resolv.conf) && echo "$linkval" | ${SUDO} tee /etc/resolv.conf.link || true
	if [[ "$linkval" == *"/systemd/"* ]] ; then
	    echo "updating systemd resolved with kube-dns IP $kubedns"
	    ${SUDO} mkdir -p /usr/lib/systemd/resolved.conf.d
	    ${SUDO} tee /usr/lib/systemd/resolved.conf.d/cilium-kube-dns.conf <<EOF >/dev/null
# This file is installed by Cilium to use kube dns server from a non-k8s node.
[Resolve]
DNS=$kubedns
Domains=${namespace}.svc.cluster.local svc.cluster.local cluster.local
EOF
	    ${SUDO} systemctl daemon-reload
	    ${SUDO} systemctl reenable systemd-resolved.service
	    ${SUDO} service systemd-resolved restart
	    ${SUDO} ln -fs /run/systemd/resolve/resolv.conf /etc/resolv.conf
	else
	    echo "Adding kube-dns IP $kubedns to /etc/resolv.conf"
	    ${SUDO} cp /etc/resolv.conf /etc/resolv.conf.orig
	    resolvconf="nameserver $kubedns\n$(cat /etc/resolv.conf)\nsearch ${namespace}.svc.cluster.local svc.cluster.local cluster.local\n"
	    printf "$resolvconf" | ${SUDO} tee /etc/resolv.conf
	fi
    fi
else
    >&2 echo "kube-dns not found."
    exit 1
fi
