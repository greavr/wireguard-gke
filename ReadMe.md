## Install TF
Source
`https://learn.hashicorp.com/tutorials/terraform/install-cli`

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

## Run TF
```
cd tf/
terraform init
terraform plan
terraform apply -auto-approve
```
Then to destroy
```
terraform destroy -auto-approve`
```


## Connect To GKE and Run Manifests
Get kubernetes context:
```
gke=$(terraform output gke_connection_command | tr -d '"')
eval "$gke"
```

Update manifests with wireguard GCE instance IP & DNS:
```
wireguard_instance_ip=$(terraform output instance_ip_addr | tr -d '"')
echo $wireguard_instance_ip
gke_dns=$(kubectl -n kube-system get svc | grep kube-dns | awk '{print $3}')
echo $gke_dns
sed -i "s/WIREGUARD_IP/$wireguard_instance_ip/g" ../kubernetes/*
sed -i "s/GKE_DNS/$gke_dns/g" ../kubernetes/wireguard-config.yaml
```

Run Kubernetes Manifests
```
kubectl apply -f ../kubernetes/
```