# CKA-PREP Consolidated Questions and Solution Notes

This document consolidates all questions and solution notes. Solutions are hidden in expandable sections.

## Question 1

**Question file:** `Question-1/Questions.txt`

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
<summary>Solution Notes</summary>

```bash
# Step one add the repo
helm repo add argocd https://argoproj.github.io/argo-helm
# Check the repo is there
helm repo list

# Step two get the template using the parameters given
helm template argocd argo/argo-cd --version 7.7.3 --set crds.install=false --namespace argocd > /root/argo-helm.yaml

#Step three verfiy
cat /root/argo-helm.yaml
# You should see the template there
```
</details>

## Question 2

**Question file:** `Question-2/Questions.txt`

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
<summary>Solution Notes</summary>

```bash
# Step one
# Check the deployment and edit it
k get deployments
k edit deployment wordpress
# We need to add the volume for the sidecar and container

volumes:
      - emptyDir: {}
        name: log
# Mount the volume to the existing container
containers:
      - command:
        - /bin/sh
        - -c
        - while true; do echo 'WordPress is running...' >> /var/log/wordpress.log;
          sleep 5; done
        image: wordpress:php8.2-apache
        imagePullPolicy: IfNotPresent
        name: wordpress
        ports:
        - containerPort: 80
          protocol: TCP
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /var/log
          name: log
# Create the sidecar deployment with the mounted volume
      - command:
        - /bin/sh
        - -c
        - tail -f /var/log/wordpress.log
        image: busybox:stable
        name: sidecar
        volumeMounts:
        - mountPath: /var/log
          name: log
# Write and Quit the edit

# Step 2 Check the deployment has the sidecar include
k describe deployment
# Also check the pod and describe that to see both containers and volume mounts
k describe po wordpress-xxxxx-xxx
```
</details>

## Question 3

**Question file:** `Question-3/Questions.txt`

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
https://youtu.be/W-Rt_U8any4?si=KD_6oVewmhPgu1NZ
```

<details>
<summary>Solution Notes</summary>

```bash
# Step 1
# Verify secret and ingress exist and describe them
k get secret -n web-app
k describe secret -n web-app web-tls
k get ingress -n web-app
k describe ingress -n web-app web

# Step 2
# Create the Gateway (use the docs)
vi gw.yaml
#yaml
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
    tls:                              # This is the section we need to add to maintain the existing config
      mode: Terminate                 # for the ingress resource
      certificateRefs:
       - kind: Secret
         name: web-tls
# Apply it
k apply -f gw.yaml
# Check it is there
k get gateway -n web-app

# Step 3 create the HTTPRoute
vi http.yaml
# Use the docs for reference
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
spec:
  parentRefs:
  - name: web-gateway
  hostnames:
  - "gateway.web.k8s.local"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /                  # We see the path from the ingress description
    backendRefs:
    - name: web-service           # Name and port need to match the service we have
      port: 80.
# apply it
k apply -f http.yaml

# Check
k describe gateway,httproute -n web-app

# Check all fields match as expected. In the exam you may be given a curl to run to check this
```
</details>

## Question 4

**Question file:** `Question-4/Questions.txt`

```bash
# Question
# You are managing a WordPress application running in a Kubernetes cluster
# Your task is to adjust the Pod resource requests and limits to ensure stable operation

# Tasks
# 1. Scale down the wordpress deployment to 0 replicas
# 2. Edit the deployment and divide the node resource evenly across all 3 pods
# 3. Assign fair and equal CPU and memory to each Pod
# 4. Add sufficient overhead to avoid node instability
# Ensure both the init containers and the main containers use exactly the same resource requests and limits
# After making the changes scale the deployment back to 3 replicas

#Video link
https://youtu.be/Hkl9XgMKxic?si=v9yI1Rz10DELN4Mf
```

<details>
<summary>Solution Notes</summary>

```bash
# Step 1
# Check the deployment and scale it down to 0
k get deployments
# Scale it down
k scale deployment wordpress --replicas 0
# Check it has scaled
k get deployments
# Should see 0 replicas

