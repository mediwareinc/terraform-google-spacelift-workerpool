terraform {
  required_providers {
    google = { source = "hashicorp/google" }
  }
}

variable "configuration" {
  type        = string
  description = <<EOF
  User configuration. This allows you to decide how you want to pass your token
  and private key to the environment - be that directly, or using SSM Parameter
  Store, Vault etc. Ultimately, here you need to export SPACELIFT_TOKEN and
  SPACELIFT_POOL_PRIVATE_KEY to the environment.
  EOF
}

variable "domain_name" {
  type        = string
  description = "Top-level domain name to use for pulling the launcher binary"
  default     = "spacelift.io"
}

variable "email" {
  type        = string
  description = "Service account email to use"
  default     = null
}

variable "project" {
  type        = string
  description = "GCP project to use"
  default     = null
}

variable "image" {
  type        = string
  description = "Disk image to use for workers"
  default     = "projects/spacelift-workers/global/images/spacelift-worker-us-1646835906-1jyej6pe"
}

variable "instance_group_manager_name" {
  type        = string
  description = "Name for instance group manager"
  default     = "spacelift-workers"
}

variable "instance_group_base_instance_name" {
  type        = string
  description = "Base name for instances in group"
  default     = "spacelift-worker"
}

variable "machine_type" {
  type        = string
  description = "Machine type to use for worker machines"
  default     = "e2-medium"
}

variable "network" {
  type        = string
  description = "Network to create workerpool in"
}

variable "subnetwork" {
  type        = string
  description = "Subnetwork to create workerpool in"
  default     = null
}

variable "subnetwork_project" {
  type        = string
  description = "Subnetwork project for creating workerpool in"
  default     = null
}

variable "network_tags" {
  type        = list(string)
  description = "Network tags to assign to workerpool VMs"
  default     = []
}

variable "region" {
  type        = string
  description = "Region to create workerpool in"
}

variable "size" {
  type        = string
  description = "Number of workers to create"
}

variable "zone" {
  type        = string
  description = "Zone to create workerpool in"
}

variable "service_account_scopes" {
  type        = list(string)
  default     = []
  description = "A list of custom OAuth scopes to add to the service account defined in the instance template"
}

variable "automatic_restart" {
  type        = string
  description = "Allow instance to be restarted by Google"
  default     = false
}

variable "enable_shielded_vm" {
  type        = string
  description = "Whether to enable the Shielded VM configuration on the instance. Note that the instance image must support Shielded VMs. See https://cloud.google.com/compute/docs/images"
  default     = false
}

variable "shielded_instance_config" {
  description = "Not used unless enable_shielded_vm is true. Shielded VM configuration for the instance."
  type = object({
    enable_secure_boot          = bool
    enable_vtpm                 = bool
    enable_integrity_monitoring = bool
  })

  default = {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
}

variable "labels" {
  description = "Resource labels"
  type        = map(string)
  default     = {}
}
