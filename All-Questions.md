# CKA Exam – Corrected Master Notes (Q&A Format, Exam‑Safe)

This document preserves the **original question context** and provides **fully corrected, exam‑safe solutions**.

Use this exactly like a revision sheet: **read question → expand solution → rehearse commands**.

---

## Q1 – Argo CD via Helm (CRDs already installed)

**Question**

Install Argo CD using Helm. CRDs are already installed in the cluster and must **NOT** be installed again.

Tasks:
1. Add the Argo CD Helm repository
2. Generate Helm manifests for version `7.7.3`
3. Save output to a file

<details>
<summary><strong>Correct Solution (Exam‑Safe)</strong></summary>

```bash
helm repo add argo https://argoproj.github.io/argo-helm
kubectl create namespace argocd

helm template argocd argo/argo-cd \
  --version 7.7.3 \
  --namespace argocd \
  --skip-crds \
  > /root/argo-helm.yaml
```

**Why this is correct**
- `--skip-crds` is a Helm‑level guarantee (not chart‑specific)
- No dependency on `values.yaml`
- Deterministic grading behavior

Verify:
```bash
grep -i CustomResourceDefinition /root/argo-helm.yaml
# expect no output
```
</details>

---

## Q2 – Sidecar Container with Shared Volume

**Question**

Update an existing Deployment to add a sidecar container that tails logs written by the main container. Both containers must share a volume.

<details>
<summary><strong>Correct Solution</strong></summary>

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

**Key rules**
- Sidecar is a **normal container**, not initContainer
- `volumeMounts.name` must match `volumes.name`
</details>

---

## Q3 – Gateway API Migration (Replace Ingress)

**Question**

Migrate an existing Ingress to the Gateway API while preserving:
- TLS termination
- Hostname
- Routing rules

<details>
<summary><strong>Correct Solution</strong></summary>

### Gateway
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

### HTTPRoute
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

**Common traps avoided**
- Missing namespace
- Invalid port value
- Missing `tls.mode: Terminate`
</details>

---

## Q4 – Resource Requests & Limits

**Question**

Adjust CPU and memory requests/limits so that multiple replicas run stably without exhausting the node.

<details>
<summary><strong>Correct Solution</strong></summary>

Apply to **all containers and initContainers**:

```yaml
resources:
  requests:
    cpu: 250m
    memory: 500Mi
  limits:
    cpu: 300m
    memory: 600Mi
```

**Method**
1. Check allocatable resources
2. Subtract system usage
3. Reserve ~10% headroom
4. Divide evenly
</details>

---

## Q5 – StorageClass Default Handling

**Question**

Create a StorageClass, then make it the default while ensuring it is the **only** default StorageClass.

<details>
<summary><strong>Correct Solution</strong></summary>

Create:
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

Patch to default:
```bash
kubectl patch sc local-storage \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Remove other defaults:
```bash
kubectl patch sc local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```
</details>

---

## Q6 – PriorityClass

**Question**

Create a PriorityClass and apply it to an existing workload.

<details>
<summary><strong>Correct Solution</strong></summary>

```bash
kubectl create priorityclass high-priority \
  --value=999 \
  --description="high priority"
```

```bash
kubectl -n priority patch deploy busybox-logger \
  -p '{"spec":{"template":{"spec":{"priorityClassName":"high-priority"}}}}'
```
</details>

---

## Q7 – Ingress (Classic)

**Question**

Expose a Service via Ingress using a host and path.

<details>
<summary><strong>Correct Solution</strong></summary>

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
</details>

---

## Q8 – CRDs Inspection

**Question**

List CRDs and extract schema documentation.

<details>
<summary><strong>Correct Solution</strong></summary>

```bash
kubectl get crd | grep cert-manager > /root/resources.yaml
kubectl explain certificate.spec.subject > /root/subject.yaml
```
</details>

---

## Q9 – NetworkPolicy (Least Permissive)

**Question**

Allow traffic from frontend namespace to backend namespace only.

<details>
<summary><strong>Correct Solution</strong></summary>

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
</details>

---

## Q10 – Horizontal Pod Autoscaler

**Question**

Create an HPA that scales based on CPU utilization.

<details>
<summary><strong>Correct Solution</strong></summary>

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
</details>

---

## Q11 – CNI with NetworkPolicy Support

**Question**

Install a CNI that supports NetworkPolicy.

<details>
<summary><strong>Correct Solution</strong></summary>

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml
```
</details>

---

## Q12 – PersistentVolume Reuse (Retain)

**Question**

Rebind a retained PV to a new PVC.

<details>
<summary><strong>Correct Solution</strong></summary>

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
</details>

---

## Q13 – cri‑dockerd Setup

**Question**

Install and enable cri‑dockerd with required sysctl settings.

<details>
<summary><strong>Correct Solution</strong></summary>

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
</details>

---

## Q14 – kube‑apiserver etcd Port Fix

**Question**

Fix kube‑apiserver failing due to wrong etcd port.

<details>
<summary><strong>Correct Solution</strong></summary>

- Correct port: **2379**
- Wrong port: 2380

```bash
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```
</details>

---

## Q15 – Taints & Tolerations

**Question**

Prevent scheduling on a node except for tolerated pods.

<details>
<summary><strong>Correct Solution</strong></summary>

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
</details>

---

## Q16 – /etc/hosts Modification

**Question**

Add service IP to `/etc/hosts`.

<details>
<summary><strong>Correct Solution</strong></summary>

```bash
echo "x.x.x.x ckaquestion.k8s.local" | sudo tee -a /etc/hosts
```
</details>

---

### Final Exam Rule

If a solution:
- cannot be dry‑run validated
- relies on chart internals
- contains silent YAML or shell traps

**do not use it.**

This document is now safe to memorize and execute under exam pressure.

