#!/bin/bash

# 1. Έλεγχος Σύνδεσης και VPN
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null)
if [ -z "$CURRENT_CONTEXT" ]; then
    echo "Δεν βρέθηκε ενεργή σύνδεση με το Kubernetes."
    echo "Παρακαλώ συνδεθείτε στο VPN της σχολής και ελέγξτε το ~/.kube/config"
    exit 1
fi

# 2. Εντοπισμός Namespace
NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
if [ -z "$NAMESPACE" ]; then
    NAMESPACE="default"
fi
echo "Εντοπίστηκε το Namespace: $NAMESPACE"

# 3. Έλεγχος αν η πόρτα 30080 είναι κατειλημμένη στο Cluster
echo "Έλεγχος διαθεσιμότητας της θύρας NodePort 30080..."
PORT_BUSY=$(kubectl get svc --all-namespaces -o jsonpath='{.items[*].spec.ports[*].nodePort}' | grep -w "30080")

if [ ! -z "$PORT_BUSY" ]; then
    echo "Η θύρα 30080 χρησιμοποιείται ήδη από άλλον φοιτητή!"
    echo "Αυτόματη αλλαγή σε Dynamic NodePort (τυχαία ελεύθερη θύρα)..."
    # Αφαιρούμε τη γραμμή με το καρφωτό nodePort για να δώσει το K8s τυχαία ελεύθερη
    cat k8s/07-service-app.yaml | grep -v "nodePort:" > k8s/07-service-app-dynamic.yaml
    SERVICE_FILE="k8s/07-service-app-dynamic.yaml"
else
    echo "Η θύρα 30080 είναι ελεύθερη. Χρήση του default NodePort."
    SERVICE_FILE="k8s/07-service-app.yaml"
fi

# 4. Εκτέλεση του Deployment
echo "Δημιουργία και εφαρμογή των Kubernetes manifests..."
kubectl apply -f k8s/01-configmap.yaml
kubectl apply -f k8s/02-secret.yaml
kubectl apply -f k8s/03-pvc.yaml
kubectl apply -f k8s/04-deployment-db.yaml
kubectl apply -f k8s/05-service-db.yaml

echo "Αναμονή για την ετοιμότητα της βάσης (PostgreSQL)..."
kubectl rollout status deployment/postgres --timeout=60s

echo "Deployment της Flask εφαρμογής (3 Replicas)..."
kubectl apply -f k8s/06-deployment-app.yaml
kubectl apply -f $SERVICE_FILE

# Καθαρισμός προσωρινού αρχείου αν δημιουργήθηκε
if [ -f "k8s/07-service-app-dynamic.yaml" ]; then
    rm k8s/07-service-app-dynamic.yaml
fi

# 5. Εξαγωγή στοιχείων πρόσβασης
echo "Το Deployment ολοκληρώθηκε επιτυχώς!"


# Εύρεση της τελικής πόρτας που εκχωρήθηκε (καρφωτή ή τυχαία)
FINAL_PORT=$(kubectl get svc voting-app -o jsonpath='{.spec.ports[0].nodePort}')

echo "Κύρια Εφαρμογή: http://source-code-master.cluster.local:$FINAL_PORT/"
echo "Στατιστικά: http://source-code-master.cluster.local:$FINAL_PORT/stats"
