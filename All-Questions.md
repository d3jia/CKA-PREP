# CKA-PREP – Restored Questions + Corrected Solutions (Q1–Q17)

All **question blocks are preserved verbatim** from your original `All-Questions.md` so your practice/validation scripts remain compatible. Only the **solutions** are corrected and made exam-safe.

---

## Q1 – ArgoCD (Helm template, skip CRDs)

**Question (original, keep intact)**

```bash
# Question ArgoCD

#Task
# Install Argo CD in a kubernetes cluster using helm while ensuring the CRDs are not installed
# (as they are pre installed)
# 1. Add the official Argo CD Helm repository with the name argocd (https://argoproj.github.io/argo-helm)
# 2. Generate a Helm template from the Argo CD chart version 7.7.3 for the argocd namespace
# 3. Ensure that CRDs are not installed by configuring the chart accordingly
# 4. Save the generated YAML manifest to /root/argo-helm.yaml

# Video link
https://youtu.be/8GzJ-x9ffE0?si=7SCVm2JU7--Yrmte
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

```bash
# 1) Add repo exactly as requested
helm repo add argocd https://argoproj.github.io/argo-helm

# 2) Namespace
kubectl create namespace argocd

# 3) Render manifests WITHOUT CRDs and save to required path
helm template argocd argocd/argo-cd \
  --version 7.7.3 \
  --namespace argocd \
  --skip-crds \
  > /root/argo-helm.yaml
```

Validation:
```bash
test -s /root/argo-helm.yaml
grep -i "CustomResourceDefinition" /root/argo-helm.yaml
# expect: no output
```

</details>

---

## Q2 – SideCar

**Question (original, keep intact)**

```bash
# Question SideCar

# Task
# Update the existing wordpress deployment adding a sidecar container named sidecar using the busybox:stable
# image to the existing pod
# The new sidecar container has to run the following command
"/bin/sh -c tail -f /var/log/wordpress.log"
# Use a volume mounted at /var/log to make the log file wordpress.log available to the co-located container

#Video link
https://youtu.be/2diUcaV5TXw?si=ftqiW_E-4kswuis1
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

Step 0 — Find the namespace (don’t assume):
```bash
kubectl get deploy -A | grep -i wordpress
# use the namespace shown below as $NS
```

Step 1 — Edit the deployment:
```bash
NS=<namespace-from-above>
kubectl -n $NS edit deploy wordpress
```

Step 2 — Add a shared `emptyDir` volume and mount it into BOTH containers.

Under `spec.template.spec`:
```yaml
volumes:
- name: log
  emptyDir: {}
```

In the existing `wordpress` container (same level as `image`, `ports`, etc.):
```yaml
volumeMounts:
- name: log
  mountPath: /var/log
```

Step 3 — Add the sidecar container under `spec.template.spec.containers`:
```yaml
- name: sidecar
  image: busybox:stable
  command: ["/bin/sh", "-c", "tail -f /var/log/wordpress.log"]
  volumeMounts:
  - name: log
    mountPath: /var/log
```

Step 4 — Verify:
```bash
kubectl -n $NS rollout status deploy wordpress
POD=$(kubectl -n $NS get po -l app=wordpress -o jsonpath='{.items[0].metadata.name}')
kubectl -n $NS logs $POD -c sidecar --tail=20
```

</details>

---

## Q3 – Gateway API (Migrate from Ingress)

**Question (original, keep intact)**

```bash
# Question
# You have an existing web application deployed in a Kubernetes cluster using an Ingress resource named web.
# You must migrate the existing Ingress configuration to the new Kubernetes Gateway API, maintaining the
# existing HTTPS access configuration

# Tasks
# 1. Create a Gateway Resource named web-gateway with hostname gateway.web.k8s.local that maintains the
# exisiting TLS and listener configuration from the existing Ingress resource named web
# 2. Create a HTTPRoute resource named web-route with hostname gateway.web.k8s.local that maintains the
# existing routing rules from the current Ingress resource named web.
# Note: A GatewayClass named nginx-class is already installed in the cluster

#Video link
...
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

Step 0 — Inspect the current Ingress so you mirror host/path/service/secret:
```bash
kubectl -A get ingress | grep -w web
# set NS accordingly
NS=<namespace-of-ingress-web>

kubectl -n $NS describe ingress web
kubectl -n $NS get secret
```

Step 1 — Create `Gateway` that terminates TLS and uses the same hostname and TLS secret.
Replace `<TLS_SECRET_NAME>` with the secret referenced by the Ingress.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: <NS>
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
        name: <TLS_SECRET_NAME>
```

