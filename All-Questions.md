# CKA Exam – Corrected, Exam‑Safe Master Notes (Reworked)

This document is a **clean, verified rewrite** of the original MD. Every section below is:
- syntactically valid
- aligned with Kubernetes/Helm behavior
- exam‑safe (no chart‑specific traps unless unavoidable)

If something is ambiguous in the exam, the **safest deterministic approach** is documented.

---

## 1. Argo CD – Helm Template (CRDs already installed)

### Goal
- Render manifests for Argo CD **without installing CRDs**
- Save output to a file

### Correct, exam‑safe solution

```bash
helm repo add argo https://argoproj.github.io/argo-helm
kubectl create namespace argocd

helm template argocd argo/argo-cd \
  --version 7.7.3 \
  --namespace argocd \
  --skip-crds \
  > /root/argo-helm.yaml
```

### Why this is correct
- `--skip-crds` is a **Helm guarantee** (not chart‑specific)
- No reliance on `values.yaml` internals
- Output will never contain `CustomResourceDefinition`

Verification:
```bash
grep -i CustomResourceDefinition /root/argo-helm.yaml
# expect: no output
```

---

## 2. Sidecar Container with Shared Volume

### Goal
- Add sidecar container
- Share logs via a common volume

### Correct pattern

```yaml
spec:
  template:
    spec:
      volumes:
      - name: log
        emptyDir: {}

      containers:
      - name: app
        image: wordpress
        volumeMounts:
        - name: log
          mountPath: /var/log

      - name: sidecar
        image: busybox:stable
        command: ["/bin/sh", "-c", "tail -f /var/log/wordpress.log"]
        volumeMounts:
        - name: log
          mountPath: /var/log
```

### Rules
- `volumeMounts.name` **must match** `volumes.name`
- Sidecar is a **normal container**, not an initContainer

---

## 3. Gateway API – Replace Existing Ingress

### Goal
- Replace Ingress with Gateway + HTTPRoute
- Preserve TLS + routing

### Gateway (TLS termination)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: web-app
spec:
  gatewayClassName: nginx-class
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: gateway.web.k8s.local
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: web-tls
```

### HTTPRoute (routing)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
  namespace: web-app
spec:
  parentRefs:
  - name: web-gateway
  hostnames:
  - gateway.web.k8s.local
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: web-service
      port: 80
```

### Common failure points
- Missing `metadata.namespace`
- Invalid port values
- Forgetting TLS `mode: Terminate`

---

## 4. Resource Requests & Limits (CPU / Memory)

### Strategy
1. Check allocatable resources on node
2. Subtract current system usage
3. Reserve ~10% headroom
4. Divide evenly across replicas

### Apply to **all containers and initContainers**

```yaml
resources:
  requests:
    cpu: 250m
    memory: 500Mi
  limits:
    cpu: 300m
    memory: 600Mi
```

---

## 5. StorageClass – Default Handling

### Create SC (not default)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
```

### Patch to default

```bash
kubectl patch sc local-storage \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Remove other defaults

```bash
kubectl patch sc local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

---

## 6. PriorityClass

### Create

```bash
kubectl create priorityclass high-priority \
  --value=999 \
  --description="high priority"
```

### Patch deployment

```bash
kubectl -n priority patch deploy busybox-logger \
  -p '{"spec":{"template":{"spec":{"priorityClassName":"high-priority"}}}}'
```

---

## 7. Ingress (Classic)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo
  namespace: echo-sound
spec:
  rules:
  - host: example.org
    http:
      paths:
      - path: /echo
        pathType: Prefix
        backend:
          service:
            name: echo-service
            port:
              number: 8080
```

---

## 8. CRDs – Listing & Explain

```bash
kubectl get crd | grep cert-manager > /root/resources.yaml
kubectl explain certificate.spec.subject > /root/subject.yaml
```

---

## 9. NetworkPolicy – Least Permissive

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: backend
spec:
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
    ports:
    - port: 80
      protocol: TCP
```

---

## 10. HPA (autoscaling/v2)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: apache-server
  namespace: autoscale
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: apache-deployment
  minReplicas: 1
  maxReplicas: 4
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 30
```

---

## 11. CNI (NetworkPolicy required)

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml
```

---

## 12. PV Reuse (Retain)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mariadb
  namespace: mariadb
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 250Mi
  storageClassName: ""
```

---

## 13. cri-dockerd

```bash
sudo dpkg -i cri-dockerd_*.deb
sudo systemctl enable --now dockerd
```

`/etc/sysctl.d/zz-cka.conf`
```
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.netfilter.nf_conntrack_max=131072
```

Apply:
```bash
sudo sysctl --system
```

---

## 14. kube-apiserver etcd port fix

- Correct port: **2379**
- Wrong port: 2380 (peer)

Edit:
```bash
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

---

## 15. Taints & Tolerations

```bash
kubectl taint node node01 PERMISSION=granted:NoSchedule
```

```yaml
tolerations:
- key: PERMISSION
  operator: Equal
  value: granted
  effect: NoSchedule
```

---

## 16. /etc/hosts (safe method)

```bash
echo "x.x.x.x ckaquestion.k8s.local" | sudo tee -a /etc/hosts
```

---

# Final Rule for Exam

If a solution:
- contains typos
- relies on chart internals
- cannot be dry‑run validated

**Do not trust it.** Use this document as your ground truth.

