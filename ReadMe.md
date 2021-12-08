## Outline
Create two GKE confidential compute clusters, one GCE confidential compute instance. On the GCE instance will install NFS-Server and mount a share __/export/kubernetes__, for use in a GKE POD volume mount. It will also create required firewall rules and components for wireguard.

## Compontents used:
- **Terraform**
    - Used to provision GCP Resources
- **Kubectl**
    - Used to configure kubernetes clusters
- **Cilium CLI**
    - Used to configure Cilium (post helm install)
- **Helm**
    - Install Cilium on cluster with required values
- **Gcloud**
    - Send commands to GCE instances

## Terraform Output:
- **gce_scp**
    - Used to generate cli bash command to upload Cilium serrver agent to upload cilium remote-server install script
- **gce_ssh**
    - Used to generate cli bash command to remote execute cilium server agent install script
- **gke_connection_command**
    - Used to get kubectl context for primary cluster
- **gke_dr_connection_command**
    - Used to get kubectl context for dr cluster

# Tool Setup Guide

[Tool Install Guide](tools/ReadMe.md)

# Install Guide

## Run Terrafrom and capture output
From workstation run terraform commands
```
cd tf/
terraform init
terraform plan
terraform apply -auto-approve
```
Now we will capture the terraform outputs to environment variables
```
gke=$(terraform output gke_connection_command | tr -d '"')
gke_dr=$(terraform output gke_dr_connection_command | tr -d '"')
gce_ssh=$(terraform output gce_ssh | tr -d '"')
gce_scp=$(terraform output gce_scp | tr -d '"')
nfs_ip=$(terraform output instance_ip_addr | tr -d '"')
eval "$gke"
```

## Install Cilium
**Generate IPsec Key**
```
kubectl create -n kube-system secret generic cilium-ipsec-keys \
    --from-literal=keys="3 rfc4106(gcm(aes)) $(echo $(dd if=/dev/urandom count=20 bs=1 2> /dev/null | xxd -p -c 64)) 128"
```

**Configure Cilium Cluster with Helm**
```
helm repo add cilium https://helm.cilium.io/

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
   --set cluster.id=1 \
   --set cluster.name=matrixx \
   --set cni.binPath=/home/kubernetes/bin
```
This configures internode encryption using IPsec, and configured cilium to create its own ETCD used for multi-cluster meshing. Each cluster must be set with a unique **cluster.id** however **cluster.name** must be shared amongst all clusters in the environment.

**Now we create the cluster mesh**
```
cilium clustermesh enable \
   --create-ca
```

**Join the GCE Instance to the cluster mesh using**
Based on: [Cilium External Workloads](https://docs.cilium.io/en/v1.10/gettingstarted/external-workloads/)<br />
From the CLI run the command:
```
cilium clustermesh vm create gce-wireguard -n default --ipv4-alloc-cidr 10.192.1.0/30
```

**Now we install and configure cilium on external workloads**
```
cilium clustermesh vm install install-external-workload.sh
```

**Now copy the file to the instance and run the script**
```
eval $gce_scp
```
The above command will scp the install script to the instance
```
eval $gce_ssh
```
The above command will install the cilium agent and join the instance to the cluster. We can validate the configuration with the commands:
```
cilium clustermesh vm status
```

# Setup Multi-cluster Server Mesh
[Install Guide](multi-cluster/ReadMe.md)

# Run Sample pod with NFS Volume
Update the __sample-pod.yaml__ with the NFS Server IP
```
sed -i "s/NFS-SERVER-IP/$nfs_ip/g" ../kubernetes/sample-pod.yaml
kubectl apply -f ../kubernetes/sample-pod.yaml
```

# Debug / Troubleshooting
[Debug Guide](debug/ReadMe.md)

## Clean Up
Destroy with Terraform
```
terraform destroy -auto-approve`
```
