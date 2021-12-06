## Firewall rules

# NFS Ports
resource "google_compute_firewall" "nfs" {
  name    = "allow-nfs"
  network = var.gcp-vpc


  allow {
    protocol = "tcp"
    ports    = ["111", "2049"]

  }

  allow {
    protocol = "udp"
    ports    = ["111", "2049"]

  }

  source_ranges = [var.vpc-cidr]
  target_tags = ["nfs"]

  depends_on = [google_project_service.enable-compute]
}

# wireguard Ports
resource "google_compute_firewall" "wireguard" {
  name    = "allow-wireguard"
  network = var.gcp-vpc

  allow {
    protocol = "udp"
    ports    = ["111"]

  }

  source_ranges = [var.vpc-cidr]
  target_tags = ["wireguard"]

  depends_on = [google_project_service.enable-compute]
}

# ssh Ports
resource "google_compute_firewall" "gke-ssh" {
  name    = "allow-ssh"
  network = var.gcp-vpc

  allow {
    protocol = "tcp"
    ports    = ["22"]

  }

  source_ranges = [var.vpc-cidr]
  target_tags = ["ssh"]

  depends_on = [google_project_service.enable-compute]
}