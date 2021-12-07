## Create GKE Cluster
resource "google_container_cluster" "primary" {
    name     = "${var.gcp-project-name}-gke"
    location = var.region

    release_channel {
        channel = "RAPID"
    }
    
    networking_mode = "VPC_NATIVE"
    ip_allocation_policy {
        cluster_ipv4_cidr_block  = ""
        services_ipv4_cidr_block = ""
    } 

    node_pool {
        initial_node_count = 1    
        node_config {
            preemptible  = false
            machine_type = "n2d-standard-4"
            disk_size_gb = "100"
            disk_type    = "pd-standard"
            # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
            oauth_scopes = [
            "https://www.googleapis.com/auth/cloud-platform"
            ]
            labels = {}
            tags = []
        }
    }


    timeouts {
        create = "30m"
        update = "40m"
    }
    
    depends_on = [google_project_service.enable-gke]


    confidential_nodes {
        enabled = true
    }
}

resource "google_container_cluster" "backup" {
    name     = "${var.gcp-project-name}-gke-backup"
    location = var.region-dr

    release_channel {
        channel = "RAPID"
    }
    
    networking_mode = "VPC_NATIVE"
    ip_allocation_policy {
        cluster_ipv4_cidr_block  = ""
        services_ipv4_cidr_block = ""
    } 

    node_pool {
        initial_node_count = 1    
        node_config {
            preemptible  = false
            machine_type = "n2d-standard-2"
            disk_size_gb = "100"
            disk_type    = "pd-standard"
            # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
            oauth_scopes = [
            "https://www.googleapis.com/auth/cloud-platform"
            ]
            labels = {}
            tags = []
        }
    }


    timeouts {
        create = "30m"
        update = "40m"
    }
    
    depends_on = [google_project_service.enable-gke]


    confidential_nodes {
        enabled = true
    }
}


## Output GKE Connection String
output "gke_connection_command" {
  value = format("gcloud container clusters get-credentials %s --region %s --project %s",google_container_cluster.primary.name,var.region,var.gcp-project-name)
}

output "gke_dr_connection_command" {
  value = format("gcloud container clusters get-credentials %s --region %s --project %s",google_container_cluster.backup.name,var.region-dr,var.gcp-project-name)
}