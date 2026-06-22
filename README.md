# Would You Rather? – Scalable Cloud Application

Αυτή η εφαρμογή υλοποιήθηκε στα πλαίσια του μαθήματος **Cloud Computing**. Πρόκειται για ένα data-driven microservices web application βασισμένο σε πραγματικά δεδομένα, με πλήρη υποστήριξη Docker, Docker Compose και Kubernetes.

---

## Πίνακας Περιεχομένων

1. [Δομή Repository](#1-δομή-repository)
2. [Dataset & Data Preparation](#2-dataset--data-preparation)
3. [Dockerization](#3-dockerization)
4. [Εκτέλεση με Docker Compose](#4-εκτέλεση-με-docker-compose)
5. [Kubernetes Deployment](#5-kubernetes-deployment)
6. [Makefile – Αυτοματοποίηση](#6-makefile--αυτοματοποίηση)
7. [Automated Testing](#7-automated-testing)
8. [API Endpoints](#8-api-endpoints)

---

## 1. Δομή Repository

```
.
├── app.py                  # Flask application (routes, DB logic)
├── questions.json          # Dataset – φορτώνεται αυτόματα στην DB
├── requirements.txt        # Python dependencies
├── Dockerfile              # Production-ready image
├── .dockerignore           # Αποκλεισμός περιττών αρχείων από το image
├── docker-compose.yml      # Τοπική εκτέλεση (app + db + pgAdmin)
├── Makefile                # Αυτοματοποίηση build / deploy / rollback
├── test_app.py             # Unit tests (pytest)
├── templates/
│   ├── ui.html             # Κύρια σελίδα ψηφοφορίας
│   └── stats.html          # Σελίδα αποτελεσμάτων
└── k8s/
    ├── 01-configmap.yaml   # Μη-ευαίσθητες ρυθμίσεις DB
    ├── 02-secret.yaml      # DB password (⚠ μην το commit σε production)
    ├── 03-pvc.yaml         # PersistentVolumeClaim 1Gi για την DB
    ├── 04-deployment-db.yaml   # PostgreSQL Deployment
    ├── 05-service-db.yaml      # ClusterIP Service για την DB
    ├── 06-deployment-app.yaml  # voting-app Deployment (3 replicas)
    └── 07-service-app.yaml     # NodePort Service (port 30080)
```

---

## 2. Dataset & Data Preparation

Για τις ανάγκες της εφαρμογής χρησιμοποιήθηκε ένα πραγματικό dataset από το Kaggle:

[Kaggle Dataset: Would You Rather](https://www.kaggle.com/datasets/charlieray668/would-you-rather)

### Διαδικασία Επεξεργασίας (Data Cleaning)

Το αρχικό αρχείο ήταν σε μορφή `.csv` και περιείχε στήλες με έτοιμα στατιστικά ψήφων (`votes_a`, `votes_b`) τα οποία έπρεπε να αφαιρεθούν, καθώς η εφαρμογή υπολογίζει live τις δικές της ψηφοφορίες.

Με Python (`pandas`) έγινε η επεξεργασία:

1. Κρατήθηκαν αποκλειστικά οι στήλες `option_a` και `option_b`.
2. Αφαιρέθηκαν όλα τα metadata και οι παλιοί ψήφοι.
3. Τα δεδομένα μετατράπηκαν σε `questions.json`, το οποίο φορτώνεται αυτόματα στη βάση κατά την εκκίνηση.

---

## 3. Dockerization

Η εφαρμογή έχει πακεταριστεί σε Docker image ακολουθώντας βέλτιστες πρακτικές ασφαλείας και αποδοτικότητας.

| Χαρακτηριστικό | Λεπτομέρεια |
|---|---|
| **Base Image** | `python:3.12-slim` – ελαχιστοποίηση μεγέθους |
| **Security** | Non-root χρήστης `appuser` με `nologin` shell |
| **WSGI Server** | `gunicorn` με 2 workers (όχι Flask dev server) |
| **Layer Caching** | Πρώτα `requirements.txt`, μετά ο κώδικας |
| **`.dockerignore`** | Αποκλείει tests, `.venv`, `Makefile`, `*.yaml` |

### Build & Run (χωρίς Compose)

```bash
# Build
docker build -t nikolasmin/would-you-rather:0.1.0 .

# Run (χρειάζεται εξωτερική DB)
docker run -d -p 8080:8080 \
  -e DB_HOST=<host> -e DB_NAME=votedb \
  -e DB_USER=voteuser -e DB_PASSWORD=votepass \
  nikolasmin/would-you-rather:0.1.0
```

---

## 4. Εκτέλεση με Docker Compose

Ο πιο απλός τρόπος για τοπική ανάπτυξη. Εκκινεί τρία services: **PostgreSQL**, **voting-app**, και **pgAdmin**.

```bash
# Εκκίνηση όλων των services στο background
docker compose up -d --build

# Διακοπή και διαγραφή containers
docker compose down
```

| Service | URL |
|---|---|
| Εφαρμογή | http://localhost:8080 |
| pgAdmin | http://localhost:5050 (admin@admin.com / admin) |

> **Σημείωση:** Το `app` service περιμένει αυτόματα να γίνει healthy η DB πριν ξεκινήσει (`depends_on` + healthcheck).

---

## 5. Kubernetes Deployment

Για production deployment σε Kubernetes cluster (π.χ. Minikube, GKE, EKS).

### Απαιτήσεις

- `kubectl` configured για τον cluster σου
- Docker image push σε Docker Hub (βλ. Makefile παρακάτω)

### Τι κάνει κάθε manifest

| Αρχείο | Τι ορίζει |
|---|---|
| `01-configmap.yaml` | DB_HOST, DB_NAME, DB_USER ως ConfigMap |
| `02-secret.yaml` | DB password ως Kubernetes Secret |
| `03-pvc.yaml` | PersistentVolumeClaim 1Gi για τα δεδομένα της PostgreSQL |
| `04-deployment-db.yaml` | PostgreSQL 16 με liveness/readiness probes και resource limits |
| `05-service-db.yaml` | ClusterIP Service – η DB δεν εκτίθεται εκτός cluster |
| `06-deployment-app.yaml` | voting-app με **3 replicas**, probes σε `/healthz` και `/readyz` |
| `07-service-app.yaml` | NodePort (30080) με `sessionAffinity: ClientIP` για σταθερό session |

> Το `sessionAffinity: ClientIP` στο `07-service-app.yaml` εξασφαλίζει ότι ο ίδιος χρήστης
> εξυπηρετείται πάντα από το ίδιο replica, ώστε να μη χάνεται το Flask session κατά το load balancing.

### Βήματα Deploy

```bash
# 1. Build & push image
make build push DOCKER_USER=nikolasmin VERSION=0.1.0

# 2. Deploy στο cluster
make deploy

# 3. Port-forward για τοπική πρόσβαση
kubectl port-forward svc/voting-app 8080:80

# Ή με NodePort (αν τρέχεις Minikube)
minikube service voting-app
```

## 5.1 Προαπαιτούμενα

Για την εκτέλεση της εφαρμογής στο Kubernetes cluster της σχολής απαιτούνται:

* Ενεργή σύνδεση στο VPN της σχολής.
* Το αρχείο ρυθμίσεων πρόσβασης (`kubeconfig`) που παρέχεται από το εργαστήριο, τοποθετημένο στη διαδρομή:

```text id="2wq6wq"
~/.kube/config
```

* Εγκατεστημένα τοπικά τα εργαλεία `kubectl` και `make`.

## 5.2 Βήματα Εγκατάστασης (Step-by-Step)

### Βήμα 1: Clone του Repository

```bash id="0rzf5j"
git clone <repository-url>
cd <repository-directory>
```

### Βήμα 2: Έλεγχος Σύνδεσης με το Cluster

Βεβαιωθείτε ότι το `kubectl` επικοινωνεί σωστά με το Kubernetes cluster της σχολής:

```bash id="3pygsk"
kubectl config current-context
```

### Βήμα 3: Αυτοματοποιημένο Deployment

Χάρη στο `Makefile`, δεν απαιτείται η χειροκίνητη εκτέλεση των επιμέρους αρχείων YAML. Η εγκατάσταση πραγματοποιείται με μία μόνο εντολή:

```bash id="vw7nxy"
make deploy
```

#### Τι εκτελείται στο παρασκήνιο;

1. Δημιουργείται το αποθηκευτικό μέσο (`PersistentVolumeClaim`).
2. Δημιουργούνται οι ρυθμίσεις της εφαρμογής (`ConfigMap` και `Secret`).
3. Εκκινείται η PostgreSQL.
4. Μόλις η βάση περάσει επιτυχώς τα `readiness probes`, το cluster κατεβάζει το έτοιμο image από το Docker Hub (`nikolasmin/would-you-rather:0.1.0`).
5. Εκκινούνται τα `3 replicas` της εφαρμογής Flask.

## 5.3 Έλεγχος Κατάστασης των Resources

H κατάσταση των resources του namespace μπορεί να ελεγχθεί με την εντολή:

```bash id="vtjlwm"
kubectl get nodes
```
H

```bash id="d8t3y4"
make status
```

Όλα τα Pods της εφαρμογής (`3 replicas`) καθώς και το Pod της βάσης δεδομένων πρέπει να εμφανίζουν κατάσταση:

```text id="nkp4nn"
STATUS: Running
```

## 5.4 Live Πρόσβαση μέσω του VPN της Σχολής

Λόγω της χρήσης `NodePort Service` στην πόρτα `30080` και των εσωτερικών DNS εγγραφών του εργαστηρίου, η εφαρμογή είναι μόνιμα προσβάσιμη σε οποιονδήποτε είναι συνδεδεμένος στο VPN της σχολής.

### Πρόσβαση στην εφαρμογή

```text id="9g7fka"
http://source-code-master.cluster.local:30080/
```

H και με την ip που εμφανιζεται οταν εκτελεις την εντολη:

```bash id="vtjlwm"
ping source-code-master.cluster.local
```

### Στατιστικά και Πληροφορίες Replicas

```text id="efm2qx"
http://source-code-master.cluster.local:30080/stats
```

Το endpoint `/stats` εμφανίζει σε πραγματικό χρόνο πληροφορίες σχετικά με την κατάσταση της εφαρμογής, συμπεριλαμβανομένου του συγκεκριμένου Pod (Hostname) που εξυπηρέτησε το αίτημα. Με αυτόν τον τρόπο μπορεί να παρατηρηθεί στην πράξη η λειτουργία των πολλαπλών replicas και του μηχανισμού load balancing του Kubernetes.

| Service | URL |
|---------|-----|
| Εφαρμογή | [http://source-code-master.cluster.local:30080/](http://source-code-master.cluster.local:30080/) |
| Στατιστικά | [http://source-code-master.cluster.local:30080/stats/](http://source-code-master.cluster.local:30080/stats/) |

## 5.5 Καθαρισμός και Μηδενισμός της Βάσης Δεδομένων (Database Reset)

Η PostgreSQL χρησιμοποιεί `PersistentVolumeClaim (PVC)` για την αποθήκευση των δεδομένων. Ως αποτέλεσμα, οι ψήφοι και τα στατιστικά της εφαρμογής αποθηκεύονται μόνιμα στον δίσκο του server και διατηρούνται ακόμη και σε περίπτωση επανεκκίνησης ή αναδημιουργίας των Pods.

Αν επιθυμείτε να μηδενίσετε πλήρως τα δεδομένα της εφαρμογής και να ξεκινήσετε από καθαρή κατάσταση (π.χ. πριν από μία παρουσίαση ή νέα επίδειξη), ακολουθήστε τα παρακάτω βήματα.

### Βήμα 1: Πλήρης διαγραφή των πόρων

```bash id="f5whq2"
make clean
```

Η εντολή αυτή διαγράφει όλα τα Kubernetes resources που δημιουργήθηκαν από την εφαρμογή, συμπεριλαμβανομένων των `Deployments`, `Services` και του `PersistentVolumeClaim (PVC)`, αφαιρώντας οριστικά όλα τα αποθηκευμένα δεδομένα και τα στατιστικά των ψήφων.

### Βήμα 2: Επανεκκίνηση από καθαρή κατάσταση

```bash id="8z7nqp"
make deploy
```

Κατά την εκ νέου εγκατάσταση, το Kubernetes δημιουργεί έναν καινούργιο, κενό χώρο αποθήκευσης. Μόλις εκκινήσει η εφαρμογή Flask, ο κώδικας εντοπίζει ότι η βάση δεδομένων είναι άδεια, διαβάζει το αρχείο `questions.json` και αρχικοποιεί αυτόματα τη βάση με τις δέκα (10) προκαθορισμένες ερωτήσεις.

Με τον τρόπο αυτό, η εφαρμογή ξεκινά από πλήρως καθαρή κατάσταση, έτοιμη για νέα καταγραφή ψήφων και στατιστικών.


---

## 6. Makefile – Αυτοματοποίηση

Το `Makefile` παρέχει shortcut εντολές για ολόκληρο τον κύκλο ζωής της εφαρμογής.

| Target | Περιγραφή |
|---|---|
| `make help` | Λίστα όλων των διαθέσιμων targets |
| `make test` | Εκτέλεση pytest τοπικά |
| `make build` | Build Docker image |
| `make push` | Push στο Docker Hub |
| `make deploy` | Deploy όλων των k8s manifests με σωστή σειρά |
| `make status` | Εμφάνιση Deployments, Pods, Services, PVCs |
| `make logs` | Tail logs από όλα τα app replicas |
| `make rollback` | Rollback στην προηγούμενη έκδοση |
| `make clean` | Διαγραφή όλων των k8s resources |

**Παραμετροποίηση:**

```bash
make build push DOCKER_USER=myusername VERSION=1.2.0
```


## 6.1 Διαχείριση Εκδόσεων (Versioning & Rolling Updates)

Η εφαρμογή υποστηρίζει δυναμικό versioning και Continuous Deployment (CD) απευθείας μέσω του `Makefile`. Στο Docker Hub βρίσκονται ήδη δημοσιευμένες διαφορετικές εκδόσεις της εφαρμογής με αμετάβλητα tags (π.χ. `0.1.0`, `0.2.0`, `0.3.0`).

### 1. Αμετάβλητες Εκδόσεις (Immutable Infrastructure)

Ως προεπιλογή (default), η εντολή `make deploy` χρησιμοποιεί την έκδοση `0.1.0`, η οποία τραβιέται αυτόματα από το Docker Hub:

```bash
nikolasmin/would-you-rather:0.1.0
```

Η χρήση συγκεκριμένων version tags αντί του `:latest` αποτελεί βέλτιστη πρακτική, καθώς εγγυάται τη σταθερότητα, την προβλεψιμότητα και την επαναληψιμότητα (reproducibility) του deployment.

### 2. Δυναμική Αναβάθμιση (On-the-fly Update)

Για την ανάπτυξη μιας νεότερης έκδοσης, μπορεί να περαστεί η μεταβλητή `VERSION` κατά την εκτέλεση:

```bash
make deploy VERSION=0.3.0
```

#### Τι συμβαίνει στο παρασκήνιο;

1. Το `Makefile` αντικαθιστά δυναμικά το placeholder στο `06-deployment-app.yaml` με το tag `:0.3.0`.
2. Το Kubernetes εντοπίζει την αλλαγή στο image και ξεκινά αυτόματα ένα **Rolling Update**.
3. Τα παλιά Pods αντικαθίστανται σταδιακά, ένα-ένα, από νέα Pods που εκτελούν την έκδοση `0.3.0`.
4. Η διαδικασία πραγματοποιείται με **μηδενικό χρόνο διακοπής (Zero Downtime)**.
5. Η τρέχουσα έκδοση εμφανίζεται δυναμικά και στο UI της εφαρμογής μέσω του endpoint `/stats`, το οποίο διαβάζει την τιμή της μεταβλητής περιβάλλοντος `APP_VERSION`.

> **Σημείωση:** Η έκδοση `0.3.0` θεωρείται πειραματική (experimental) και δεν είναι τόσο αξιόπιστη όσο οι προηγούμενες εκδόσεις. Για χρήση σε περιβάλλον παραγωγής (production) προτείνεται η έκδοση `0.2.0`, η οποία έχει ελεγχθεί και αποτελεί την τρέχουσα σταθερή έκδοση.

```bash
make deploy VERSION=0.2.0
```

### 3. Μηχανισμός Rollback

Αν η νέα έκδοση παρουσιάσει προβλήματα ή μη αναμενόμενη συμπεριφορά, μπορεί να γίνει άμεση επαναφορά στην προηγούμενη σταθερή κατάσταση με μία μόνο εντολή:

```bash
make rollback
```

Η εντολή εκτελεί:

```bash
kubectl rollout undo deployment/would-you-rather
```

Το Kubernetes επαναφέρει αυτόματα το προηγούμενο ReplicaSet, παρέχοντας έναν γρήγορο και ασφαλή μηχανισμό επαναφοράς (rollback) με ελάχιστο λειτουργικό κίνδυνο.


---

## 7. Automated Testing

Για τη διασφάλιση της ορθής λειτουργίας των routes, υλοποιήθηκαν unit tests με `pytest` που **δεν απαιτούν σύνδεση με βάση δεδομένων**.

```bash
make test
# ή απευθείας:
python -m pytest -q
```

| Test | Τι ελέγχει |
|---|---|
| `test_healthz_returns_ok` | GET `/healthz` → `{"status": "ok"}` με status 200 |
| `test_version_returns_version_field` | GET `/version` → JSON με string πεδίο `version` |

---

## 8. API Endpoints

| Method | Path | Περιγραφή |
|---|---|---|
| `GET` | `/` | Κύρια σελίδα – εμφανίζει την τρέχουσα ερώτηση |
| `POST` | `/vote` | Καταχωρεί ψήφο και προχωράει στην επόμενη ερώτηση |
| `GET` | `/stats` | Αποτελέσματα όλων των ερωτήσεων με ποσοστά |
| `GET` | `/restart` | Επαναφέρει session και διαγράφει τους ψήφους |
| `GET` | `/healthz` | Liveness probe – πάντα επιστρέφει `{"status": "ok"}` |
| `GET` | `/readyz` | Readiness probe – ελέγχει σύνδεση με DB |
| `GET` | `/version` | Επιστρέφει την έκδοση της εφαρμογής |

---

# 9. Πειραματικό One-Click Script (run.sh)

> **Προειδοποίηση (Warning):** Το script `run.sh` είναι πειραματικό (experimental) και δεν έχει ελεγχθεί πλήρως σε όλα τα περιβάλλοντα εκτέλεσης. Προορίζεται κυρίως για δοκιμές αυτοματοποιημένης διαχείρισης συγκρούσεων θυρών (port conflicts). Η προτεινόμενη και πλήρως υποστηριζόμενη μέθοδος εγκατάστασης παραμένει η χρήση της εντολής `make deploy`.

Στο repository περιλαμβάνεται το script `run.sh`, το οποίο επιχειρεί να αυτοματοποιήσει πλήρως τη διαδικασία εγκατάστασης της εφαρμογής από τρίτους χρήστες στο Kubernetes cluster της σχολής.

Κατά την εκτέλεσή του, το script πραγματοποιεί δυναμικό έλεγχο του cluster και ελέγχει εάν η προεπιλεγμένη θύρα `NodePort 30080` χρησιμοποιείται ήδη από κάποιον άλλο χρήστη ή namespace. Σε περίπτωση σύγκρουσης, τροποποιεί δυναμικά (on-the-fly) το manifest του Service και ζητά από το Kubernetes να εκχωρήσει μια τυχαία διαθέσιμη θύρα (`NodePort`) από το επιτρεπόμενο εύρος θυρών.

Με τον τρόπο αυτό αποφεύγονται σφάλματα τύπου:

```text id="q8x2bn"
provided port is already allocated
```

ή

```text id="k5p8fh"
port already allocated
```

Ο μηχανισμός αυτός επιτρέπει την εκτέλεση πολλαπλών ανεξάρτητων deployments στο ίδιο cluster χωρίς χειροκίνητη αλλαγή των manifests, διευκολύνοντας τις δοκιμές και την πειραματική χρήση της εφαρμογής από διαφορετικούς χρήστες.

