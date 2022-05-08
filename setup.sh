#!/bin/bash
echo "This script will setup environmnet for your CI/CD environment with Jenkins"

# Set GCP Project and region
PROJECT_ID=luiz-devops-jenkins
REGION=us-central1
ZONE=us-central1-f
ZONE1=us-central1-f
ZONE2=us-central1-b
JENKINS_VPC=jenkinsvpc
JENKINS_FW=jenkinsfw
JENKINS_CLUSTER=jenkinscluster

gcloud auth login --no-browser

echo "Set default projet:$PROJECT_ID and zone:$ZONE."

gcloud config set project  $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

#Create Virtual Private Cloud for Jenkins cluster
gcloud compute networks create $JENKINS_VPC --subnet-mode auto
gcloud compute firewall-rules create $JENKINS_FW --network $JENKINS_VPC --allow tcp:22,tcp:80,tcp:8080,tcp:30000,tcp:50000,tcp:443,icmp --source-ranges 0.0.0.0/0

#NOTE: The first time, if Kubernetes API not configured, the creation fails!!
# https://console.cloud.google.com/apis/api/container
# gcloud services enable container.googleapis.com ADDED on 5/6/2022
echo "Enabling Kubernets API"
gcloud services enable container.googleapis.com

echo "K8S Cluster:$JENKINS_CLUSTER"
gcloud container clusters create $JENKINS_CLUSTER \
--network $JENKINS_VPC \
--zone $ZONE \
--scopes "https://www.googleapis.com/auth/projecthosting,storage-rw"

# Create Kubenets cluster
echo "Creating namespace for Kubernets..."
kubectl get namespace

kubectl create -f ./jenkinsnamespace.yaml
echo "Kubernets namespace created."
kubectl get namespace

# Get credential of the cluster (to use kubectl)
gcloud container clusters get-credentials $JENKINS_CLUSTER

# Display cluster information
kubectl get nodes
kubectl get services

# Jenkins setup
PASSWD=`openssl rand -base64 15`
echo "Generated password for kubernets:$PASSWD"

echo "--argumentsRealm.passwd.jenkins=$PASSWD --argumentsRealm.roles.jenkins=admin" > options
echo "option file generated with the password..."
echo "Jenkins login credential:"
echo "    username:jenkins"
echo "    password:$PASSWD"

kubectl create secret generic jenkins --from-file=options --namespace=jenkinsgcp
echo "secret in Kubernets created."

# Add administrative roles to manage the Kubernets cluster
echo "Adding administrative role to Kubernets cluster..."
kubectl create clusterrolebinding cluster-admin-bining \
 --clusterrole=cluster-admin \
 --user=$(gcloud config get-value account)

# Deploy Kubernets deployment and the service
echo "Start Kubernets deployment and services ..."
kubectl apply -f k8s/jenkins_deployment.yaml
kubectl apply -f k8s/jenkins_backend_service.yaml
# Exposing the service
echo "Exposing the service..."
#echo "Exposing the service...as NodePort"
#kubectl apply -f k8s/jenkins_nodeport_service.yaml
echo "Exposing the service...as LoadBalancer"
kubectl apply -f loadbalancer/lb.yaml
#echo "Exposing the service...as INGRESS"
#kubectl apply -f ingress/ingress.yaml

# Check pods and services
echo "Checking the status ..."
kubectl get pods --namespace jenkinsgcp
kubectl get services --namespace jenkinsgcp
# Check ingress
#echo "Checking the ingress status ..."
#kubectl describe ingress jenkins --namespace jenkinsgcp

# TLS Certificate (self-signed)
echo "Generating Certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=jenkins/O=jenkins"
echo "OpenSSL Certificate generated."
cat tls.key
cat tls.crt

kubectl create secret generic tls --from-file=tls.crt --from-file=tls.key --namespace jenkinsgcp

echo "(NOTE) To access the Jenkins server portal, open the browser and put the ADDRESS (ip address of the server)."
echo "(NOTE) Jenkins server administrator credential is as the following:"
echo -e "\e[31musername: jenkins\e[0m"
echo -e "\e[31mpassword: $PASSWD\e[0m (You can find the information on the option file as well...)"
cat options

echo "You may need to wait a while and check the completion of the ingression creation."
echo "You can check by executing <kubectl get ingress --namespace jenkinsgcp>."

# Completion message here
echo "completed!!"