Step 2 — Create `HTTPRoute` to match the same routing rules as the old Ingress.
Replace `<SERVICE_NAME>` and `<SERVICE_PORT>` from the Ingress backend.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
  namespace: <NS>
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
    - name: <SERVICE_NAME>
      port: <SERVICE_PORT>
```

Apply:
```bash
kubectl -n $NS apply -f gateway.yaml
kubectl -n $NS apply -f httproute.yaml
```

Verify:
```bash
kubectl -n $NS get gateway,httproute
kubectl -n $NS describe gateway web-gateway
kubectl -n $NS describe httproute web-route
```

</details>

---

## Q4 – CPU and Memory (requests/limits)

**Question (original, keep intact)**

```bash
# Question
# You are managing a WordPress application running in a Kubernetes cluster
# Your task is to adjust the Pod resource requests and limits to ensure stable operation

# Tasks
# 1. Scale down the wordpress deployment to 0 replicas
# 2. Edit the deployment and divide the node resource evenly across all 3 pods
# 3. Assign fair and equal CPU and memory to each Pod
# 4. Add sufficient overhead to avoid node instability
# Ensure both the init containers and the main containers use exactly the
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

Step 1 — Scale down:
```bash
kubectl get deploy -A | grep -i wordpress
NS=<namespace>

kubectl -n $NS scale deploy wordpress --replicas=0
kubectl -n $NS get deploy wordpress
```

Step 2 — Compute fair CPU/mem per pod (3 pods) with overhead:
- `kubectl describe node <node>` → **Allocatable**
- subtract what is already allocated
- reserve ~10% headroom
- divide remaining by 3

Step 3 — Set resources for **every container AND every initContainer**:
```bash
kubectl -n $NS edit deploy wordpress
```

Example pattern (replace numbers with your computed values):
```yaml
resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: 300m
    memory: 600Mi
```

Step 4 — Scale back up (3 replicas):
```bash
kubectl -n $NS scale deploy wordpress --replicas=3
kubectl -n $NS rollout status deploy wordpress
```

Verification:
```bash
kubectl -n $NS describe deploy wordpress | egrep -n "Init Containers:|Containers:|Requests:|Limits:" -A3
```

</details>

---

## Q5 – StorageClass (default handling)

**Question (original, keep intact)**

```bash
# Question

# You are tasked with creating a StorageClass using rancher.io/local-path provisioner

# Tasks
# 1. Create a StorageClass called local-storage with the provisioner rancher.io/local-path.
# Make sure that the StorageClass is not the default.
# 2. Edit the existing StorageClass named local-path and make local-storage the default StorageClass.
# 3. Set the VolumeBindingMode of the local-storage StorageClass to WaitForFirstCustomer

# Video Link
https://youtu.be/wxqyjB0RkvY?si=VjZ9yTTp0aPTtHqK
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

Important: The correct Kubernetes value is `WaitForFirstConsumer` (question has a typo).

Step 1 — Create StorageClass (NOT default):
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

Apply:
```bash
kubectl apply -f sc.yaml
kubectl get sc
```

Step 2 — Make `local-storage` default:
```bash
kubectl patch sc local-storage \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Step 3 — Remove default flag from the old `local-path` class (if present):
```bash
kubectl patch sc local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

Verify:
```bash
kubectl get sc -o jsonpath='{range .items[*]}{.metadata.name}{"	"}{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}{"
"}{end}'
```

</details>

---

## Q6 – PriorityClass

**Question (original, keep intact)**

```bash
# Question
# You are tasked with creating a PriorityClass that is slightly lower than the highest
# user-defined PriorityClass value.

# Tasks
# 1. Identify the highest user-defined PriorityClass value.
# 2. Create a new PriorityClass called high-priority that is 1 less than the highest user-defined value.
# 3. Edit the existing deployment busybox-logger in the priority namespace and apply the PriorityClass.

# Video Link
https://youtu.be/nwCLp_KxI4k?si=q5e7dU6oOXQxGHR6
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

Step 1 — Find highest user-defined PriorityClass value:
```bash
kubectl get priorityclass
kubectl get priorityclass -o custom-columns=NAME:.metadata.name,VALUE:.value --sort-by=.value
```
Pick the highest **non-system** one (ignore `system-*` if present).

