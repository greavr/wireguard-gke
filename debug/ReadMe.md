# Debug Commands
### Enter nfs-web pod
```
kubectl exec -it --tty nfs-web -- /bin/sh
```
### Check Ciliums status
```
cilium status
cilium clustermesh vm status
kubectl -n kube-system exec -ti cilium-g6btl -- cilium node list
```
### Check traffic is encrypted
On the GCE NFS Instance
```
docker exec -ti cilium bash

apt-get update
apt-get -y install tcpdump
```

On a GKE cluster
```
kubectl -n kube-system get pods
```

**Then use one of the cilium pod names (none etcd)**
```
kubectl -n kube-system exec -ti <cilium pod> -- bash

apt-get update
apt-get -y install tcpdump
tcpdump -n -i cilium_vxlan
```

### Check Connectivity from GCE instance to GKE Cluster through cilium
On GCE Instance
```
ping $(cilium service list get -o jsonpath='{[?(@.spec.flags.name=="clustermesh-apiserver")].spec.backend-addresses[0].ip}')
```

### Check Connectivity between clusters
From any machine (requires context environment variables from multi-cluster, these are just kubernetes context names)
```
cilium connectivity test --context $CLUSTER1 --multi-cluster $CLUSTER2
```

[Main Page](../)