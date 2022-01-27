## Outline
Create two GKE confidential compute clusters, one GCE confidential compute instance. On the GCE instance will install NFS-Server and mount a share __/export/kubernetes__, for use in a GKE POD volume mount. It will also create required firewall rules and components for wireguard.

## Compontents used:
- **Terraform**
    - Used to provision GCP Resources
- **Kubectl**
    - Used to configure kubernetes clusters
- **Cilium CLI**
    - Used to configure Cilium (post helm install)
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
- **gke_context1**
    - The kubectl context name created for GKE Primary cluster. Used for multi-cluster setup
- **gke_context2**
    - The kubectl context name created for GKE DR cluster. Used for multi-cluster setup

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
eval $(terraform output gke_context1 | tr -d '"')
eval $(terraform output gke_context2 | tr -d '"')
eval "$gke"
```

## Install Cilium
**Primary Cluster**
```
eval "$gke"
cilium install --cluster-id 1 --cluster-name gke --encryption ipsec
cilium clustermesh enable
kubectl get secret -n kube-system -o yaml cilium-ipsec-keys > cilium-ipsec-keys.yaml
```
**Secondary Cluster**
```
eval "$gke_dr"
kubectl apply -f cilium-ipsec-keys.yaml
cilium install --cluster-id 2 --cluster-name backup --encryption ipsec --inherit-ca $CLUSTER1
cilium clustermesh enable
```
This configures internode encryption using IPsec, and configured cilium to create its own ETCD used for multi-cluster meshing. Each cluster must be set with a unique **cluster.id** however **cluster.name** must be shared amongst all clusters in the environment.

**Now we create the cluster mesh**
```
cilium --context $CLUSTER1 clustermesh connect --destination-context $CLUSTER2
```

## UNDER REVIEW
This content is not currently working using the simpler server mesh. As of : **01/27/2022**
**Join the GCE Instance to the cluster mesh using**
Based on: [Cilium External Workloads](https://docs.cilium.io/en/v1.10/gettingstarted/external-workloads/)<br />
From the CLI run the command:
```
cilium clustermesh vm create gce-nfs -n default --ipv4-alloc-cidr 10.192.1.0/30
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