# Step 2
# Find the allocatable CPU and memory on the node and decide how to split it between the 3 pods
k describe node node01
# Look at the memory and CPU that is allocatable (I will be using example numbers here, yours will be different)
cpu: 1
memory: 1846652Ki
# Firstly we want memory in Mi so divide the Ki by 1024
expr 1846652 / 1024
1803
# Next we want to look at memory already in use
k describe node node01
# Look in the Memory Requests Column
  kube-system                 canal-tqknq                   25m (2%)      0 (0%)      0 (0%)           0 (0%)         2d23h
  kube-system                 coredns-6ff97d97f9-h59nk      50m (5%)      0 (0%)      50Mi (2%)        170Mi (9%)     2d23h
  kube-system                 coredns-6ff97d97f9-rpmqd      50m (5%)      0 (0%)      50Mi (2%)        170Mi (9%)     2d23h
# We have 100Mi already requested so we need to take this out of our calculation
1803 - 100
1703
# We now need to leave ~ 10% Head room
1703 - 170
1533
# We now need to share this between 3 pods
1533 / 3
511Mi
# Looking at this a 500Mi request looks reasonable with a 600Mi limit

# We now need to do the same for CPU
1 CPU = 1000m
# Check CPU usage from the table we see it is 125m
1000 - 125
875
# Get ~10% headroom
875 - 87
788
# Share this between 3 pods
788 / 3
~ 262
# Looking at this a 250m request with a 300m limit looks reasonable

# Step 3
# Edit the deployment with the new requests and limits
k edit deployment wordpress
# ensure you add the limits to containers AND init containers
        resources:
          limits:
            cpu: 300m
            memory: 600Mi
          requests:
            cpu: 250m
            memory: 500Mi

# Step 4 Scale Up
# Scale the deployment back to 3 replicas
k scale deployment wordpress --replicas 3
# Describe the deployment and ensure you see the requests/limits there
k describe deployment wordpress
# Once the pods are up and running describe one of the pods and make sure you see the requests/limits there
k describe pod wordpress-xxx-xxx-xxx
```
</details>

## Question 5

**Question file:** `Question-5/Questions.txt`

```bash
# Question Storage Class

# Tasks
# 1. Create a new StorageClass named local-storage with the provisioner rancher.io/local-path. Set
# the VolumeBindingMode to WaitForFirstCustomer. Do not make the SC default
# 2. Patch the StorageClass to make it the default StorageClass
# 3. Ensure local-storage is the only default class
# Do not modify any existing Deployments or PersistentVolumeClaims

# Video link
https://youtu.be/WmbIrlbqjPw?si=bYSf9dDtb4hIfKG4
```

<details>
<summary>Solution Notes</summary>

```bash
# Step 1 Create the storage class
vi sc.yaml
# Use the docs to create the yaml as per your spec
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
# apply
k apply -f sc.yaml
# Check
k get sc
# You should see your SC there and it isn't the default class

# Step 2 patch your SC
# Check where we need to patch by using
k get sc local-storage -oyaml
# Find the default setting
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
  ....
    storageclass.kubernetes.io/is-default-class: "false" # This is what we want to change to true
# We can see this is under metadata.annotations.storageclass.kubernetes.io/is-default-class we can
# now build our patch command
k patch storageclasses.storage.k8s.io local-storage -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
# Check
k get sc
# We should see our sc is now labelled as default

# Step 3 remove other default
# We can also see the local-path SC is labelled as default, we don't want two defaults so we need to remove this
# Use the command we built above to remove this editing it for the local-path SC and setting default to false
k patch storageclasses.storage.k8s.io local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
# Check
k get sc
# We should now only see local-storage as the default
```
</details>

## Question 6

**Question file:** `Question-6/Questions.txt`

```bash
# Question
# You're working in a kubernetes cluster with an existing deployment named busybox-logger running
# in the priority namespace.
# The cluster already has at least one user defined Priority Class

# Tasks:
# 1. Create a new Priority Class named high-priority for user workloads. The value of this class should
# be exactly one less than the highest existing user-defined priority class
# 2. Patch the existing deployment busybox-logger in the priority namespace to use the newly created
# high-priority class

