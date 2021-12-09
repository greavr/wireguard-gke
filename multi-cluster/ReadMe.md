# Configure Multi-cluster server mesh
(Reference Guide Found On Cilium Documentation)[https://docs.cilium.io/en/v1.10/gettingstarted/clustermesh/clustermesh/#gs-clustermesh]
## Export CA & IPSec secret from Primary Cluster
```
kubectl get secrets/cilium-ipsec-keys -n kube-system -o yaml > cilium-ipsec-keys.yaml
kubectl get secrets/cilium-ca -n kube-system -o yaml > cilium-ca.yaml
kubectl get secrets/cilium-etcd-secrets -n kube-system -o yaml > cilium-etcd-secrets.yaml
kubectl get secrets/clustermesh-apiserver-client-certs -n kube-system -o yaml > clustermesh-apiserver-client-certs.yaml
kubectl get secrets/clustermesh-apiserver-external-workload-certs -n kube-system -o yaml > clustermesh-apiserver-external-workload-certs.yaml 
```

## Change Context to Backup GKE Cluster
The below will create two environmental variables and setup kubectl context for the GKE DR Cluster
```
eval $gke_context1
eval $gke_context2
eval $gke_dr
```
We can validate the context with `echo $CLUSTER1` if nothing is returned run the command from the terraform outputs for **gke_context1** and **gke_context2** to create environment variables.

## Install cilium on the DR Cluster
Apply the secrets we exported and clean them up
```
kubectl apply -f cilium-ipsec-keys.yaml
kubectl apply -f cilium-ca.yaml
kubectl apply -f cilium-etcd-secrets.yaml
kubectl apply -f clustermesh-apiserver-client-certs.yaml
kubectl apply -f clustermesh-apiserver-external-workload-certs.yaml
rm cilium-ipsec-keys.yaml
rm cilium-ca.yaml
rm cilium-etcd-secrets.yaml
rm clustermesh-apiserver-client-certs.yaml
rm clustermesh-apiserver-external-workload-certs.yaml
```

Now use helm to install cilium
```
helm install cilium cilium/cilium --version 1.10.5 \
   --namespace kube-system \
   --set etcd.enabled=true \
   --set etcd.managed=true \
   --set etcd.k8sService=true \
   --set encryption.enabled=true \
   --set encryption.nodeEncryption=false \
   --set identityAllocationMode=kvstore \
   --set encryption.type=ipsec \
   --set externalWorkloads.enabled=true \
   --set cluster.id=2 \
   --set cluster.name=dr \
   --set cni.binPath=/home/kubernetes/bin
```

Check Cluster Mesh is enabled:
```
cilium clustermesh status --context $CLUSTER1 --wait
cilium clustermesh status --context $CLUSTER2 --wait
```

Both should be green, now we enable cluster mesh with:
```
cilium clustermesh connect --context $CLUSTER1 --destination-context $CLUSTER2
```

[Main Page](../)