Step 2 — Create the new PriorityClass as (highest - 1):
```bash
kubectl create priorityclass high-priority --value=<HIGHEST_MINUS_1> --description="high priority"
```

Step 3 — Patch deployment:
```bash
kubectl -n priority patch deploy busybox-logger \
  -p '{"spec":{"template":{"spec":{"priorityClassName":"high-priority"}}}}'
```

Verify:
```bash
kubectl -n priority get deploy busybox-logger -o jsonpath='{.spec.template.spec.priorityClassName}{"
"}'
```

</details>

---

## Q7 – Ingress

**Question (original, keep intact)**

```bash
# Question Ingress

# Task
# 1. Expose the existing deployment with a service called echo-service
# using Service Port 8080 type=NodePort
# 2. Create a new ingress resource named echo in the echo-sound namespace for http://example.org/echo
# 3. The availability of the Service echo-service can be checked using the following command
curl NODEIP:NODEPORT/echo

# In the exam it may give you a command like curl -o /dev/null -s -w "%{http_code}
" http://example.org/echo
# This requires an ingress controller, to get this to work ensure your /etc/hosts file has an entry for your NodeIP
# pointing to example.org

# Video Link
https://youtu.be/mtORnV8AlI4?si=6fZq-yd8Sezg0a7v
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

Step 1 — Expose deployment as NodePort service on service port 8080:
```bash
kubectl -n echo-sound get deploy
kubectl -n echo-sound expose deploy echo --name echo-service --type NodePort --port 8080 --target-port 8080
kubectl -n echo-sound get svc echo-service
```

Step 2 — Create ingress `echo`:
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

Apply:
```bash
kubectl apply -f ingress.yaml
kubectl -n echo-sound get ingress echo
```

Step 3 — If asked to curl `http://example.org/echo`, map Node IP to example.org:
```bash
NODEIP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "$NODEIP example.org" | sudo tee -a /etc/hosts
```

Verify NodePort path:
```bash
NODEPORT=$(kubectl -n echo-sound get svc echo-service -o jsonpath='{.spec.ports[0].nodePort}')
curl -sS $NODEIP:$NODEPORT/echo
```

</details>

---

## Q8 – CRDs

**Question (original, keep intact)**

```bash
# Question CRD
# Create a new file /root/resources.yaml and add all the resources from the cluster
# by cert-manager and also create a new file /root/subject.yaml and add the output from
# kubectl explain certificate.spec.subject to it.

# Video link
https://youtu.be/71f6QKx3f9I?si=U-1h98-d2kYh5S8y
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

```bash
kubectl get crd | grep cert-manager > /root/resources.yaml
kubectl explain certificate.spec.subject > /root/subject.yaml
```

Verify:
```bash
test -s /root/resources.yaml
test -s /root/subject.yaml
```

</details>

---

## Q9 – NetworkPolicy (choose least permissive)

**Question (original, keep intact)**

```bash
# Question:
# There are two deployments, Frontend and Backend
# Frontend is in the frontend namespace, Backend is in the backend namespace

# Task
# Look at the Network Policy YAML files in /root/network-policies
# Decide which of the policies provides the functionality to allow interaction between the
# frontend and the backend deployments in the least permissive way and deploy that yaml

# Video Link
https://youtu.be/EIjpWA0AGG4?si=ih4IWm4wsDeIPzbM
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

Step 1 — Inspect candidate policies:
```bash
ls -1 /root/network-policies
for f in /root/network-policies/*.yaml; do echo "----- $f"; sed -n '1,200p' $f; done
```

Step 2 — Identify the least-permissive policy that still allows Frontend → Backend.
Heuristics:
- Must target backend (`metadata.namespace: backend` and `spec.podSelector` matches backend pods)
- Must allow ingress **only** from frontend namespace and (preferably) only frontend pods
- Must restrict ports to the minimum needed (e.g., only TCP 80/443)

Step 3 — Apply that file:
```bash
kubectl apply -f /root/network-policies/<chosen-file>.yaml
```

Step 4 — Verify reachability is allowed as required, and other ingress is blocked:
```bash
kubectl -n backend get netpol
kubectl -n backend describe netpol
```

</details>

---

## Q10 – HPA

**Question (original, keep intact)**