# Video Link
https://youtu.be/wiL_M9qbPX4?si=rOIyX45i5kON8Xr7
```

<details>
<summary>Solution Notes</summary>

```bash
# Step1 Find the user defined priority classes
k get pc
# User defined PCs are appended with "user", we can see the highest is 1000 so we need to create
# a PC with value 999
k create priorityclass high-priority --value=999 --description="high priority"
# Check to see PC was created
k get pc

# Step 2 Patch the deployment, we need to use the patch command for this for the exam, first we need to figure
# out where we want the priority class name to go.
k get deployments.apps -n priority busybox-logger -oyaml
# We need to add priorityClassName in the following section
...
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: busybox-logger
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: busybox-logger
    spec:
      # We want to add priorityClassName here
      containers:
      - command:
        - sh
        - -c
        - while true; do echo 'logging...'; sleep 5; done
        image: busybox
        imagePullPolicy: Always
        name: busybox
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      priorityClassName: high-priority
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
# From this we can see this is under spec:template:spec so our command will look like this
k patch deployment -n priority busybox-logger -p '{"spec":{"template":{"spec":{"priorityClassName":"high-priority"}}}}'

# Step 3 Check patch has applied successfully
k describe deployment -n priority busybox-logger
# We should see the following
  Priority Class Name:  high-priority
```
</details>

## Question 7

**Question file:** `Question-7/Questions.txt`

```bash
# Question Ingress

# Task
# 1. Expose the existing deployment with a service called echo-service
# using Service Port 8080 type=NodePort
# 2. Create a new ingress resource named echo in the echo-sound namespace for http://example.org/echo
# 3. The availability of the Service echo-service can be checked using the following command
curl NODEIP:NODEPORT/echo

# In the exam it may give you a command like curl -o /dev/null -s -w "%{http_code}\n" http://example.org/echo
# This requires an ingress controller, to get this to work ensure your /etc/hosts file has an entry for your NodeIP
# pointing to example.org

# Video Link
https://youtu.be/mtORnV8AlI4?si=6fZq-yd8Sezg0a7v
```

<details>
<summary>Solution Notes</summary>

```bash
# Step 1 Expose the deployment with the given features
k get deployments -n echo-sound

k expose deployment -n echo-sound echo --name echo-service --type NodePort --port 8080 --target-port 8080

# Check the service has been created
k get svc -n echo-sound

# Step 2 Create the ingress
# Use the docs for a template
vi ingress.yaml
# yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo
  namespace: echo-sound
spec:
  rules:
  - host: "example.org"
    http:
      paths:
      - pathType: Prefix
        path: "/echo"
        backend:
          service:
            name: echo-service
            port:
              number: 8080
# Apply
k apply -f ingress.yaml
# Check
k get ingress -n echo-sound

# Step 3 Check curl command
k get nodes -owide
# Get the IP of the node you have deployed on
k get svc -n echo-sound
# Get the NodePort of the service
curl NODEIP:NODEPORT/echo
# Output
Hostname: echo-84897cb55d-lk675

Pod Information:
        -no pod information available-

Server values:
        server_version=nginx: 1.13.3 - lua: 10008

Request Information:
        client_address=172.30.2.2
        method=GET
        real path=/echo
        query=
        request_version=1.1
        request_scheme=http
        request_uri=http://172.30.2.2:8080/echo

