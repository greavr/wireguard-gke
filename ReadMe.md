## Install TF
Install Guide [Found Here](https://learn.hashicorp.com/tutorials/terraform/install-cli)

```
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform
terraform -install-autocomplete
```

## Install Kubectl
```
sudo apt-get install kubectl
```

## Install Helm
Install Guide [Found Here](https://helm.sh/docs/intro/install/)
```
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Install Cilium CLI
Install Guide [Found Here](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/
```
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz{,.sha256sum}
```

## Run TF
```
cd tf/
terraform init
terraform plan
terraform apply -auto-approve
```


## Connect To GKE and Run Manifests
Get kubernetes context:
```
gke=$(terraform output gke_connection_command | tr -d '"')
gke_dr=$(terraform output gke_dr_connection_command | tr -d '"')
gce_ssh=$(terraform output gce_ssh | tr -d '"')
gce_scp=$(terraform output gce_scp | tr -d '"')
eval "$gke"
```

# Install Guide
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

**Join the GCE Instance to the cluster mesh using [Cilium External Workloads](https://docs.cilium.io/en/v1.10/gettingstarted/external-workloads/)**
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


## Clean Up
Destroy with Terraform
```
terraform destroy -auto-approve`
```
