terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

// Google Cloud provider & Beta
provider "google" {
  project = var.gcp-project-name
  region = var.region
  zone = var.zone
}
provider "google-beta" {
  project = var.gcp-project-name
}

# Enable Default SA
# Service Account
data "google_compute_default_service_account" "default" {
}

# Enable API's
resource "google_project_service" "enable-compute" {
  project = var.gcp-project-name
  service = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable-gke" {
  project = var.gcp-project-name
  service = "container.googleapis.com"
  disable_on_destroy = false
}