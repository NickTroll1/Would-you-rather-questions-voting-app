# Would You Rather? - Scalable Cloud Application 🚀

Αυτή η εφαρμογή υλοποιήθηκε στα πλαίσια του μαθήματος Cloud Computing. Πρόκειται για ένα data-driven microservices web application (βασισμένο σε real-world dataset) το οποίο είναι πλήρως **scalable** και έχει σχεδιαστεί για να εκτελείται μέσα σε ένα **Kubernetes (K8s)** cluster.

---

## 📊 1. Το Dataset (Data Preparation)
Για τις ανάγκες της εφαρμογής χρησιμοποιήθηκε ένα πραγματικό dataset από το Kaggle:
🔗 [Kaggle Dataset: Would You Rather](https://www.kaggle.com/datasets/charlieray668/would-you-rather)

### Διαδικασία Επεξεργασίας (Data Cleaning):
Το αρχικό αρχείο ήταν σε μορφή `.csv` και περιείχε στήλες με έτοιμα στατιστικά ψήφων (`votes_a`, `votes_b`) τα οποία έπρεπε να αφαιρεθούν, καθώς η εφαρμογή μας έπρεπε να ξεκινάει με μηδενικούς ψήφους για να καταγράφει τη δική της live δραστηριότητα.

Με τη χρήση ενός Python Script (`pandas`), έγινε το ξεσκαρτάρισμα των δεδομένων:
1. Κρατήθηκαν αποκλειστικά οι στήλες `option_a` και `option_b`.
2. Αφαιρέθηκαν όλα τα περιττά metadata και οι παλιοί ψήφοι.
3. Τα δεδομένα μετατράπηκαν στην τελική μορφή `questions.json`, η οποία τροφοδοτείται αυτόματα στη βάση δεδομένων κατά την εκκίνηση του server.

---

## 🏗️ 2. Αρχιτεκτονική της Εφαρμογής & Cloud Components

Η εφαρμογή ακολουθεί μια **decoupled (διαχωρισμένη) αρχιτεκτονική** με 3 βασικά συστατικά:

1. **Frontend UI (HTML5 / CSS3 Flexbox):** Μια μοντέρνα split-screen (Tinder-style) διεπαφή, η οποία εμφανίζει live τα ποσοστά προτίμησης (%) μετά από κάθε ψήφο και φορτώνει αυτόματα την επόμενη τυχαία ερώτηση.
2. **Backend API (Node.js / Express):** Διαχειρίζεται τα requests, επικοινωνεί με τη βάση δεδομένων και περιλαμβάνει έναν τεχνητό αλγόριθμο φόρτου (CPU-heavy crypto hashing) για τη δοκιμή του scaling.
3. **Database (MongoDB):** NoSQL βάση δεδομένων που αποθηκεύει τις ερωτήσεις και αυξάνει δυναμικά τους ψήφους χρησιμοποιώντας την ατομική εντολή `$inc`.

---

## 🐳 3. Πακετάρισμα (Dockerization)
Η εφαρμογή έχει πακεταριστεί σε ένα ελαφρύ Docker Image βασισμένο στο `node:18-alpine` χρησιμοποιώντας το `Dockerfile`. Το image είναι δημόσια διαθέσιμο στο Docker Hub, επιτρέποντας στο Kubernetes cluster της σχολής να το τραβήξει (pull) άμεσα.

---

## ☸️ 4. Kubernetes Deployment & Horizontal Pod Autoscaling (HPA)

Η διαχείριση και το scaling της εφαρμογής γίνονται μέσω του αρχείου `kubernetes.yaml`. 

### Πώς επιτυγχάνεται το Scaling:
* Στο Deployment της εφαρμογής έχουν οριστεί αυστηρά **Resource Requests & Limits** (`cpu: "100m"`). Αυτό επιτρέπει στο Kubernetes να γνωρίζει με ακρίβεια πότε ένα Pod αρχίζει να πιέζεται.
* Έχει υλοποιηθεί ένας **Horizontal Pod Autoscaler (HPA)**, ο οποίος παρακολουθεί live τη χρήση της CPU. 
* **Κανόνας Scaling:** Αν η μέση κατανάλωση CPU των Pods ξεπεράσει το **50%**, το HPA ενεργοποιείται αυτόματα και κάνει scale-out την εφαρμογή από **1 σε έως και 5 Pods** (αντίγραφα), μοιράζοντας την κίνηση μέσω ενός Kubernetes ClusterIP Service (Load Balancer).

---

## 🔥 5. Load Testing & Παρουσίαση Scaling

Για την προσομοίωση συνθηκών πραγματικού υψηλού φόρτου (π.χ. χιλιάδες ταυτόχρονοι φοιτητές που ψηφίζουν), χρησιμοποιήθηκε το εργαλείο **Apache Benchmark (ab)**:

```bash
ab -n 3000 -c 40 -p /dev/null -T "application/json" http://<wyr-app-ip>/api/vote
