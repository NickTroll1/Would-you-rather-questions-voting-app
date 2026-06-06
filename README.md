# Would You Rather? - Scalable Cloud Application  

Αυτή η εφαρμογή υλοποιήθηκε στα πλαίσια του μαθήματος Cloud Computing. Πρόκειται για ένα data-driven microservices web application (βασισμένο σε real-world dataset) το οποίο είναι πλήρως **scalable** και έχει σχεδιαστεί για να εκτελείται μέσα σε ένα **Kubernetes (K8s)** cluster.

---

##  1. Το Dataset (Data Preparation)
Για τις ανάγκες της εφαρμογής χρησιμοποιήθηκε ένα πραγματικό dataset από το Kaggle:
 [Kaggle Dataset: Would You Rather](https://www.kaggle.com/datasets/charlieray668/would-you-rather)

### Διαδικασία Επεξεργασίας (Data Cleaning):
Το αρχικό αρχείο ήταν σε μορφή `.csv` και περιείχε στήλες με έτοιμα στατιστικά ψήφων (`votes_a`, `votes_b`) τα οποία έπρεπε να αφαιρεθούν, καθώς η εφαρμογή μας έπρεπε να ξεκινάει με μηδενικούς ψήφους για να καταγράφει τη δική της live δραστηριότητα.

Με τη χρήση ενός Python Script (`pandas`), έγινε το ξεσκαρτάρισμα των δεδομένων:
1. Κρατήθηκαν αποκλειστικά οι στήλες `option_a` και `option_b`.
2. Αφαιρέθηκαν όλα τα περιττά metadata και οι παλιοί ψήφοι.
3. Τα δεδομένα μετατράπηκαν στην τελική μορφή `questions.json`, η οποία τροφοδοτείται αυτόματα στη βάση δεδομένων κατά την εκκίνηση του server.

---