Request Headers:
        accept=*/*
        host=172.30.2.2:31999
        user-agent=curl/8.5.0

Request Body:
        -no body in request-
```
</details>

## Question 8

**Question file:** `Question-8/Questions.txt`

```bash
# Question CRDs

#Task
# 1. Create a list of all cert-manager [CRDs] and save it to /root/resources.yaml
# 2. Using kubectl extract the documentation for the subject specification field of the Certifciate
# Custom Resource and save it to /root/subject.yaml
# You may use any output format that kubectl supports

# Video Link
https://youtu.be/mKvkcjoYzOc?si=53ob4__-b242y4K_
```

<details>
<summary>Solution Notes</summary>

```bash
# Step 1 list the cert-manager CRDs
k get crd | grep cert-manager
# Check the list you get and then output it to the file location
k get crd | grep cert-manager > /root/resources.yaml
# Check the file matches your first list
cat /root/resources.yaml

# Step 2 extract the doc for subject spec, for this we want to use explain
k explain certificate.spec.subject
# We should see the doc output for the subject spec of certificates, we now want output it to the file
k explain certificate.spec.subject > /root/subject.yaml
# Check the file matches the explain command output
cat /root/subject.yaml
```
</details>

## Question 9

**Question file:** `Question-9/Questions.txt`

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
<summary>Solution Notes</summary>

```bash
# Step 1 Inspect file one
cat /root/network-policies/network-policy-1.yaml
# We can see file one allows all ingress traffic which is too permissive

#Step 2 Inspect file 2
cat /root/network-policies/network-policy-2.yaml
# We can see this has the correct namespace selector but it also allows an additional IP which
# Wasn't mentioned in the question so that is too permissive

# Step 3 Inspect file 3
cat /root/network-policies/network-policy-2.yaml
# File three only allows frontend traffic from the frontend namespace and pods labelled front end. We
# need to check the labels on the frontend deployment pods
k get po -n frontend --show-labels
# We can see they have the label app=frontend which means network-policy-3 is the least permissive and allows
# the traffic we want

# Step 4 Apply the file
k apply -f /root/network-policies/network-policy3.yaml
```
</details>

## Question 10

**Question file:** `Question-10/Questions.txt`

```bash
# Question HPA
# Create a new HorizontalPodAutoScaler(HPA) named apache-server in the autoscale namespace

# Task
# 1. The HPA must target the existing deployment called apache-deployment in the autoscale namespace
# 2. Set the HPA to target for 50% CPU usage per Pod
# 3. Configure the HPA to have a minimum of 1 pod and a maximum of 4 pods
# 4. Set the downscale stabilization window to 30 seconds

# Video Link
https://youtu.be/X0ISIy9Bd7U?si=h-GydG4EzPTug6Jt
```

<details>
<summary>Solution Notes</summary>

```bash
# Step 1 Verify the deployment
k get deployments.apps -n autoscale
# You should see the apache-deployment, check the pod(s) exist
k get po -n autoscale
# You should see apache-deployment-xxxxx-xxx

# Step 2 Create the HPA
# Use the Kubernetes docs (https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
# Edit the template to suit your requirements
vi hpa.yaml
# yaml file
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
  behavior:                               # This config can be found at
    scaleDown:                            # https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
      stabilizationWindowSeconds: 30
# Apply the file
k apply -f hpa.yaml

# Step 3 Check the HPA is working
k get hpa -n autoscale
# We should see the reference is Deployment/apache-deployment
# After a small amount of time we should see the CPU targets with values e.g. CPU: 1%/50%
```
</details>

## Question 11

**Question file:** `Question-11/Questions.txt`

```bash
# Question
# Install and configure a CNI of your choice tht meets the specified requirements,
# Choose one of the following:

# Flannel (v0.26.1) using the manifest kube-flannel.yml
# (https://github.com/flannel-io/flannel/releases/download/v0.26.1/kube-flannel.yml)

# or

# Calico (v3.28.2) using the manifest tigera-operator.yaml
# (https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml)

# The CNI you choose must
# 1. Let pods communicate with each other
# 2. Support network policy enforcement
# 3. Install from manifest

#Video Link
https://youtu.be/SV3V5VwR2sk?si=47uiyuvMD1Vpqbm1
```

<details>
<summary>Solution Notes</summary>

```bash
# Step 1
# The key defining factor in the criteria is network policies, Flannel doesn't support network policies,
# Calico does. We can confirm this by running the following
curl -sL https://github.com/flannel-io/flannel/releases/download/v0.26.1/kube-flannel.yml | grep network
# We see nothing relating to networks in the flannel yaml, now lets try Calico
curl -sL https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml
# We see several references to networks and network policies, therefore we know Calico is the choice

# Step 2
# We need to apply the Calico file
k create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml

# Step 3 check everything has been deployed
k get all -n tigera-operator
# We should see pods, deployments and replicasets
```
</details>

## Question 12

**Question file:** `Question-12/Questions.txt`

```bash
# Question:
# A user accidentally deleted the MariaDB Deployment in the mariadb namespace. The deployment
# was configured with persistent storage. Your responsibility is to re-establish the deployment
# while ensuring data is preserved by reusing the available PersistentVolume

#Task
# A PersistentVolume already exists and is retained for reuse. Only one PV exists
# Create a Persistent Volume Claim (PVC) named mariadb in the mariadb namespace with the spec
# Access Mode = ReadWriteOnce
# Storage = 250Mi
# Edit the MariaDb Deployment file located at ~/mariadb-deploy.yaml to use the PVC created in the previous step
# Apply the updated Deployment file to the cluster
# Ensure the MariaDB Deployment is running and Stable

#Video Link
https://youtu.be/0h2Dik_OTvw?si=9hU6-xzCW7AUsmEj
```

<details>
<summary>Solution Notes</summary>

```bash
# Step 1 - check the pv exists
k get pv
k describe pv mariadb-pv

# Step 2 - Clear existing claim
# We can see that the PV has a RELEASED status as it has a claim from the previous PVC, we need to
# edit the PV to remove the claim reference. We can also see the PV has an empty storage class which
# we need to keep in mind for creating our PVC
k edit pv mariadb-pv
# We need to remove this section
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: mariadb
    namespace: mariadb
    resourceVersion: "11228"
    uid: ffa27d96-5199-4785-8ad9-562e8f5d5f53
# Check the PV is now available
k get pv mariadb-pv
# PV should now have status AVAILABLE

# Step 3 Create the PVC (Remember the storage class for the PV is empty)
vi pvc.yaml
# Use the docs
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
  storageClassName: "" # This will allow it to bind to the existing PV with ono SC
# Apply it
k apply pvc.yaml
# Check it has bound
k get pvc -n mariadb mariadb
# Status should show bound
# Double check it has bound to the PV
k get pv mariadb-pv
# This should show as bound with mariadb claim name

# Step 4 Check the deployment
vi mariadb-deploy.yaml
# Ensure the deployment looks as expected and specifically it uses your PVC
volumes:
        - name: mariadb-storage
          persistentVolumeClaim:
            claimName: mariadb
# Apply it
k apply -f mariadb-deploy.yaml

# Step 5 final checks
k get po -n mariadb
# Pod should be running, we want to check it is using the PVC
k describe po -n mariadb mariadb-xxxxx-xxxxx
# We should see this
Volumes:
  mariadb-storage:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  mariadb
```
</details>

## Question 13

**Question file:** `Question-13/Questions.txt`

```bash
# Question: Cri-Dockerd

# Task:
# Set up cri-dockerd
# Install the debian package ~/cri-dockerd.deb using dpkg
# Enable and start the cri-docker service
# Configure these parameters:
# 1. Set net.bridge.bridge-nf-call-iptables to 1
# 2. Set net.ipv6.conf.all.forwarding to 1
# 3. Set net.ipv4.ip_forward to 1
# 4. Set net.netfilter.nf_conntrack_max to 131072

# Video Link
https://youtu.be/u3kUI9lFPWE?si=Pkq74-rfFEp6dmfd
```

<details>
<summary>Solution Notes</summary>

```bash
# Step 1 install and start cri-dockerd
# First we need to use dpkg to install the package
dpkg -i cri-dockerd.deb

# Now we need to enable the service
sudo systemctl enable --now cri-docker.service

# Now we start the service
sudo systemctl start cri-docker.service

# Verify the service is running
sudo systemctl status cri-docker.service
# It should show as active

#Step 2 set the system parameters
# Run the following commands to set the parameters
sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.netfilter.nf_conntrack_max=131072
# This isn't persistent however so would be lost on reboot, to make it persistent
vi /etc/sysctl.d/kube.conf
# add the config
net.bridge.bridge-nf-call-iptables=1
net.ipv6.conf.all.forwarding=1
net.ipv4.ip_forward=1
net.netfilter.nf_conntrack_max=131072

# Check the output and ensure it is correct
sudo sysctl --system

# You may need to add/edit files in the /etc/sysctl.d directory, if you create a file and there are still
# overrides check to see if there re additional conf files there. You can give your config a lexically
# later name e.g. zz-cridocker.conf so it is ran last or you can edit those values in the other files.
```
</details>

## Question 14

**Question file:** `Question-14/Questions.txt`

```bash
# Question:
# After a cluster migration, the controlplane kube-apiserver is not coming up
# Before the migration, the etcd was external and in HA, after migration the kube-api server was pointing to etcd peer port 2380

# Task
# Fix it

# Video Link
https://youtu.be/p1vNc1GacpI?si=lbUxoj5jOeruLy7B
```

<details>
<summary>Solution Notes</summary>

```bash
# On getting on to the node and trying to run kubectl commands we can see that they don't work
# This indicates an issue with the kube api server, we can inspect the logs to see if we can decipher any more information
journalctl | grep kube-apiserver
# We can also go to the following directory for the pod logs
cat /var/log/pods/kube-system_kube-apiserver-controlplane_..../kube-apiserver/x.log
# The pod logs tell us there is an issue connecting to 127.0.0.1:2380
vi /etc/kubernetes/manifests/kube-apiserver.yaml

# Inspect the yaml, we can see there is an issue
--etcd-servers=https://127.0.0.1:2380
# This is the incorrect port of the etcd server it should be
--etcd-servers=https://127.0.0.1:2379
# Update the file and wait for the pods to come up

# There are several issues that could be at play in the exam for this question, the IP could be wrong,
# issues with the location of the certs and keys etc.

# One issue mentioned is that after this the kube-scheduler is down, you may need to inspect the logs for this
k -n kube-system get pods | grep kube-scheduler
k -n kube-system describe pod 'kube-scheduler-pod-name'
k -n kube-system logs 'kube-scheduler-pod-name'
# Usual errors will relate to not being able to connect to the API server or an incorrect config path,
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml
# Key things to check:
# --kubeconfig points to /etc/kubernetes/scheduler.conf
# No leftover --master flags pointing to old IPs
# Hostname/IP matches current control plane (controlplaneIP:6443)
# Check cert files are correct
```
</details>

## Question 15

**Question file:** `Question-15/Questions.txt`

```bash
# Question: Taints & Tolerances

# Tasks:
# 1. Add a taint to node01 so tht no normal pods can be scheduled in this node. key=PERMISSION, value=granted, Type=NoSchedule
# 2. Schedule a Pod on node01 adding the correct toleration to the spec so it can be deployed

# Video Link
https://youtu.be/-rs3AoAVyXE?si=nACYrGA5h_4WL-og
```

<details>
<summary>Solution Notes</summary>

```bash
# Step One
# First thing we need to do is add the taint to node01. You can use
k taint --help

# Which gives you a format to use

# Update node 'foo' with a taint with key 'dedicated' and value 'special-user' and effect 'NoSchedule'
# If a taint with that key and effect already exists, its value is replaced as specified
kubectl taint nodes foo dedicated=special-user:NoSchedule

#For the question we have
k taint nodes node01 PERMISSION=granted:NoSchedule

#Step Two
# We need to create a pod with the appropriate tolerations to be scheduled on node01
vi pod.yaml
#Working yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    env: test
spec:
  containers:
  - name: nginx
    image: nginx
    imagePullPolicy: IfNotPresent
  tolerations:
  - key: "PERMISSION"
    operator: "Equal"
    value: "granted"
    effect: "NoSchedule"
#apply
k apply -f pod.yaml
#check
k get po
# We should see the pod has created as expected

# Step 3
# To test the taint is working as expected create a pod you know doesn't have the tolerations needed
vi podfailure.yaml
# yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-fail
  labels:
    env: test
spec:
  containers:
  - name: nginx
    image: nginx
    imagePullPolicy: IfNotPresent
  tolerations:
  - key: "example-key"
    operator: "Exists"
    effect: "NoSchedule"
#apply
k apply -f podfailure.yaml
#check
k get po
# We should see this pod in a pending state
k describe po nginx-fail
# We should see the following
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  13s   default-scheduler  0/2 nodes are available: 1 node(s) had untolerated taint {PERMISSION: granted}, 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }. preemption: 0/2 nodes are available: 2 Preemption is not helpful for scheduling.
# delete the test pod
k delete po nginx-fail
```
</details>

## Question 16

**Question file:** `Question-16/Questions.txt`

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
<summary>Solution Notes</summary>

```bash
# Step One
# We need to edit the deployment to expose it on port 80, name it http using TCP protocol
k edit deployment -n relative nodeport-deployment

spec:
      containers:
      - image: nginx
        imagePullPolicy: Always
        name: nginx
        #This is the section we need to add
        ports:
        - name: http
          containerPort: 80
          protocol: TCP

# Verify the changes
k describe deployment -n relative nodeport-deployment | grep -i port
# We should see the following
Name:                   nodeport-deployment
Labels:                 app=nodeport-deployment
Selector:               app=nodeport-deployment
  Labels:  app=nodeport-deployment
    Port:          80/TCP     # THIS IS WHAT WE ARE INTERESTED IN
    Host Port:     0/TCP
OldReplicaSets:  nodeport-deployment-6fc449468d (0/0 replicas created)
NewReplicaSet:   nodeport-deployment-56b95f5667 (2/2 replicas created)
  Normal  ScalingReplicaSet  9m23s  deployment-controller  Scaled up replica set nodeport-deployment-6fc449468d from 0 to 2
  Normal  ScalingReplicaSet  2m37s  deployment-controller  Scaled up replica set nodeport-deployment-56b95f5667 from 0 to 1
  Normal  ScalingReplicaSet  2m36s  deployment-controller  Scaled down replica set nodeport-deployment-6fc449468d from 2 to 1
  Normal  ScalingReplicaSet  2m36s  deployment-controller  Scaled up replica set nodeport-deployment-56b95f5667 from 1 to 2
  Normal  ScalingReplicaSet  2m34s  deployment-controller  Scaled down replica set nodeport-deployment-6fc449468d from 1 to 0

# Step 2
# We need to create the service as per the given requirements, we know a service will require a selector so run
k get deployments -n relative nodeport-deployment --show-labels

NAME                  READY   UP-TO-DATE   AVAILABLE   AGE   LABELS
nodeport-deployment   2/2     2            2           14m   app=nodeport-deployment

# We want to note the label for later use. Now we need to create a yaml file for our service
vi svc.yaml

# Use the kubernetes docs to get the yaml for creating a NodePort service
apiVersion: v1
kind: Service
metadata:
  name: nodeport-service
  namespace: relative
spec:
  type: NodePort
  selector:
    app: nodeport-deployment
  ports:
    - port: 80
      protocol: TCP
      targetPort: 80
      nodePort: 30080
# Apply the yaml file and check the service is running
k apply -f svc.yaml
k describe svc -n relative nodeport-service

# We need to verify the service is running as expected, we know the nodeport is 30080. We need to get the IP of
# the node the deployment is running on and check it using a curl command
k get nodes -owide # Get the node IP x.x.x.x

curl http://x.x.x.x:30080

#Output we should see
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

# As we have used the selector label from the deployment which exists
# on both pods we have exposed the individual pods
```
</details>

## Question 17

**Question file:** `Question-17/Questions.txt`

```bash
# Question:
# There is an existing deployment in the nginx-static namespace. The deployment contains a ConfigMap that supports
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
<summary>Solution Notes</summary>

```bash
# Step one
# We want to edit the config map to remove all references to tls v1.2
k edit cm -n nginx-static nginx-config # remove TLSv1.2 from SSL protocols (remove from last applied configuration for safety)

# Step 2
# We need to get the IP of the service
k get svc -n nginx-static
# We need to add this IP with the host name to /etc/hosts
sudo echo 'x.x.x.x ckaquestion.k8s.local' >> /etc/hosts
# Check the hosts file has been updated the IP and host should be added to the bottom of the file
sudo cat /etc/hosts

# Step 3
# If we run the check commands now we see v1.2 is still working, this is because we need to restart the deployment to use the new CM config
k rollout restart -n nginx-static deployment nginx-static
# Test the commands again and the v1.2 should no longer work
```
</details>

