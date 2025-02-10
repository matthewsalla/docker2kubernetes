Docker to K3s Cluster Migration

Overview

This repository contains infrastructure-as-code (IaC) for deploying and managing a K3s Kubernetes cluster using Terraform on a KVM-based environment. The setup includes a control plane node and worker nodes with 1TB storage.

# TODO:  Update documentation!

📌 Features

- Automated K3s Cluster Deployment
- Dynamic VM Provisioning with Terraform
- Cloud-Init for VM Initialization

🚀 Getting Started

1️⃣ Prerequisites

Ensure you have the following installed:

- Terraform (>= 1.3.0)
- Libvirt / KVM
- Lens

2️⃣ Clone the Repository

3️⃣ Initialize Terraform

terraform init

4️⃣ Deploy VMs

terraform apply -auto-approve

5️⃣ Retrieve K3s Token


🛑 Common Issues:

Cloud-Init Failing: Check logs with:

journalctl -u cloud-init --no-pager | less

SSH Issues: Ensure SSH keys are correctly injected:

cat ~/.ssh/authorized_keys

K3s Agent Nodes Not Joining:

sudo cat /var/lib/rancher/k3s/agent/k3s-agent.log | grep 'token'


📌 Next Steps

✅ Finalize automated Terraform provisioning.

⏳ Set up Sealed Secrets for Kubernetes.

⏳ Deploy Longhorn and schedule backups.

📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you’d like to change.

🛠 Maintainers

Matt Salla (@matthewsalla)

📞 Contact

For questions, issues, or feature requests, open a GitHub issue or reach out to Matt Salla.

