# Kubernetes wordpress sharing NFS volume with mySQL on Google Container Engine (GKE)

This Kubernetes project is implementing the wordpress application that shares an NFS volume with mySQL. The idea behind sharing a NFS volume between pods is to implement in the next step a StatefulSet for mySQL. This StatefulSet application will need to share the database between all the pods of mySQL so that a multi node database is created that ensures the requested high performance.

To do that, there is an example [janakiramm/wp-statefulset](https://github.com/janakiramm/wp-statefulset). This example is using `etcd`. So why not using `nfs` in stead of `etcd`?

Below is then a trial to implement it with `nfs`.

## 1. create a GCE persistent disk

```
gcloud compute disks create --size=5GB --zone=us-east1-b gce-nfs-disk
```

## 2. create a GKE cluster
```
gcloud container clusters create mappedinn-cluster --num-nodes=3
```

## 3. changing the context of kubectl
```
# (if needed)
gcloud container clusters get-credentials mappedinn-cluster --zone us-east1-b --project mappedinn
```

## 4. Creation of the Kubernetes wordpress

```
# creation of PV and PVC for the nfs server Deployment
kubectl create -f 01-pv-gce.yml

# creation of the Deployment for the NFS server
kubectl create -f 02-dep-nfs.yml

# Creation of a service for the NFS server
kubectl create -f 03-srv-nfs.yml

# Getting the IP address of the `nfs-server` to update the file 04-pv-pvc.yml file
kubectl get services

# Creation of the NFS PV and NFS PVC to be shared by wordpress and mysql
kubectl create -f 04-pv-pvc.yml

# create a mysql Deployment with its service
kubectl create -f 05-mysql.yml

# create a wordpress Deployment with its service
kubectl create -f 06-wordpress.yml
```

## 5. Issue

The problem is that the wordpress pod is not succeding to start as it can be seen down:

```
$ kubectl get pods
NAME                              READY     STATUS             RESTARTS   AGE
nfs-server-2899972627-jgjx0       1/1       Running            0          4m
wp01-mysql-1941769936-m9jjd       1/1       Running            0          3m
wp01-wordpress-2362719074-bv53t   0/1       CrashLoopBackOff   4          2m
```

This is the output of the `kubectl describe pods`:

```
$ kubectl describe pods wp01-wordpress-2362719074-bv53t
Name:		wp01-wordpress-2362719074-bv53t
Namespace:	default
Node:		gke-mappedinn-cluster-default-pool-6264f94a-z0sh/10.240.0.4
Start Time:	Thu, 04 May 2017 05:59:12 +0400
Labels:		app=wp01
		pod-template-hash=2362719074
		tier=frontend
Annotations:	kubernetes.io/created-by={"kind":"SerializedReference","apiVersion":"v1","reference":{"kind":"ReplicaSet","namespace":"default","name":"wp01-wordpress-2362719074","uid":"44b91da0-306d-11e7-a0d1-42010a...
		kubernetes.io/limit-ranger=LimitRanger plugin set: cpu request for container wordpress
Status:		Running
IP:		10.244.0.4
Controllers:	ReplicaSet/wp01-wordpress-2362719074
Containers:
  wordpress:
    Container ID:	docker://658c7392c1b7a5033fe1a1b456a9653161003ee2878a4f02c6a12abb49241d47
    Image:		wordpress:4.6.1-apache
    Image ID:		docker://sha256:ee397259d4e59c65e2c1c5979a3634eb3ab106bba389acea8b21862053359134
    Port:		80/TCP
    State:		Waiting
      Reason:		CrashLoopBackOff
    Last State:		Terminated
      Reason:		Error
      Exit Code:	1
      Started:		Thu, 04 May 2017 06:03:16 +0400
      Finished:		Thu, 04 May 2017 06:03:16 +0400
    Ready:		False
    Restart Count:	5
    Requests:
      cpu:	100m
    Environment:
      WORDPRESS_DB_HOST:	wp01-mysql
      WORDPRESS_DB_PASSWORD:	<set to the key 'password' in secret 'wp01-pwd-wordpress'>	Optional: false
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-k650h (ro)
      /var/www/html from wordpress-persistent-storage (rw)
Conditions:
  Type		Status
  Initialized 	True
  Ready 	False
  PodScheduled 	True
Volumes:
  wordpress-persistent-storage:
    Type:	PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:	wp01-pvc-data
    ReadOnly:	false
  default-token-k650h:
    Type:	Secret (a volume populated by a Secret)
    SecretName:	default-token-k650h
    Optional:	false
QoS Class:	Burstable
Node-Selectors:	<none>
Tolerations:	<none>
Events:
  FirstSeen	LastSeen	Count	From								SubObjectPath			Type		Reason		Message
  ---------	--------	-----	----								-------------			--------	------		-------
  5m		5m		1	default-scheduler										Normal		Scheduled	Successfully assigned wp01-wordpress-2362719074-bv53t to gke-mappedinn-cluster-default-pool-6264f94a-z0sh
  4m		4m		1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal		Pulling		pulling image "wordpress:4.6.1-apache"
  4m		4m		1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal		Pulled		Successfully pulled image "wordpress:4.6.1-apache"
  4m		4m		1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal		Created		Created container with docker id 8647e997d6f4; Security:[seccomp=unconfined]
  4m		4m		1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal		Started		Started container with docker id 8647e997d6f4
  4m		4m		1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal		Created		Created container with docker id 37f4f0fd392d; Security:[seccomp=unconfined]
  4m		4m		1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal		Started		Started container with docker id 37f4f0fd392d
  4m		4m		1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh					Warning		FailedSync	Error syncing pod, skipping: failed to "StartContainer" for "wordpress" with CrashLoopBackOff: "Back-off 10s restarting failed container=wordpress pod=wp01-wordpress-2362719074-bv53t_default(44ba1226-306d-11e7-a0d1-42010a8e0084)"

  3m	3m	1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal	Created		Created container with docker id b78a661388a2; Security:[seccomp=unconfined]
  3m	3m	1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal	Started		Started container with docker id b78a661388a2
  3m	3m	2	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh					Warning	FailedSync	Error syncing pod, skipping: failed to "StartContainer" for "wordpress" with CrashLoopBackOff: "Back-off 20s restarting failed container=wordpress pod=wp01-wordpress-2362719074-bv53t_default(44ba1226-306d-11e7-a0d1-42010a8e0084)"

  3m	3m	1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal	Created		Created container with docker id 2b6384407678; Security:[seccomp=unconfined]
  3m	3m	1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal	Started		Started container with docker id 2b6384407678
  3m	2m	4	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh					Warning	FailedSync	Error syncing pod, skipping: failed to "StartContainer" for "wordpress" with CrashLoopBackOff: "Back-off 40s restarting failed container=wordpress pod=wp01-wordpress-2362719074-bv53t_default(44ba1226-306d-11e7-a0d1-42010a8e0084)"

  2m	2m	1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal	Created		Created container with docker id 930a3410b213; Security:[seccomp=unconfined]
  2m	2m	1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal	Started		Started container with docker id 930a3410b213
  2m	1m	7	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh					Warning	FailedSync	Error syncing pod, skipping: failed to "StartContainer" for "wordpress" with CrashLoopBackOff: "Back-off 1m20s restarting failed container=wordpress pod=wp01-wordpress-2362719074-bv53t_default(44ba1226-306d-11e7-a0d1-42010a8e0084)"

  4m	1m	5	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal	Pulled		Container image "wordpress:4.6.1-apache" already present on machine
  1m	1m	1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal	Created		Created container with docker id 658c7392c1b7; Security:[seccomp=unconfined]
  1m	1m	1	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Normal	Started		Started container with docker id 658c7392c1b7
  4m	10s	19	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh	spec.containers{wordpress}	Warning	BackOff		Back-off restarting failed docker container
  1m	10s	5	kubelet, gke-mappedinn-cluster-default-pool-6264f94a-z0sh					Warning	FailedSync	Error syncing pod, skipping: failed to "StartContainer" for "wordpress" with CrashLoopBackOff: "Back-off 2m40s restarting failed container=wordpress pod=wp01-wordpress-2362719074-bv53t_default(44ba1226-306d-11e7-a0d1-42010a8e0084)"
```


# 6. Clean up the cluster

```
# deleting the cluser
gcloud container clusters delete mappedinn-cluster

# deleting the GCE PV
gcloud compute disks delete gce-nfs-disk
```
