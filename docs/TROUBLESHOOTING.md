### 📌 Troubleshooting: Longhorn Volume Not Attached  

If you see this error:  

```json
"message": "failed to create snapshot: cannot get client for volume mealie-pv on node atlasmalt-kube-vm-control: engine is not running"
```

It likely means the **Persistent Volume (PV) is detached** and not bound to the deployment.  

#### ✅ **Fix: Ensure PVC is Correctly Referenced**  
In `values.yaml`, explicitly reference the existing claim:  

```yaml
persistence:
  data:
    enabled: true
    existingClaim: mealie-pvc
    mountPath: /app/data
```

Apply the update:  
```sh
helm upgrade --install mealie ./mealie -n mealie
```

#### 🔄 **Check If PVC Is Bound**  
```sh
kubectl get pvc -n mealie
```
Expected output:
```
NAME         STATUS   VOLUME      STORAGECLASS   AGE
mealie-pvc   Bound    mealie-pv   longhorn       5m
```
If **not bound**, check PV status:  
```sh
kubectl get pv | grep mealie
```
If `mealie-pv` is **detached**, manually re-attach it.

#### 🔧 **Manually Attach the Longhorn Volume**  
```sh
kubectl -n longhorn-system patch volumes.longhorn.io mealie-pv --type='merge' -p '{"spec":{"nodeID":"<NODE_NAME>"}}'
```
Replace `<NODE_NAME>` with the correct node. Then restart Mealie:  
```sh
kubectl rollout restart deployment mealie -n mealie
```

#### 🔍 **Verify Fix**  
```sh
kubectl exec -n mealie -it $(kubectl get pod -n mealie -o jsonpath="{.items[0].metadata.name}") -- df -h | grep /app/data
```
Expected output:
```
/dev/longhorn/mealie-pv  10G  1G  9G  10% /app/data
```

#### 🚀 **Prevention**  
1. Ensure **`existingClaim`** is set before deploying.  
2. Check Longhorn volumes before making changes:  
   ```sh
   kubectl get volumes -n longhorn-system
   ```
3. Use `helm template` to verify correct volume mounting:  
   ```sh
   helm template mealie ./mealie -n mealie | less
   ```
