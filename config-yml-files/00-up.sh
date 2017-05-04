# create a GCE persistent disk
gcloud compute disks create --size=5GB --zone=us-east1-b gce-nfs-disk

# create a GKE cluster
# gcloud container clusters create mappedinn-cluster --machine-type=g1-small --num-nodes=1
gcloud container clusters create mappedinn-cluster --num-nodes=3

# changing the context of kubectl
gcloud container clusters get-credentials mappedinn-cluster --zone us-east1-b --project mappedinn
## but it seems to be not necessary since after creating the cluster the context has been automatically changed

kubectl create -f 01-pv-gce.yml
kubectl create -f 02-dep-nfs.yml
kubectl create -f 03-srv-nfs.yml
kubectl get services # you have to update the file 04-pv-pvc with the new IP address of the service 
kubectl create -f 04-pv-pvc.yml
kubectl create -f 05-mysql.yml
kubectl create -f 06-wordpress.yml


# clean up the cluster
## deleting the cluser
gcloud container clusters delete mappedinn-cluster

## deleting the GCE PV
gcloud compute disks delete gce-nfs-disk
