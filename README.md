### **🚀 README.md – Docker to Kubernetes Migration (AtlasMalt K3s Cluster)**  

# **Docker to Kubernetes Migration (AtlasMalt K3s Cluster)**  

This repository provides a **structured, automated, and secure** migration process from **Docker to Kubernetes (K3s)**. It includes **Helm-based deployments, infrastructure provisioning (Terraform), persistent storage (Longhorn), GitOps principles, and security best practices** to ensure a **scalable, production-ready Kubernetes cluster**.  

---

## **📂 Repository Overview**  
| **Directory** | **Description** |
|--------------|----------------|
| `kubernetes/apps/` | Kubernetes manifests for individual apps (IngressRoutes, Services, Deployments). |
| `kubernetes/certs/` | Cert-Manager configurations for TLS certificates. Sealed Secrets Public Key|
| `kubernetes/cluster-issuers/` | ClusterIssuer definitions for Let's Encrypt staging & production. |
| `kubernetes/helm/values/` | Helm values for application deployments. |
| `kubernetes/middlewares/` | Traefik middlewares for authentication & security. |
| `kubernetes/scripts/` | Automation scripts for deploying infrastructure & applications. |
| `kubernetes/secrets/` | **SealedSecrets for securely managing credentials**. |
| `terraform/` | Terraform scripts to provision infrastructure (VMs, networking, storage). |

---

## **🚀 Migration Strategy: Docker to Kubernetes**
A **7-step structured approach** ensures a smooth and repeatable **Docker to Kubernetes application migration**.  

### **1️⃣ App Assessment & Requirements**
- Identify **dependencies** (databases, volumes, env variables, secrets).  
- Determine **persistent storage needs** (PVCs via Longhorn).  
- Define **resource limits & requests** for optimal performance.  

### **2️⃣ Helm Chart Deployment (Preferred)**
- Use **Helm charts** for all applications.  
- Customize **`values.yaml`** to match app requirements.  
- Store **Helm charts in version control for upgrades**.  

### **3️⃣ Direct-to-Production Deployment**
- Deploy applications **directly to production** using Helm.  
- Use **Let's Encrypt Staging** for certificate validation (initial).  
- **Verify application functionality in production** before switching to Let's Encrypt Prod.  

### **4️⃣ Certificate & Security Validation**
- Use **SealedSecrets for credentials**.  
- Validate **TLS certificates with Let's Encrypt Staging**.  
- Test **authentication & access controls**.  
- Review **RBAC policies for correct permissions**.  

### **5️⃣ Monitoring & Logging Setup**
- Ensure **Prometheus/Grafana track application health**.  
- Configure **alerting for failures & anomalies**.  
- Verify **Longhorn storage metrics** are available.  

### **6️⃣ Post-Migration Cleanup**
- **Decommission old Docker-based setup**.  
- Archive **Docker Compose configurations for reference**.  
- Document **the migration for future apps**.  

---

## **📦 Kubernetes Deployment Breakdown**
This repo provisions and manages a **fully automated K3s cluster** with the following components:  

| **Component** | **Description** | **Deployment Method** |
|--------------|----------------|--------------------|
| **K3s** | Lightweight Kubernetes distribution | Terraform (`cloud_init.cfg`) |
| **Longhorn** | Persistent storage solution | Helm (`deploy-longhorn.sh`) |
| **Traefik v3** | Ingress controller with TLS | Helm (`deploy-traefik.sh`) |
| **Cert-Manager** | TLS certificate automation | Helm (`deploy-cert-manager.sh`) |
| **Prometheus & Grafana** | Monitoring stack | Helm (`deploy-monitoring.sh`) |
| **SealedSecrets** | Encrypted Kubernetes secrets | Helm (`deploy-sealed-secrets.sh`) |

---

## **⚡ Quick Start Guide**
### **1️⃣ Prerequisites**
- **Ubuntu 24.04** server  
- **Helm & Kubectl installed**  
- **Terraform installed**  

### **2️⃣ Deploy Kubernetes Cluster**
```bash
cd terraform
terraform init
terraform apply
```

### **3️⃣ Deploy Core Infrastructure**
```bash
cd kubernetes/scripts/helpers
./deploy-sealed-secrets.sh
./deploy-cert-manager.sh
./deploy-traefik.sh
./deploy-longhorn.sh
./deploy-monitoring.sh
```

### **4️⃣ Deploy Applications**
```bash
./deploy-mealie.sh
./deploy-whoami.sh
```

### **5️⃣ Verify Deployment**
```bash
kubectl get pods -A
kubectl get ingressroute -A
kubectl get certificate -A
```

---

## **🛠 Troubleshooting Logs**
### **Grafana Authentication Failures**
✅ **Issue:** "Failed to authenticate request" errors in logs.  
✅ **Fix:**  
- **Removed Traefik middleware authentication** (was redundant).  
- **Cleared browser cache** (Cognito mode confirmed caching issue).  
- **Restarted Grafana to reset authentication state**.  

### **Prometheus PVC Binding Issues**
✅ **Issue:** PVCs were not attaching properly.  
✅ **Fix:**  
- Used **`storageSpec.volumeClaimTemplate`** instead of `persistentVolume`.  
- Ensured **Longhorn was set as the default storage class**.  

### **Debugging Grafana-Prometheus Connectivity**
✅ **Issue:** Grafana dashboards showed **"No Data"**.  
✅ **Fix:**  
- **Verified Prometheus service endpoint** (`kubectl get svc -n monitoring`).  
- **Updated `datasources.yaml`** in Grafana with the correct Prometheus URL.  

## Virsh Overview Command

Run the following one-liner to get an overview of your current virsh state:

```bash
echo "=== Storage Pools ===" && virsh pool-list --all && echo "=== Domains ===" && virsh list --all && echo "=== Volumes per Pool ===" && for pool in $(virsh pool-list --name); do echo "Pool: $pool"; virsh vol-list --pool "$pool"; echo "----------------"; done
```

---

## **🔮 Future Enhancements**
🔹 **Solve Persistent Storage Across Cluster Nukes**  
🔹 **Implement Longhorn Backup & Restore Strategy**  
🔹 **Integrate ArgoCD for GitOps & Deployment Automation**  
🔹 **Migrate Additional Stateful Apps (Nextcloud, Firefly III, Logitech Media Server, etc.)**  

---

## **🤝 Contributions & Feedback**
This is an active migration project!  If you have **improvements, issues, or suggestions**, feel free to **open a PR or discussion**.  

---

### **📢 Shoutout**
This project is part of my **ongoing Kubernetes migration series**.  Follow along as I **move more services from Docker to K3s** while optimizing performance, security, and automation. 🚀  

#Kubernetes #K3s #DockerToK8s #DevOps #InfrastructureAsCode #CloudComputing  