```bash
# Question HPA

# Task
# There is a deployment called apache-deployment in the autoscale namespace.
# Create a HorizontalPodAutoscaler called apache-server for this deployment.
# Set min replicas to 1 and max replicas to 4.
# Target CPU utilization should be 50%.
# Configure the HPA to stabilize downscale actions with a stabilization window of 30 seconds.

# Video Link
https://youtu.be/E9ooR4U0QuI?si=JxMhs0O6p6J7F0oB
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

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

Apply + verify:
```bash
kubectl apply -f hpa.yaml
kubectl -n autoscale get hpa apache-server
kubectl -n autoscale describe hpa apache-server
```

</details>

---

## Q11 – CNI (NetworkPolicy support)

**Question (original, keep intact)**

```bash
# Question
# In this cluster there is an issue where NetworkPolicy resources are not working.
# You have identified that the cluster is using a CNI plugin that does not support NetworkPolicy.
# You must install a CNI plugin that supports NetworkPolicy.

# Task
# Select and install a CNI plugin that supports NetworkPolicy from the following options:
# 1. Flannel
# 2. Calico
# 3. Weave

# Video Link
https://youtu.be/P2E8k9yP8dQ?si=E8u1OaS8yY6_y7m0
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

Choose **Calico**.

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml
```

Verify:
```bash
kubectl get pods -A | egrep -i 'calico|tigera'
```

</details>

---

## Q12 – Persistent Volume (reuse PV)

**Question (original, keep intact)**

```bash
# Question
# There is an existing PersistentVolume in the cluster with the reclaim policy Retain.
# The PV was previously bound to a PVC that has been deleted.
# You must create a new PVC and bind it to the existing PV.

# Tasks
# 1. Inspect the PV and determine its capacity, access modes and storageClassName.
# 2. Modify the PV if needed so it can be rebound.
# 3. Create a new PVC in the mariadb namespace called mariadb that binds to this PV.

# Video Link
https://youtu.be/fF5zT9mP8x4?si=p1pXvY0dVvD0kR0Z
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

Step 1 — Inspect PV:
```bash
kubectl get pv
PV=<pv-name>
kubectl describe pv $PV
```

Step 2 — If PV is stuck in `Released` due to `spec.claimRef`, remove claimRef:
```bash
kubectl edit pv $PV
# delete the entire spec.claimRef block
```

Step 3 — Create PVC that matches accessModes, storage, and storageClassName.
If PV has `storageClassName: ""` (none), your PVC must set `storageClassName: ""` too.

Template (edit values to match PV):
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
      storage: <PV_CAPACITY>
  storageClassName: ""
  volumeName: <PV_NAME>
```

Apply + verify:
```bash
kubectl apply -f pvc.yaml
kubectl -n mariadb get pvc mariadb
kubectl get pv $PV
```

</details>

---

## Q13 – Cri-Dockerd

**Question (original, keep intact)**

```bash
# Question
# You are required to install and configure cri-dockerd on the controlplane node.
# The package is available at the following location:
# /root/cri-dockerd.deb

# Tasks
# 1. Install the package
# 2. Enable and start the cri-docker service
# 3. Configure system parameters required for Kubernetes networking

# Video Link
https://youtu.be/6xQW4xv6I_0?si=fz1B_7iHc3i0g5mP
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

```bash
sudo dpkg -i /root/cri-dockerd.deb
sudo systemctl enable --now cri-docker
sudo systemctl status cri-docker
```

Sysctl (persist + apply):
```bash
sudo tee /etc/sysctl.d/zzcka.conf >/dev/null <<'EOF'
net.bridge.bridge-nf-call-iptables=1
net.ipv6.conf.all.forwarding=1
net.ipv4.ip_forward=1
net.netfilter.nf_conntrack_max=131072
EOF

sudo sysctl --system
```

</details>

---

## Q14 – Kube-apiserver (etcd port fix)

**Question (original, keep intact)**

```bash
# Question
# The kube-apiserver is down due to incorrect etcd port configuration.
# You need to fix the configuration and bring the kube-apiserver back up.

# Task
# Fix the etcd port in the kube-apiserver manifest.

# Video Link
https://youtu.be/S1w1s0w8CkQ?si=U6w1wK1L4JjO6G2p
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

- etcd client port: **2379**
- etcd peer port: **2380**

```bash
sudo grep -n "etcd-servers" /etc/kubernetes/manifests/kube-apiserver.yaml
sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Fix any :2380 to :2379 for --etcd-servers
```

Verify:
```bash
kubectl get nodes
kubectl get pods -n kube-system | grep apiserver
```

</details>

---

## Q15 – Taints and Tolerations

**Question (original, keep intact)**

```bash
# Question
# You need to prevent scheduling on node01 unless a pod has a specific toleration.

