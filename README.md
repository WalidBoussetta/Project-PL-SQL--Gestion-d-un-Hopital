#  Système de Gestion d'un Hôpital Intelligent — PL/SQL

> Projet avancé PL/SQL — MI2 2025/2026  
> Gestion complète d'un système hospitalier avec procédures stockées, curseurs, packages, collections, triggers et gestion des exceptions.

---

##  Description

Ce projet implémente une application complète en **PL/SQL (Oracle)** pour la gestion d'un hôpital intelligent. Il couvre l'ensemble des fonctionnalités avancées du langage PL/SQL à travers un schéma relationnel médical réaliste.

---

##  Schéma de la base de données

```
Patient          (idPatient PK, nom, prénom, dateNaissance, adresse, téléphone)
Medecin          (idMedecin PK, nom, spécialité, salaire, idService FK)
Service          (idService PK, nomService, capacité)
RendezVous       (idRdv PK, idPatient FK, idMedecin FK, dateRdv, statut)
Hospitalisation  (idHosp PK, idPatient FK, idService FK, dateEntree, dateSortie)
Medicament       (idMed PK, nom, stock, prix)
Prescription     (idPresc PK, idPatient FK, idMedecin FK, datePresc)
Ligne_Prescription (idPresc FK, idMed FK, quantité, PK(idPresc, idMed))
```

---

##  Structure du projet

```
 hopital-plsql/
├── 1000-complet.sql    -- Script principal : tables, CRUD, curseurs, fonctions,
│                          collections, exceptions, package (spec + body), triggers
├── 100-test.sql        -- Jeu de tests complet avec données de test
├── delete.sql          -- Script de suppression / remise à zéro des objets
└── README.md
```

---

##  Fonctionnalités implémentées

### 1. Création des tables & contraintes
Toutes les tables sont créées avec leurs clés primaires, clés étrangères et contraintes d'intégrité.

### 2. Opérations CRUD
- `ajouter_patient`, `modifier_patient`, `supprimer_patient`, `afficher_patient`
- `ajouter_medecin`, `modifier_medecin`, `supprimer_medecin`, `afficher_medecin`
- `ajouter_medicament`, `modifier_medicament`, `supprimer_medicament`, `afficher_medicament`
- `ajouter_rdv`, `modifier_rdv`, `supprimer_rdv`, `afficher_rdv`

### 3. Curseurs paramétrés
- `afficher_rdv_medecin(p_idMedecin)` — affiche les RDV d'un médecin avec nom patient et statut

### 4. Fonctions
- `nb_patients_service(p_idService)` — nombre de patients hospitalisés dans un service
- `total_medicaments_patient(p_idPatient)` — total des quantités prescrites à un patient
- `cout_prescription(p_idPresc)` — coût total d'une prescription

### 5. Procédures avec curseurs
- `liste_hospitalisations` — affiche toutes les hospitalisations avec durée de séjour calculée

### 6. Collections
- `medicaments_rupture` — identifie les médicaments avec stock = 0 via TABLE/VARRAY

### 7. Gestion des exceptions
| Type | Exceptions |
|------|-----------|
| Implicites | `NO_DATA_FOUND`, `TOO_MANY_ROWS`, `ZERO_DIVIDE` |
| Explicites | `ex_stock_insuffisant`, `ex_rdv_conflit`, `ex_capacite_depassee` |

### 8. Procédure métier complexe
- `prescrire_medicament` — vérifie le stock, insère la prescription, met à jour le stock

### 9. Package PL/SQL — `pkg_hopital`
- Spécification (spec) + Corps (body) regroupant toutes les procédures et fonctions

### 10. Triggers
| Trigger | Table | Événement | Rôle |
|---------|-------|-----------|------|
| `trg_check_rdv` | RENDEZVOUS | BEFORE INSERT | Vérifie les conflits de RDV |
| `trg_update_stock` | PRESCRIPTION | AFTER UPDATE | Mise à jour automatique du stock |
| `trg_ddl_log` | Schéma | CREATE/DROP/ALTER | Capture des opérations DDL |
| `trg_connexion` | Base de données | LOGON | Notification de connexion utilisateur |

### 11. Contraintes métier avancées
- Interdiction de double RDV pour un même médecin à la même date/heure
- Vérification de la capacité maximale des services
- Blocage des prescriptions si stock insuffisant
- Prévention de double hospitalisation simultanée d'un même patient

---

##  Instructions d'exécution

> **Prérequis :** Oracle Database 11g ou supérieur, SQL*Plus ou SQL Developer

**Activer l'affichage des sorties avant tout :**
```sql
SET SERVEROUTPUT ON;
```

**Ordre d'exécution recommandé :**

```sql
-- 1. Supprimer les anciens objets si besoin (remise à zéro)
@delete.sql

-- 2. Créer toutes les tables, procédures, fonctions, package et triggers
@1000-complet.sql

-- 3. Lancer les tests
@100-test.sql
```

---

##  Tests — `100-test.sql`

Le fichier de tests contient :
- ✅ Insertions de données de test pour toutes les tables
- ✅ Appels de toutes les procédures CRUD
- ✅ Appels des fonctions avec vérification des résultats
- ✅ Tests des cas d'erreurs et des exceptions personnalisées
- ✅ Vérification des triggers (DML, DDL, instance)

---

##  Remise à zéro — `delete.sql`

Ce script supprime tous les objets créés (tables, procédures, fonctions, package, triggers) pour permettre une réexécution propre du projet.

---

##  Gestion des erreurs

Toutes les procédures et fonctions incluent une gestion générique :
```sql
WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
```

---

Filière : MI2  
Année universitaire : 2025/2026  

---

## 📄 Licence

Projet académique — Usage éducatif uniquement.
