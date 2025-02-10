variable "ubuntu_image_url" {
  default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "libvirt_user" {
  type        = string
  description = "username used for logging into libvirtd with SSH"
}

variable "k3s_cluster_main_pool" {
  type        = string
  description = "Main storage pool for all nodes"
}

variable "k3s_cluster_main_pool_name" {
  type        = string
  description = "Main storage pool name for all nodes"
}

# Create a storage pools for distributed drives
variable "longhorn_storage_pools" {
  type = map(string)
}

variable "control_plane_ip" {
  type        = string
  description = "IP address of the K3s control plane"
}

variable "worker_node_ips" {
  type = map(string)
  description = "Worker node IP addresses"
}

variable "gateway_ip" {
  type        = string
  description = "IP address of the Gateway (typically the router)"
}

variable "host_ip" {
  type        = string
  description = "IP address of the Host"
}

# Uses default public key for SSH access to VMs
variable "ssh_key" {
  type  = string
  default = "~/.ssh/id_rsa.pub"
}

variable "k3s_nodes" {
  type = map(object({
    vcpu              = number
    ram               = number
    disk              = number
    cloud_init        = string  # e.g. "control-plane" or "worker-node"
    longhorn_disk_path = string # If non-empty, create & attach a 1TB disk
    ip_address        = string
    hostname          = string
  }))
}
