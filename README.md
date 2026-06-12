# Would You Rather? – Scalable Cloud Application

Αυτή η εφαρμογή υλοποιήθηκε στα πλαίσια του μαθήματος Cloud Computing. Πρόκειται για ένα data-driven microservices web application (βασισμένο σε real-world δεδομένα).

---

## 1. Το Dataset (Data Preparation)

Για τις ανάγκες της εφαρμογής χρησιμοποιήθηκε ένα πραγματικό dataset από το Kaggle:

[Kaggle Dataset: Would You Rather](https://www.kaggle.com/datasets/charlieray668/would-you-rather)

### Διαδικασία Επεξεργασίας (Data Cleaning)

Το αρχικό αρχείο ήταν σε μορφή `.csv` και περιείχε στήλες με έτοιμα στατιστικά ψήφων (`votes_a`, `votes_b`) τα οποία έπρεπε να αφαιρεθούν, καθώς η εφαρμογή υπολογίζει live τις δικές της ψηφοφορίες.

Με τη χρήση ενός Python Script (`pandas`), έγινε το ξεσκαρτάρισμα των δεδομένων:

1. Κρατήθηκαν αποκλειστικά οι στήλες `option_a` και `option_b`.
2. Αφαιρέθηκαν όλα τα περιττά metadata και οι παλιοί ψήφοι.
3. Τα δεδομένα μετατράπηκαν στην τελική μορφή `questions.json`, η οποία τροφοδοτείται αυτόματα στη βάση δεδομένων κατά την εκκίνηση του server.

---

## 2. Dockerization & Production Ready

Η εφαρμογή έχει πακεταριστεί πλήρως σε Docker Container ακολουθώντας αυστηρές προδιαγραφές ασφαλείας και βέλτιστες πρακτικές (multi-layer caching):

- **Base Image:** `python:3.12-slim` για ελαχιστοποίηση του μεγέθους του ειδώλου.
- **Security:** Χρήση non-root χρήστη (`appuser`) με απενεργοποιημένο shell (`nologin`) για μέγιστη ασφάλεια του host συστήματος.
- **WSGI Server:** Χρήση του `gunicorn` με 2 workers (αντί του ενσωματωμένου development server της Flask).
- **Βελτιστοποίηση:** Χρήση ειδικού `.dockerignore` για τον αποκλεισμό περιττών αρχείων (όπως `test_app.py`, `.venv`, κλπ.) ώστε να διατηρηθεί το είδωλο ελαφρύ και αποδοτικό.

### Οδηγίες Χρήσης (Docker)

**1. Δημιουργία (Build) της Docker εικόνας:**

```bash
docker build -t voting-app:v1 .
```

**2. Εκτέλεση (Run) του Docker Container:**

```bash
docker run -d -p 8080:8080 --name live-voting-app voting-app:v1
```

Η εφαρμογή είναι άμεσα διαθέσιμη στον browser στη διεύθυνση: `http://localhost:8080`

---

## 3. Automated Testing

Για τη διασφάλιση της ορθής λειτουργίας του κώδικα και των routes της Flask, έχουν υλοποιηθεί αυτοματοποιημένα unit tests.

- **Εργαλείο:** `pytest`

**Εκτέλεση Tests τοπικά:**

```bash
pytest
```
