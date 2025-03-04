# Create a key pair to access control-plane node for k3s_token
resource "tls_private_key" "cluster_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}


# Create a storage pool for attached drives
resource "libvirt_pool" "k3s_cluster_main_pool_main" {
  name = var.k3s_cluster_main_pool_name
  type = "dir"
  
  target {
    path = var.k3s_cluster_main_pool
  }
}

resource "libvirt_pool" "longhorn_pools" {
  for_each = { for key, value in var.k3s_nodes : key => value if value.longhorn_disk != "" }

  name = each.value.longhorn_pool_name
  type = "dir"

  target {
    path = each.value.longhorn_pool_path
  }
}

# Create a 1TB QCOW2 disk for Longhorn storage
resource "libvirt_volume" "longhorn_disks" {
  for_each = { for key, value in var.k3s_nodes : key => value if value.longhorn_disk != "" }

  name     = "${each.value.longhorn_disk}"
  pool   = libvirt_pool.longhorn_pools[each.key].name  # Use dynamically created pools
  format   = "qcow2"
  size     = 1073741824000  # 1TB in bytes

  depends_on = [libvirt_pool.longhorn_pools]  # Ensure storage pool is created first
}

# Base Ubuntu image
resource "libvirt_volume" "k3s_base_disks" {
  for_each  = var.k3s_nodes

  name   = "disk-${each.key}.qcow2"

  pool   = libvirt_pool.k3s_cluster_main_pool_main.name
  
  # Clone the base image instead of using it directly
  base_volume_id = libvirt_volume.base_image.id
  size   = each.value.disk * 1024 * 1024 * 1024
  
  format = "qcow2"
}

# Define the base image volume separately
resource "libvirt_volume" "base_image" {
  name   = "ubuntu-base.qcow2"
  pool   = libvirt_pool.k3s_cluster_main_pool_main.name
  source = var.ubuntu_image_url
  format = "qcow2"
}

# Cloud-init disk using the user_data from cloud_init.cfg
resource "libvirt_cloudinit_disk" "commoninit" {
  for_each  = var.k3s_nodes

  name      = "commoninit-${each.key}.iso"
  pool      = libvirt_pool.k3s_cluster_main_pool_main.name
  user_data = templatefile("${path.module}/config/cloud_init.cfg", { 
    ssh_key    = file(var.ssh_key)
    cluster_private_key = tls_private_key.cluster_key.private_key_pem
    cluster_public_key   = tls_private_key.cluster_key.public_key_openssh
    hostname   = each.value.hostname
    node_type    = each.value.cloud_init  # "control-plane" or "worker-node"
    control_ip   = var.k3s_nodes["atlasmalt-control-plane"].ip_address
  })
  network_config = templatefile("${path.module}/config/network_config.cfg", {
    ip_address = each.value.ip_address
    gateway_ip = var.gateway_ip
  })

}

# Define the VM domain
resource "libvirt_domain" "k3_nodes" {
  for_each  = var.k3s_nodes

  name      = each.key
  memory    = each.value.ram
  vcpu      = each.value.vcpu

  cloudinit = libvirt_cloudinit_disk.commoninit[each.key].id

  disk {
    volume_id = libvirt_volume.k3s_base_disks[each.key].id
  }

  # Attach the Longhorn disk only for worker nodes
  dynamic "disk" {
    for_each = each.value.longhorn_disk != "" ? [1] : []
    content {
      volume_id = libvirt_volume.longhorn_disks[each.key].id
    }
  }

  network_interface {
    bridge   = "bri0"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  # Apply XSLT transformation to modify the libvirt XML
  xml {
    xslt = file("${path.module}/config/memory_backing.xslt")
  }

  qemu_agent = true  # Enable qemu-guest-agent support
}

# Output the VM's IP address
output "vm_ips" {
  description = "IP addresses of all VMs"
  value = {
    for vm in libvirt_domain.k3_nodes :
    vm.name => vm.network_interface[0].addresses[0]
  }
}

