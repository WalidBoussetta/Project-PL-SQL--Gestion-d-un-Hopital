-- walid boussetta -- feryal hmaidi

set serveroutput on;
BEGIN
    delete from Ligne_Prescription;
    delete from Prescription;
    delete from RendezVous;
    delete from Hospitalisation;
    delete from Medecin;
    delete from Patient;
    delete from Service;
    delete from Medicament;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Toutes les données ont été supprimées.');
END;
/

-- PARTIE 6 : TESTS COMPLETS
-- ============================================================

INSERT INTO Service(idService, nomService, capacite) VALUES (1, 'Cardiologie', 3);
INSERT INTO Service(idService, nomService, capacite) VALUES (2, 'Pédiatrie', 2);
INSERT INTO Service(idService, nomService, capacite) VALUES (3, 'Urgences', 5);

INSERT INTO Patient(idPatient, nom, prenom, dateNaissance, adresse, telephone)
VALUES (1, 'Ben Ali', 'Mohamed', TO_DATE('1985-03-15','YYYY-MM-DD'), 'Tunis', '21234567');
INSERT INTO Patient(idPatient, nom, prenom, dateNaissance, adresse, telephone)
VALUES (2, 'Trabelsi', 'Salma', TO_DATE('1990-07-20','YYYY-MM-DD'), 'Sfax', '22345678');
INSERT INTO Patient(idPatient, nom, prenom, dateNaissance, adresse, telephone)
VALUES (3, 'Mansouri', 'Karim', TO_DATE('2000-01-10','YYYY-MM-DD'), 'Sousse', '23456789');

INSERT INTO Medecin(idMedecin, nom, specialite, salaire, idService)
VALUES (1, 'Dr. Jebali', 'Cardiologie', 5000, 1);
INSERT INTO Medecin(idMedecin, nom, specialite, salaire, idService)
VALUES (2, 'Dr. Karray', 'Pédiatrie', 4500, 2);

INSERT INTO Medicament(idMed, nom, stock, prix) VALUES (1, 'Paracetamol', 100, 2.5);
INSERT INTO Medicament(idMed, nom, stock, prix) VALUES (2, 'Amoxicilline', 50, 5.0);
INSERT INTO Medicament(idMed, nom, stock, prix) VALUES (3, 'Ibuprofene', 0, 3.0);

INSERT INTO RendezVous(idRdv, idPatient, idMedecin, dateRdv, statut)
VALUES (1, 1, 1, TO_DATE('2026-05-10 09:00','YYYY-MM-DD HH24:MI'), 'planifié');
INSERT INTO RendezVous(idRdv, idPatient, idMedecin, dateRdv, statut)
VALUES (2, 2, 2, TO_DATE('2026-05-11 10:00','YYYY-MM-DD HH24:MI'), 'confirmé');

INSERT INTO Hospitalisation(idHosp, idPatient, idService, dateEntree, dateSortie)
VALUES (1, 1, 1, TO_DATE('2026-04-01','YYYY-MM-DD'), TO_DATE('2026-04-05','YYYY-MM-DD'));
INSERT INTO Hospitalisation(idHosp, idPatient, idService, dateEntree, dateSortie)
VALUES (2, 2, 2, TO_DATE('2026-04-10','YYYY-MM-DD'), NULL);

INSERT INTO Prescription(idPresc, idPatient, idMedecin, datePresc)
VALUES (1, 1, 1, TO_DATE('2026-04-01','YYYY-MM-DD'));
INSERT INTO Ligne_Prescription(idPresc, idMed, quantite) VALUES (1, 1, 10);
INSERT INTO Ligne_Prescription(idPresc, idMed, quantite) VALUES (1, 2, 5);
COMMIT;

BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Données de test insérées ===');
END;
/

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== TESTS CRUD PATIENT ======');
END;
/
EXEC pkg_hopital.afficher_patient(1);
/
EXEC pkg_hopital.ajouter_patient(10,'Gharbi','Amine',TO_DATE('1995-06-01','YYYY-MM-DD'),'Nabeul','24567890');
/
EXEC pkg_hopital.ajouter_patient(1,'X','X',SYSDATE,'X','00000000');
/
EXEC pkg_hopital.modifier_patient(10,'Gharbi','Amine M.',TO_DATE('1995-06-01','YYYY-MM-DD'),'Hammamet','24567890');
/
EXEC pkg_hopital.modifier_patient(99,'X','X',SYSDATE,'X','00000000');
/
EXEC pkg_hopital.supprimer_patient(10);
/
EXEC pkg_hopital.supprimer_patient(1);
/

