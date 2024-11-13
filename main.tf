locals {
  user_data_head = <<EOF
#!/bin/bash

spacelift () {(
set -e
  EOF

  user_data_tail = <<EOF
currentArch=$(uname -m)

if [[ "$currentArch" != "x86_64" && "$currentArch" != "aarch64" ]]; then
  echo "Unsupported architecture: $currentArch" >> /var/log/spacelift/error.log
  return 1
fi

baseURL="https://downloads.${var.domain_name}/spacelift-launcher"
binaryURL=$(printf "%s-%s" "$baseURL" "$currentArch")
shaSumURL=$(printf "%s-%s_%s" "$baseURL" "$currentArch" "SHA256SUMS")
shaSumSigURL=$(printf "%s-%s_%s" "$baseURL" "$currentArch" "SHA256SUMS.sig")

echo "Downloading Spacelift launcher" >> /var/log/spacelift/info.log
curl "$binaryURL" --output /usr/bin/spacelift-launcher 2>>/var/log/spacelift/error.log

echo "Importing public GPG key" >> /var/log/spacelift/info.log
curl https://keys.openpgp.org/vks/v1/by-fingerprint/175FD97AD2358EFE02832978E302FB5AA29D88F7 | gpg --import 2>>/var/log/spacelift/error.log

echo "Downloading Spacelift launcher checksum file and signature" >> /var/log/spacelift/info.log
curl "$shaSumURL" --output spacelift-launcher_SHA256SUMS 2>>/var/log/spacelift/error.log
curl "$shaSumSigURL" --output spacelift-launcher_SHA256SUMS.sig 2>>/var/log/spacelift/error.log

echo "Verifying checksum signature..." >> /var/log/spacelift/info.log
gpg --verify spacelift-launcher_SHA256SUMS.sig 1>>/var/log/spacelift/info.log 2>>/var/log/spacelift/error.log

retStatus=$?
if [ $retStatus -eq 0 ]; then
    echo "OK\!" >> /var/log/spacelift/info.log
else
    return $retStatus
fi

CHECKSUM=$(cut -f 1 -d ' ' spacelift-launcher_SHA256SUMS)
rm spacelift-launcher_SHA256SUMS spacelift-launcher_SHA256SUMS.sig
LAUNCHER_SHA=$(sha256sum /usr/bin/spacelift-launcher | cut -f 1 -d ' ')

echo "Verifying launcher binary..." >> /var/log/spacelift/info.log
if [[ "$CHECKSUM" == "$LAUNCHER_SHA" ]]; then
  echo "OK\!" >> /var/log/spacelift/info.log
else
  echo "Checksum and launcher binary hash did not match" >> /var/log/spacelift/error.log
  return 1
fi

echo "Making the Spacelift launcher executable" >> /var/log/spacelift/info.log
chmod 755 /usr/bin/spacelift-launcher 2>>/var/log/spacelift/error.log

echo "Retrieving GCP Instance ID" >> /var/log/spacelift/info.log
export SPACELIFT_METADATA_gcp_instance_id=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/id" -H "Metadata-Flavor: Google")

echo "Retrieving GCP VM Name" >> /var/log/spacelift/info.log
export SPACELIFT_METADATA_gcp_instance_name=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")

echo "Retrieving GCP VM Zone" >> /var/log/spacelift/info.log
export SPACELIFT_METADATA_gcp_zone=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google")

echo "Retrieving GCP VM Machine Type" >> /var/log/spacelift/info.log
export SPACELIFT_METADATA_gcp_machine_type=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/machine-type" -H "Metadata-Flavor: Google")

export SPACELIFT_METADATA_cloud_provider=gcp

echo "Starting the Spacelift binary" >> /var/log/spacelift/info.log
/usr/bin/spacelift-launcher 1>>/var/log/spacelift/info.log 2>>/var/log/spacelift/error.log
)}

spacelift
echo "Powering off in 15 seconds" >> /var/log/spacelift/error.log
sleep 15
poweroff
  EOF
}

resource "google_compute_instance_template" "spacelift-worker" {
  name_prefix  = "${var.instance_group_base_instance_name}-"
  machine_type = var.machine_type
  region       = var.region
  project      = var.project
  tags         = var.network_tags

  disk {
    source_image = var.image
    disk_size_gb = var.boot_disk_size
  }

  network_interface {
    network            = var.network
    subnetwork         = var.subnetwork
    subnetwork_project = var.subnetwork_project
  }

  service_account {
    email  = var.email
    scopes = var.service_account_scopes
  }

  dynamic "shielded_instance_config" {
    for_each = var.enable_shielded_vm ? ["shield"] : []

    content {
      enable_secure_boot          = var.shielded_instance_config.enable_secure_boot
      enable_vtpm                 = var.shielded_instance_config.enable_vtpm
      enable_integrity_monitoring = var.shielded_instance_config.enable_integrity_monitoring
    }
  }

  metadata_startup_script = join("\n", [
    local.user_data_head,
    var.configuration,
    local.user_data_tail,
  ])

  scheduling {
    automatic_restart   = var.automatic_restart
    on_host_maintenance = "MIGRATE"
  }

  labels = var.labels
}

resource "google_compute_instance_group_manager" "spacelift-worker" {
  lifecycle {
    replace_triggered_by = [google_compute_instance_template.spacelift-worker]
  }

  name = var.instance_group_manager_name

  base_instance_name = var.instance_group_base_instance_name
  zone               = var.zone
  project            = var.project

  version {
    instance_template = google_compute_instance_template.spacelift-worker.id
  }

  target_size = var.worker_count

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_percent     = 20
    max_unavailable_fixed = 2
    replacement_method    = "SUBSTITUTE"
  }
}
