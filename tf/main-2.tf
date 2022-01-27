## Create GCE Instance used for wireguard and NFS Server
resource "google_compute_instance" "gce-nfs" {
    name         = "gce-nfs"
    machine_type = "n2d-standard-2"
    zone         = var.zone

    tags = ["nfs", "wireguard", "ssh"]

    confidential_instance_config {
        enable_confidential_compute = true
    }

    boot_disk {
        initialize_params {
            image = "ubuntu-os-cloud/ubuntu-2004-lts"
            size  = "20"
        }
    }

    scheduling {
        on_host_maintenance = "TERMINATE"
    }

    network_interface {
        network = "default"
        access_config {
            // Ephemeral public IP
        }
    }

    metadata = {
        foo = "bar"
    }

    metadata_startup_script = file("${path.module}/artifacts/startup_script.sh")

    service_account {
        scopes = ["cloud-platform"]
    }

    depends_on = [google_project_service.enable-compute]
}


## Output Instance IP
output "instance_ip_addr" {
  value = google_compute_instance.gce-nfs.network_interface.0.network_ip 
}

output "gce_ssh" {
    value = format("gcloud beta compute ssh --zone '%s' '%s' --project '%s' --command='chmod +x ~/install-external-workload.sh && sudo ~/install-external-workload.sh && cilium status'",var.zone,google_compute_instance.gce-nfs.name,var.gcp-project-name)
}

output "gce_scp"{
    value = format("gcloud compute scp ./install-external-workload.sh %s:~/install-external-workload.sh --zone=%s",google_compute_instance.gce-nfs.name, var.zone)
}