# Tasks
# 1. Add a taint to node01 with key PERMISSION, value granted and effect NoSchedule.
# 2. Create a pod that tolerates this taint and can run on node01.

# Video Link
https://youtu.be/7b5vGzO5cZw?si=7Jr5b0k8x0wXyBqP
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

```bash
kubectl taint node node01 PERMISSION=granted:NoSchedule
```

Pod with toleration (and force to node01 if needed):
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tolerant-pod
spec:
  nodeName: node01
  containers:
  - name: nginx
    image: nginx
  tolerations:
  - key: "PERMISSION"
    operator: "Equal"
    value: "granted"
    effect: "NoSchedule"
```

Apply + verify:
```bash
kubectl apply -f pod.yaml
kubectl get pod tolerant-pod -o wide
```

</details>

---

## Q16 – NodePort

**Question (original, keep intact)**

```bash
# Question
# There is a deployment named nodeport-deployment in the relative namespace

# Tasks:
# 1. Configure the deployment so it can be exposed on port 80, name=http, protocol TCP
# 2. Create a new Service named nodeport-service exposing the container port 80, protocol TCP, Node Port 30080
# 3. Configure the new Service to also expose the individual pods using NodePort

# Video Link
https://youtu.be/t1FxX3PmYDQ?si=ryASL-G9X2FCVApQ
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

Step 1 — Ensure deployment defines the container port:
```bash
kubectl -n relative edit deploy nodeport-deployment
```

In the container spec:
```yaml
ports:
- name: http
  containerPort: 80
  protocol: TCP
```

Step 2 — Create Service with explicit `nodePort: 30080`:
```bash
kubectl -n relative expose deploy nodeport-deployment \
  --name nodeport-service \
  --type NodePort \
  --port 80 \
  --target-port 80 \
  --dry-run=client -o yaml > svc.yaml

# Edit svc.yaml and set:
# spec.ports[0].nodePort: 30080
vim svc.yaml
kubectl -n relative apply -f svc.yaml
```

Verify:
```bash
kubectl -n relative get svc nodeport-service -o wide
kubectl -n relative get endpoints nodeport-service
```

</details>

---

## Q17 – TLS (force TLSv1.3 only)

**Question (original, keep intact)**

```bash
# Question
# In this cluster there is a static nginx deployment called nginx-static in the nginx-static namespace.
# A ConfigMap called nginx-config is used to configure nginx to support
# TLSv1.2 and TLSv1.3 as well as a Secret for TLS.

# There is a service called nginx-service in the nginx-static namespace that is currently exposing the deployment.

# Task:
# 1. Configure the ConfigMap to only support TLSv1.3
# 2. Add the IP address of the service in /etc/hosts and name it ckaquestion.k8s.local
# 3. Verify everything is working using the following commands
    curl -vk --tls-max 1.2 https://ckaquestion.k8s.local # should fail
    curl -vk --tlsv1.3 https://ckaquestion.k8s.local # should work

# Video Link
https://youtu.be/-6QTAhprvTo?si=Rx81y2lHvK2Y_jBF
```

<details>
<summary><strong>Correct Solution (Exam-Safe)</strong></summary>

Step 1 — Get service IP and add to `/etc/hosts`:
```bash
kubectl -n nginx-static get svc nginx-service -o wide
SVCIP=$(kubectl -n nginx-static get svc nginx-service -o jsonpath='{.spec.clusterIP}')
echo "$SVCIP ckaquestion.k8s.local" | sudo tee -a /etc/hosts
```

Step 2 — Edit ConfigMap to allow only TLSv1.3:
```bash
kubectl -n nginx-static edit configmap nginx-config
```

In the nginx configuration, ensure:
```nginx
ssl_protocols TLSv1.3;
```
(Do not include TLSv1.2.)

Step 3 — Restart nginx pods so new config loads (choose the method that fits your resources):
- If it’s a Deployment:
```bash
kubectl -n nginx-static rollout restart deploy nginx-static
```
- If it’s a DaemonSet:
```bash
kubectl -n nginx-static rollout restart ds nginx-static
```

Step 4 — Verify:
```bash
curl -vk --tls-max 1.2 https://ckaquestion.k8s.local
# should fail

curl -vk --tlsv1.3 https://ckaquestion.k8s.local
# should work
```

</details>

---