-- Tests CRUD Médecin
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== TESTS CRUD MEDECIN ======');
END;
/
EXEC pkg_hopital.afficher_medecin(1);
/
EXEC pkg_hopital.ajouter_medecin(10,'Dr. Sassi','Neurologie',6000,3);
/
EXEC pkg_hopital.ajouter_medecin(11,'Dr. Test','ORL',-100,1);
/
EXEC pkg_hopital.supprimer_medecin(10);
/
EXEC pkg_hopital.supprimer_medecin(1);
/

-- Tests CRUD Médicament
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== TESTS CRUD MEDICAMENT ======');
END;
/
EXEC pkg_hopital.afficher_medicament(1);
/
EXEC pkg_hopital.ajouter_medicament(10,'Doliprane',200,1.5);
/
EXEC pkg_hopital.ajouter_medicament(11,'Test',-5,1.0);
/
EXEC pkg_hopital.supprimer_medicament(1);
/
EXEC pkg_hopital.supprimer_medicament(10);
/

-- Tests CRUD RendezVous
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== TESTS CRUD RENDEZVOUS ======');
END;
/
EXEC pkg_hopital.afficher_rendezvous(1);
/
EXEC pkg_hopital.ajouter_rendezvous(10,2,1,TO_DATE('2026-06-01 09:00','YYYY-MM-DD HH24:MI'),'planifié');
/
EXEC pkg_hopital.supprimer_rendezvous(10);
/

-- Tests Fonctions
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== TESTS FONCTIONS ======');
    DBMS_OUTPUT.PUT_LINE('nb_patients_service(1)      : ' || pkg_hopital.nb_patients_service(1));
    DBMS_OUTPUT.PUT_LINE('total_medicaments_patient(1): ' || pkg_hopital.total_medicaments_patient(1));
    DBMS_OUTPUT.PUT_LINE('cout_prescription(1)        : ' || pkg_hopital.cout_prescription(1));
    DBMS_OUTPUT.PUT_LINE('cout_prescription(99)       : ' || pkg_hopital.cout_prescription(99));
END;
/

-- Tests Curseur paramétré
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== TESTS CURSEUR PARAMÉTRÉ ======');
END;
/
EXEC pkg_hopital.afficher_rdv_medecin(1);
/
EXEC pkg_hopital.afficher_rdv_medecin(99);
/

-- Tests Hospitalisations
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== TESTS LISTE HOSPITALISATIONS ======');
END;
/
EXEC pkg_hopital.liste_hospitalisations;
/

-- Tests Collections
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== TESTS COLLECTIONS ======');
END;
/
EXEC pkg_hopital.medicaments_rupture;
/

-- Tests Procédure métier
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== TESTS PRESCRIRE MEDICAMENT ======');
END;
/
EXEC pkg_hopital.prescrire_medicament(10,1,1,SYSDATE,1,5);
/
EXEC pkg_hopital.prescrire_medicament(11,1,1,SYSDATE,3,10);
/
EXEC pkg_hopital.prescrire_medicament(12,99,1,SYSDATE,1,1);
/

-- Tests Gestion des exceptions
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== TESTS GESTION EXCEPTIONS ======');
END;
/
EXEC pkg_hopital.rechercher_patient(99);
/
EXEC pkg_hopital.rechercher_medecin_specialite('Cardiologie');
/
EXEC pkg_hopital.verifier_stock_et_diviser(1,0);
/
EXEC pkg_hopital.verifier_stock_et_diviser(3,1);
/
EXEC pkg_hopital.verifier_capacite_service(2);
/

-- Tests Triggers DML
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== TESTS TRIGGERS DML ======');
END;
/

-- Trigger RDV conflit
BEGIN
    INSERT INTO RendezVous(idRdv, idPatient, idMedecin, dateRdv, statut)
    VALUES (20, 3, 1, TO_DATE('2026-05-10 09:00','YYYY-MM-DD HH24:MI'), 'planifié');
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Trigger RDV conflit : ' || SQLERRM);
END;
/

-- Trigger update stock
BEGIN
    UPDATE Ligne_Prescription SET quantite = 15 WHERE idPresc = 1 AND idMed = 1;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Trigger stock : mise à jour effectuée.');
EXCEPTION
    WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Trigger stock : ' || SQLERRM);
END;
/

-- Trigger double hospitalisation
BEGIN
    INSERT INTO Hospitalisation(idHosp, idPatient, idService, dateEntree, dateSortie)
    VALUES (20, 2, 1, TO_DATE('2026-04-12','YYYY-MM-DD'), NULL);
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Trigger hosp : ' || SQLERRM);
END;
/