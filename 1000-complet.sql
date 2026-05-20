-- walid boussetta -- feryal hmaidi

-- ============================================================
-- PARTIE 1 : CRÉATION DES TABLES
-- ============================================================

CREATE TABLE Service (
    idService   NUMBER PRIMARY KEY,
    nomService  VARCHAR2(100) NOT NULL,
    capacite    NUMBER        NOT NULL
);

CREATE TABLE Patient (
    idPatient     NUMBER PRIMARY KEY,
    nom           VARCHAR2(100) NOT NULL,
    prenom        VARCHAR2(100) NOT NULL,
    dateNaissance DATE          NOT NULL,
    adresse       VARCHAR2(200),
    telephone     VARCHAR2(20)  NOT NULL
);

CREATE TABLE Medecin (
    idMedecin   NUMBER PRIMARY KEY,
    nom         VARCHAR2(100) NOT NULL,
    specialite  VARCHAR2(100) NOT NULL,
    salaire     NUMBER        NOT NULL,
    idService   NUMBER        NOT NULL,
    CONSTRAINT fk_medecin_service FOREIGN KEY (idService) REFERENCES Service(idService)
);

CREATE TABLE Medicament (
    idMed  NUMBER PRIMARY KEY,
    nom    VARCHAR2(100) NOT NULL,
    stock  NUMBER        NOT NULL,
    prix   NUMBER        NOT NULL
);

CREATE TABLE RendezVous (
    idRdv      NUMBER PRIMARY KEY,
    idPatient  NUMBER       NOT NULL,
    idMedecin  NUMBER       NOT NULL,
    dateRdv    DATE         NOT NULL,
    statut     VARCHAR2(20) NOT NULL,
    CONSTRAINT fk_rdv_patient FOREIGN KEY (idPatient) REFERENCES Patient(idPatient),
    CONSTRAINT fk_rdv_medecin FOREIGN KEY (idMedecin) REFERENCES Medecin(idMedecin)
);

CREATE TABLE Hospitalisation (
    idHosp      NUMBER PRIMARY KEY,
    idPatient   NUMBER NOT NULL,
    idService   NUMBER NOT NULL,
    dateEntree  DATE   NOT NULL,
    dateSortie  DATE,
    CONSTRAINT fk_hosp_patient FOREIGN KEY (idPatient) REFERENCES Patient(idPatient),
    CONSTRAINT fk_hosp_service FOREIGN KEY (idService) REFERENCES Service(idService)
);

CREATE TABLE Prescription (
    idPresc    NUMBER PRIMARY KEY,
    idPatient  NUMBER NOT NULL,
    idMedecin  NUMBER NOT NULL,
    datePresc  DATE   NOT NULL,
    CONSTRAINT fk_presc_patient FOREIGN KEY (idPatient) REFERENCES Patient(idPatient),
    CONSTRAINT fk_presc_medecin FOREIGN KEY (idMedecin) REFERENCES Medecin(idMedecin)
);

CREATE TABLE Ligne_Prescription (
    idPresc    NUMBER NOT NULL,
    idMed      NUMBER NOT NULL,
    quantite   NUMBER NOT NULL,
    CONSTRAINT pk_ligne_presc PRIMARY KEY (idPresc, idMed),
    CONSTRAINT fk_lp_presc FOREIGN KEY (idPresc) REFERENCES Prescription(idPresc),
    CONSTRAINT fk_lp_med   FOREIGN KEY (idMed)   REFERENCES Medicament(idMed)
);

-- ============================================================
-- PARTIE 2 : TYPES POUR COLLECTIONS
-- ============================================================

CREATE OR REPLACE TYPE t_medicament AS OBJECT (
    idMed  NUMBER,
    nom    VARCHAR2(100),
    stock  NUMBER
);
/

CREATE OR REPLACE TYPE t_liste_medicaments AS TABLE OF t_medicament;
/


-- ============================================================
-- PARTIE 3 : TRIGGERS
-- ============================================================

-- Trigger DML 1 : BEFORE INSERT sur RendezVous
CREATE OR REPLACE TRIGGER trg_before_insert_rdv
BEFORE INSERT ON RendezVous
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM RendezVous
    WHERE idMedecin = :NEW.idMedecin
      AND dateRdv   = :NEW.dateRdv
      AND statut   != 'annulé';
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20070,
            'Erreur : Le médecin ' || :NEW.idMedecin ||
            ' a déjà un rendez-vous le ' || TO_CHAR(:NEW.dateRdv, 'DD/MM/YYYY HH24:MI'));
    END IF;
END;
/

-- Trigger DML 2 : AFTER UPDATE sur Ligne_Prescription
CREATE OR REPLACE TRIGGER trg_after_update_prescription
AFTER UPDATE ON Ligne_Prescription
FOR EACH ROW
DECLARE
    v_stock NUMBER;
    v_diff  NUMBER;
BEGIN
    v_diff := :NEW.quantite - :OLD.quantite;
    SELECT stock INTO v_stock FROM Medicament WHERE idMed = :NEW.idMed;
    IF v_stock - v_diff < 0 THEN
        RAISE_APPLICATION_ERROR(-20071,
            'Erreur : Stock insuffisant pour le médicament ' || :NEW.idMed ||
            '. Disponible : ' || v_stock || ', demandé : ' || v_diff);
    END IF;
    UPDATE Medicament SET stock = stock - v_diff WHERE idMed = :NEW.idMed;
END;
/

-- Trigger DML 3 : BEFORE INSERT sur Hospitalisation
CREATE OR REPLACE TRIGGER trg_before_insert_hospitalisation
BEFORE INSERT ON Hospitalisation
FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM Hospitalisation
    WHERE idPatient = :NEW.idPatient
      AND (
            (dateSortie IS NULL AND :NEW.dateEntree >= dateEntree)
            OR (:NEW.dateEntree BETWEEN dateEntree AND dateSortie)
            OR (:NEW.dateSortie IS NOT NULL AND dateEntree BETWEEN :NEW.dateEntree AND :NEW.dateSortie)
          );
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20080,
            'Erreur : Le patient ' || :NEW.idPatient ||
            ' est déjà hospitalisé sur cette période.');
    END IF;
END;
/

-- Trigger DDL : Capture CREATE, DROP, ALTER
CREATE OR REPLACE TRIGGER trg_ddl_audit
AFTER CREATE or DROP or ALTER ON SCHEMA
DECLARE
    v_operation VARCHAR2(30);
    v_objet     VARCHAR2(100);
    v_type      VARCHAR2(50);
BEGIN
    v_operation := ORA_SYSEVENT;
    v_objet     := ORA_DICT_OBJ_NAME;
    v_type      := ORA_DICT_OBJ_TYPE;
    DBMS_OUTPUT.PUT_LINE('=== Opération DDL ===');
    DBMS_OUTPUT.PUT_LINE('Opération : ' || v_operation);
    DBMS_OUTPUT.PUT_LINE('Objet     : ' || v_objet);
    DBMS_OUTPUT.PUT_LINE('Type      : ' || v_type);
    DBMS_OUTPUT.PUT_LINE('Date      : ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
END;
/

-- Trigger d'instance : Connexion utilisateur
CREATE OR REPLACE TRIGGER trg_connexion_utilisateur
AFTER LOGON ON DATABASE
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== Nouvelle connexion ===');
    DBMS_OUTPUT.PUT_LINE('Utilisateur : ' || SYS_CONTEXT('USERENV', 'SESSION_USER'));
    DBMS_OUTPUT.PUT_LINE('Date        : ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('Hôte        : ' || SYS_CONTEXT('USERENV', 'HOST'));
END;
/


-- ============================================================
-- PARTIE 4 : PACKAGE - SPÉCIFICATION
-- ============================================================

CREATE OR REPLACE PACKAGE pkg_hopital AS

    -- --------------------------------------------------------
    -- CRUD PATIENT
    -- --------------------------------------------------------
    PROCEDURE ajouter_patient(
        p_idPatient     IN Patient.idPatient%TYPE,
        p_nom           IN Patient.nom%TYPE,
        p_prenom        IN Patient.prenom%TYPE,
        p_dateNaissance IN Patient.dateNaissance%TYPE,
        p_adresse       IN Patient.adresse%TYPE,
        p_telephone     IN Patient.telephone%TYPE
    );
    PROCEDURE modifier_patient(
        p_idPatient     IN Patient.idPatient%TYPE,
        p_nom           IN Patient.nom%TYPE,
        p_prenom        IN Patient.prenom%TYPE,
        p_dateNaissance IN Patient.dateNaissance%TYPE,
        p_adresse       IN Patient.adresse%TYPE,
        p_telephone     IN Patient.telephone%TYPE
    );
    PROCEDURE supprimer_patient(p_idPatient IN Patient.idPatient%TYPE);
    PROCEDURE afficher_patient(p_idPatient IN Patient.idPatient%TYPE);

    -- --------------------------------------------------------
    -- CRUD MEDECIN
    -- --------------------------------------------------------
    PROCEDURE ajouter_medecin(
        p_idMedecin  IN Medecin.idMedecin%TYPE,
        p_nom        IN Medecin.nom%TYPE,
        p_specialite IN Medecin.specialite%TYPE,
        p_salaire    IN Medecin.salaire%TYPE,
        p_idService  IN Medecin.idService%TYPE
    );
    PROCEDURE modifier_medecin(
        p_idMedecin  IN Medecin.idMedecin%TYPE,
        p_nom        IN Medecin.nom%TYPE,
        p_specialite IN Medecin.specialite%TYPE,
        p_salaire    IN Medecin.salaire%TYPE,
        p_idService  IN Medecin.idService%TYPE
    );
    PROCEDURE supprimer_medecin(p_idMedecin IN Medecin.idMedecin%TYPE);
    PROCEDURE afficher_medecin(p_idMedecin IN Medecin.idMedecin%TYPE);

    -- --------------------------------------------------------
    -- CRUD MEDICAMENT
    -- --------------------------------------------------------
    PROCEDURE ajouter_medicament(
        p_idMed IN Medicament.idMed%TYPE,
        p_nom   IN Medicament.nom%TYPE,
        p_stock IN Medicament.stock%TYPE,
        p_prix  IN Medicament.prix%TYPE
    );
    PROCEDURE modifier_medicament(
        p_idMed IN Medicament.idMed%TYPE,
        p_nom   IN Medicament.nom%TYPE,
        p_stock IN Medicament.stock%TYPE,
        p_prix  IN Medicament.prix%TYPE
    );
    PROCEDURE supprimer_medicament(p_idMed IN Medicament.idMed%TYPE);
    PROCEDURE afficher_medicament(p_idMed IN Medicament.idMed%TYPE);

    -- --------------------------------------------------------
    -- CRUD RENDEZVOUS
    -- --------------------------------------------------------
    PROCEDURE ajouter_rendezvous(
        p_idRdv     IN RendezVous.idRdv%TYPE,
        p_idPatient IN RendezVous.idPatient%TYPE,
        p_idMedecin IN RendezVous.idMedecin%TYPE,
        p_dateRdv   IN RendezVous.dateRdv%TYPE,
        p_statut    IN RendezVous.statut%TYPE
    );
    PROCEDURE modifier_rendezvous(
        p_idRdv     IN RendezVous.idRdv%TYPE,
        p_idPatient IN RendezVous.idPatient%TYPE,
        p_idMedecin IN RendezVous.idMedecin%TYPE,
        p_dateRdv   IN RendezVous.dateRdv%TYPE,
        p_statut    IN RendezVous.statut%TYPE
    );
    PROCEDURE supprimer_rendezvous(p_idRdv IN RendezVous.idRdv%TYPE);
    PROCEDURE afficher_rendezvous(p_idRdv IN RendezVous.idRdv%TYPE);

    -- --------------------------------------------------------
    -- FONCTIONS
    -- --------------------------------------------------------
    FUNCTION nb_patients_service(p_idService IN Service.idService%TYPE) RETURN NUMBER;
    FUNCTION total_medicaments_patient(p_idPatient IN Patient.idPatient%TYPE) RETURN NUMBER;
    FUNCTION cout_prescription(p_idPresc IN Prescription.idPresc%TYPE) RETURN NUMBER;

    -- --------------------------------------------------------
    -- CURSEUR PARAMÉTRÉ
    -- --------------------------------------------------------
    PROCEDURE afficher_rdv_medecin(p_idMedecin IN Medecin.idMedecin%TYPE);

    -- --------------------------------------------------------
    -- PROCÉDURE AVEC CURSEUR - Hospitalisations
    -- --------------------------------------------------------
    PROCEDURE liste_hospitalisations;

    -- --------------------------------------------------------
    -- COLLECTIONS - Médicaments en rupture
    -- --------------------------------------------------------
    PROCEDURE medicaments_rupture;

    -- --------------------------------------------------------
    -- GESTION DES EXCEPTIONS
    -- --------------------------------------------------------
    PROCEDURE rechercher_patient(p_idPatient IN Patient.idPatient%TYPE);
    PROCEDURE rechercher_medecin_specialite(p_specialite IN Medecin.specialite%TYPE);
    PROCEDURE verifier_stock_et_diviser(p_idMed IN NUMBER, p_diviseur IN NUMBER);

    -- --------------------------------------------------------
    -- PROCÉDURE MÉTIER COMPLEXE
    -- --------------------------------------------------------
    PROCEDURE prescrire_medicament(
        p_idPresc   IN Prescription.idPresc%TYPE,
        p_idPatient IN Prescription.idPatient%TYPE,
        p_idMedecin IN Prescription.idMedecin%TYPE,
        p_datePresc IN Prescription.datePresc%TYPE,
        p_idMed     IN Ligne_Prescription.idMed%TYPE,
        p_quantite  IN Ligne_Prescription.quantite%TYPE
    );

    -- --------------------------------------------------------
    -- CONTRAINTES MÉTIER AVANCÉES
    -- --------------------------------------------------------
    PROCEDURE verifier_capacite_service(p_idService IN Service.idService%TYPE);

END pkg_hopital;
/


-- ============================================================
-- PARTIE 5 : PACKAGE - BODY
-- ============================================================

CREATE OR REPLACE PACKAGE BODY pkg_hopital AS

    -- --------------------------------------------------------
    -- CRUD PATIENT
    -- --------------------------------------------------------
    PROCEDURE ajouter_patient(
        p_idPatient     IN Patient.idPatient%TYPE,
        p_nom           IN Patient.nom%TYPE,
        p_prenom        IN Patient.prenom%TYPE,
        p_dateNaissance IN Patient.dateNaissance%TYPE,
        p_adresse       IN Patient.adresse%TYPE,
        p_telephone     IN Patient.telephone%TYPE
    ) AS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Patient WHERE idPatient = p_idPatient;
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Erreur : Un patient avec cet identifiant existe déjà.');
        END IF;
        IF p_telephone IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'Erreur : Le téléphone est obligatoire.');
        END IF;
        INSERT INTO Patient(idPatient, nom, prenom, dateNaissance, adresse, telephone)
        VALUES (p_idPatient, p_nom, p_prenom, p_dateNaissance, p_adresse, p_telephone);
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Patient ajouté avec succès. ID : ' || p_idPatient);
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END ajouter_patient;

    PROCEDURE modifier_patient(
        p_idPatient     IN Patient.idPatient%TYPE,
        p_nom           IN Patient.nom%TYPE,
        p_prenom        IN Patient.prenom%TYPE,
        p_dateNaissance IN Patient.dateNaissance%TYPE,
        p_adresse       IN Patient.adresse%TYPE,
        p_telephone     IN Patient.telephone%TYPE
    ) AS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Patient WHERE idPatient = p_idPatient;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Erreur : Aucun patient trouvé avec l''identifiant ' || p_idPatient);
        END IF;
        UPDATE Patient
        SET nom = p_nom, prenom = p_prenom, dateNaissance = p_dateNaissance,
            adresse = p_adresse, telephone = p_telephone
        WHERE idPatient = p_idPatient;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Patient modifié avec succès. ID : ' || p_idPatient);
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END modifier_patient;

    PROCEDURE supprimer_patient(p_idPatient IN Patient.idPatient%TYPE) AS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Patient WHERE idPatient = p_idPatient;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Erreur : Aucun patient trouvé avec l''identifiant ' || p_idPatient);
        END IF;
        SELECT COUNT(*) INTO v_count FROM RendezVous WHERE idPatient = p_idPatient;
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20005, 'Erreur : Suppression impossible, le patient a des rendez-vous.');
        END IF;
        DELETE FROM Patient WHERE idPatient = p_idPatient;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Patient supprimé avec succès. ID : ' || p_idPatient);
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END supprimer_patient;

    PROCEDURE afficher_patient(p_idPatient IN Patient.idPatient%TYPE) AS
        v_patient Patient%ROWTYPE;
    BEGIN
        SELECT * INTO v_patient FROM Patient WHERE idPatient = p_idPatient;
        DBMS_OUTPUT.PUT_LINE('--- Patient ---');
        DBMS_OUTPUT.PUT_LINE('ID       : ' || v_patient.idPatient);
        DBMS_OUTPUT.PUT_LINE('Nom      : ' || v_patient.nom);
        DBMS_OUTPUT.PUT_LINE('Prénom   : ' || v_patient.prenom);
        DBMS_OUTPUT.PUT_LINE('Naissance: ' || TO_CHAR(v_patient.dateNaissance, 'DD/MM/YYYY'));
        DBMS_OUTPUT.PUT_LINE('Adresse  : ' || v_patient.adresse);
        DBMS_OUTPUT.PUT_LINE('Téléphone: ' || v_patient.telephone);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN DBMS_OUTPUT.PUT_LINE('Erreur : Aucun patient trouvé avec l''identifiant ' || p_idPatient);
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END afficher_patient;

    -- --------------------------------------------------------
    -- CRUD MEDECIN
    -- --------------------------------------------------------
    PROCEDURE ajouter_medecin(
        p_idMedecin  IN Medecin.idMedecin%TYPE,
        p_nom        IN Medecin.nom%TYPE,
        p_specialite IN Medecin.specialite%TYPE,
        p_salaire    IN Medecin.salaire%TYPE,
        p_idService  IN Medecin.idService%TYPE
    ) AS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Medecin WHERE idMedecin = p_idMedecin;
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Erreur : Un médecin avec cet identifiant existe déjà.');
        END IF;
        SELECT COUNT(*) INTO v_count FROM Service WHERE idService = p_idService;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20011, 'Erreur : Le service spécifié n''existe pas.');
        END IF;
        IF p_salaire <= 0 THEN
            RAISE_APPLICATION_ERROR(-20012, 'Erreur : Le salaire doit être positif.');
        END IF;
        INSERT INTO Medecin(idMedecin, nom, specialite, salaire, idService)
        VALUES (p_idMedecin, p_nom, p_specialite, p_salaire, p_idService);
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Médecin ajouté avec succès. ID : ' || p_idMedecin);
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END ajouter_medecin;

    PROCEDURE modifier_medecin(
        p_idMedecin  IN Medecin.idMedecin%TYPE,
        p_nom        IN Medecin.nom%TYPE,
        p_specialite IN Medecin.specialite%TYPE,
        p_salaire    IN Medecin.salaire%TYPE,
        p_idService  IN Medecin.idService%TYPE
    ) AS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Medecin WHERE idMedecin = p_idMedecin;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Erreur : Aucun médecin trouvé avec l''identifiant ' || p_idMedecin);
        END IF;
        IF p_salaire <= 0 THEN
            RAISE_APPLICATION_ERROR(-20012, 'Erreur : Le salaire doit être positif.');
        END IF;
        UPDATE Medecin
        SET nom = p_nom, specialite = p_specialite, salaire = p_salaire, idService = p_idService
        WHERE idMedecin = p_idMedecin;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Médecin modifié avec succès. ID : ' || p_idMedecin);
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END modifier_medecin;

    PROCEDURE supprimer_medecin(p_idMedecin IN Medecin.idMedecin%TYPE) AS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Medecin WHERE idMedecin = p_idMedecin;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Erreur : Aucun médecin trouvé avec l''identifiant ' || p_idMedecin);
        END IF;
        SELECT COUNT(*) INTO v_count FROM RendezVous WHERE idMedecin = p_idMedecin;
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20015, 'Erreur : Suppression impossible, le médecin a des rendez-vous.');
        END IF;
        DELETE FROM Medecin WHERE idMedecin = p_idMedecin;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Médecin supprimé avec succès. ID : ' || p_idMedecin);
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END supprimer_medecin;

    PROCEDURE afficher_medecin(p_idMedecin IN Medecin.idMedecin%TYPE) AS
        v_medecin Medecin%ROWTYPE;
    BEGIN
        SELECT * INTO v_medecin FROM Medecin WHERE idMedecin = p_idMedecin;
        DBMS_OUTPUT.PUT_LINE('--- Médecin ---');
        DBMS_OUTPUT.PUT_LINE('ID         : ' || v_medecin.idMedecin);
        DBMS_OUTPUT.PUT_LINE('Nom        : ' || v_medecin.nom);
        DBMS_OUTPUT.PUT_LINE('Spécialité : ' || v_medecin.specialite);
        DBMS_OUTPUT.PUT_LINE('Salaire    : ' || v_medecin.salaire);
        DBMS_OUTPUT.PUT_LINE('ID Service : ' || v_medecin.idService);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN DBMS_OUTPUT.PUT_LINE('Erreur : Aucun médecin trouvé avec l''identifiant ' || p_idMedecin);
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END afficher_medecin;

    -- --------------------------------------------------------
    -- CRUD MEDICAMENT
    -- --------------------------------------------------------
    PROCEDURE ajouter_medicament(
        p_idMed IN Medicament.idMed%TYPE,
        p_nom   IN Medicament.nom%TYPE,
        p_stock IN Medicament.stock%TYPE,
        p_prix  IN Medicament.prix%TYPE
    ) AS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Medicament WHERE idMed = p_idMed;
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20020, 'Erreur : Un médicament avec cet identifiant existe déjà.');
        END IF;
        IF p_stock < 0 THEN
            RAISE_APPLICATION_ERROR(-20021, 'Erreur : Le stock ne peut pas être négatif.');
        END IF;
        IF p_prix <= 0 THEN
            RAISE_APPLICATION_ERROR(-20022, 'Erreur : Le prix doit être positif.');
        END IF;
        INSERT INTO Medicament(idMed, nom, stock, prix) VALUES (p_idMed, p_nom, p_stock, p_prix);
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Médicament ajouté avec succès. ID : ' || p_idMed);
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END ajouter_medicament;

    PROCEDURE modifier_medicament(
        p_idMed IN Medicament.idMed%TYPE,
        p_nom   IN Medicament.nom%TYPE,
        p_stock IN Medicament.stock%TYPE,
        p_prix  IN Medicament.prix%TYPE
    ) AS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Medicament WHERE idMed = p_idMed;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20023, 'Erreur : Aucun médicament trouvé avec l''identifiant ' || p_idMed);
        END IF;
        IF p_stock < 0 THEN
            RAISE_APPLICATION_ERROR(-20021, 'Erreur : Le stock ne peut pas être négatif.');
        END IF;
        IF p_prix <= 0 THEN
            RAISE_APPLICATION_ERROR(-20022, 'Erreur : Le prix doit être positif.');
        END IF;
        UPDATE Medicament SET nom = p_nom, stock = p_stock, prix = p_prix WHERE idMed = p_idMed;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Médicament modifié avec succès. ID : ' || p_idMed);
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END modifier_medicament;

    PROCEDURE supprimer_medicament(p_idMed IN Medicament.idMed%TYPE) AS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Medicament WHERE idMed = p_idMed;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20024, 'Erreur : Aucun médicament trouvé avec l''identifiant ' || p_idMed);
        END IF;
        SELECT COUNT(*) INTO v_count FROM Ligne_Prescription WHERE idMed = p_idMed;
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20025, 'Erreur : Suppression impossible, médicament utilisé dans des prescriptions.');
        END IF;
        DELETE FROM Medicament WHERE idMed = p_idMed;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Médicament supprimé avec succès. ID : ' || p_idMed);
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END supprimer_medicament;

    PROCEDURE afficher_medicament(p_idMed IN Medicament.idMed%TYPE) AS
        v_med Medicament%ROWTYPE;
    BEGIN
        SELECT * INTO v_med FROM Medicament WHERE idMed = p_idMed;
        DBMS_OUTPUT.PUT_LINE('--- Médicament ---');
        DBMS_OUTPUT.PUT_LINE('ID    : ' || v_med.idMed);
        DBMS_OUTPUT.PUT_LINE('Nom   : ' || v_med.nom);
        DBMS_OUTPUT.PUT_LINE('Stock : ' || v_med.stock);
        DBMS_OUTPUT.PUT_LINE('Prix  : ' || v_med.prix);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN DBMS_OUTPUT.PUT_LINE('Erreur : Aucun médicament trouvé avec l''identifiant ' || p_idMed);
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END afficher_medicament;

    -- --------------------------------------------------------
    -- CRUD RENDEZVOUS
    -- --------------------------------------------------------
    PROCEDURE ajouter_rendezvous(
        p_idRdv     IN RendezVous.idRdv%TYPE,
        p_idPatient IN RendezVous.idPatient%TYPE,
        p_idMedecin IN RendezVous.idMedecin%TYPE,
        p_dateRdv   IN RendezVous.dateRdv%TYPE,
        p_statut    IN RendezVous.statut%TYPE
    ) AS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM RendezVous WHERE idRdv = p_idRdv;
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20030, 'Erreur : Un rendez-vous avec cet identifiant existe déjà.');
        END IF;
        SELECT COUNT(*) INTO v_count FROM Patient WHERE idPatient = p_idPatient;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20031, 'Erreur : Le patient spécifié n''existe pas.');
        END IF;
        SELECT COUNT(*) INTO v_count FROM Medecin WHERE idMedecin = p_idMedecin;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20032, 'Erreur : Le médecin spécifié n''existe pas.');
        END IF;
        IF p_statut NOT IN ('planifié', 'confirmé', 'annulé', 'effectué') THEN
            RAISE_APPLICATION_ERROR(-20034, 'Erreur : Statut invalide.');
        END IF;
        INSERT INTO RendezVous(idRdv, idPatient, idMedecin, dateRdv, statut)
        VALUES (p_idRdv, p_idPatient, p_idMedecin, p_dateRdv, p_statut);
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Rendez-vous ajouté avec succès. ID : ' || p_idRdv);
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END ajouter_rendezvous;

    PROCEDURE modifier_rendezvous(
        p_idRdv     IN RendezVous.idRdv%TYPE,
        p_idPatient IN RendezVous.idPatient%TYPE,
        p_idMedecin IN RendezVous.idMedecin%TYPE,
        p_dateRdv   IN RendezVous.dateRdv%TYPE,
        p_statut    IN RendezVous.statut%TYPE
    ) AS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM RendezVous WHERE idRdv = p_idRdv;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20035, 'Erreur : Aucun rendez-vous trouvé avec l''identifiant ' || p_idRdv);
        END IF;
        IF p_statut NOT IN ('planifié', 'confirmé', 'annulé', 'effectué') THEN
            RAISE_APPLICATION_ERROR(-20034, 'Erreur : Statut invalide.');
        END IF;
        UPDATE RendezVous
        SET idPatient = p_idPatient, idMedecin = p_idMedecin,
            dateRdv = p_dateRdv, statut = p_statut
        WHERE idRdv = p_idRdv;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Rendez-vous modifié avec succès. ID : ' || p_idRdv);
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END modifier_rendezvous;

    PROCEDURE supprimer_rendezvous(p_idRdv IN RendezVous.idRdv%TYPE) AS
        v_count  NUMBER;
        v_statut RendezVous.statut%TYPE;
    BEGIN
        SELECT COUNT(*), MAX(statut) INTO v_count, v_statut FROM RendezVous WHERE idRdv = p_idRdv;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20036, 'Erreur : Aucun rendez-vous trouvé avec l''identifiant ' || p_idRdv);
        END IF;
        IF v_statut = 'effectué' THEN
            RAISE_APPLICATION_ERROR(-20037, 'Erreur : Suppression impossible, rendez-vous déjà effectué.');
        END IF;
        DELETE FROM RendezVous WHERE idRdv = p_idRdv;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Rendez-vous supprimé avec succès. ID : ' || p_idRdv);
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END supprimer_rendezvous;

    PROCEDURE afficher_rendezvous(p_idRdv IN RendezVous.idRdv%TYPE) AS
        v_rdv RendezVous%ROWTYPE;
    BEGIN
        SELECT * INTO v_rdv FROM RendezVous WHERE idRdv = p_idRdv;
        DBMS_OUTPUT.PUT_LINE('--- Rendez-Vous ---');
        DBMS_OUTPUT.PUT_LINE('ID RDV     : ' || v_rdv.idRdv);
        DBMS_OUTPUT.PUT_LINE('ID Patient : ' || v_rdv.idPatient);
        DBMS_OUTPUT.PUT_LINE('ID Médecin : ' || v_rdv.idMedecin);
        DBMS_OUTPUT.PUT_LINE('Date RDV   : ' || TO_CHAR(v_rdv.dateRdv, 'DD/MM/YYYY HH24:MI'));
        DBMS_OUTPUT.PUT_LINE('Statut     : ' || v_rdv.statut);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN DBMS_OUTPUT.PUT_LINE('Erreur : Aucun rendez-vous trouvé avec l''identifiant ' || p_idRdv);
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END afficher_rendezvous;

    -- --------------------------------------------------------
    -- FONCTIONS
    -- --------------------------------------------------------
    FUNCTION nb_patients_service(p_idService IN Service.idService%TYPE) RETURN NUMBER AS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Hospitalisation WHERE idService = p_idService;
        RETURN v_count;
    EXCEPTION
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM); RETURN -1;
    END nb_patients_service;

    FUNCTION total_medicaments_patient(p_idPatient IN Patient.idPatient%TYPE) RETURN NUMBER AS
        v_total NUMBER;
    BEGIN
        SELECT SUM(lp.quantite) INTO v_total
        FROM Ligne_Prescription lp
        JOIN Prescription p ON lp.idPresc = p.idPresc
        WHERE p.idPatient = p_idPatient;
        RETURN NVL(v_total, 0);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 0;
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM); RETURN -1;
    END total_medicaments_patient;

    FUNCTION cout_prescription(p_idPresc IN Prescription.idPresc%TYPE) RETURN NUMBER AS
        v_cout NUMBER;
    BEGIN
        SELECT SUM(lp.quantite * m.prix) INTO v_cout
        FROM Ligne_Prescription lp
        JOIN Medicament m ON lp.idMed = m.idMed
        WHERE lp.idPresc = p_idPresc;
        IF v_cout IS NULL THEN
            RAISE_APPLICATION_ERROR(-20050, 'Aucune ligne trouvée pour la prescription ' || p_idPresc);
        END IF;
        RETURN v_cout;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 0;
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM); RETURN -1;
    END cout_prescription;

    -- --------------------------------------------------------
    -- CURSEUR PARAMÉTRÉ
    -- --------------------------------------------------------
    PROCEDURE afficher_rdv_medecin(p_idMedecin IN Medecin.idMedecin%TYPE) AS
        CURSOR c_rdv(c_idMedecin Medecin.idMedecin%TYPE) IS
            SELECT r.idRdv, r.dateRdv, r.statut,
                   p.nom AS nomPatient, p.prenom AS prenomPatient
            FROM RendezVous r
            JOIN Patient p ON r.idPatient = p.idPatient
            WHERE r.idMedecin = c_idMedecin
            ORDER BY r.dateRdv;
        v_count NUMBER := 0;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Medecin WHERE idMedecin = p_idMedecin;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20040, 'Erreur : Aucun médecin trouvé avec l''identifiant ' || p_idMedecin);
        END IF;
        v_count := 0;
        DBMS_OUTPUT.PUT_LINE('=== Rendez-vous du médecin ID : ' || p_idMedecin || ' ===');
        FOR rec IN c_rdv(p_idMedecin) LOOP
            v_count := v_count + 1;
            DBMS_OUTPUT.PUT_LINE('----------------------------------');
            DBMS_OUTPUT.PUT_LINE('RDV N°  : ' || rec.idRdv);
            DBMS_OUTPUT.PUT_LINE('Date    : ' || TO_CHAR(rec.dateRdv, 'DD/MM/YYYY HH24:MI'));
            DBMS_OUTPUT.PUT_LINE('Patient : ' || rec.nomPatient || ' ' || rec.prenomPatient);
            DBMS_OUTPUT.PUT_LINE('Statut  : ' || rec.statut);
        END LOOP;
        IF v_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Aucun rendez-vous trouvé pour ce médecin.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('----------------------------------');
            DBMS_OUTPUT.PUT_LINE('Total : ' || v_count || ' rendez-vous.');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END afficher_rdv_medecin;

    -- --------------------------------------------------------
    -- PROCÉDURE AVEC CURSEUR - Hospitalisations
    -- --------------------------------------------------------
    PROCEDURE liste_hospitalisations AS
        CURSOR c_hosp IS
            SELECT h.idHosp,
                   p.nom AS nomPatient, p.prenom AS prenomPatient,
                   s.nomService, h.dateEntree, h.dateSortie,
                   (CASE
                        WHEN h.dateSortie IS NOT NULL THEN h.dateSortie - h.dateEntree
                        ELSE SYSDATE - h.dateEntree
                   END) AS dureeJours
            FROM Hospitalisation h
            JOIN Patient p ON h.idPatient = p.idPatient
            JOIN Service s ON h.idService = s.idService
            ORDER BY h.dateEntree;
        v_count NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('       LISTE DES HOSPITALISATIONS       ');
        DBMS_OUTPUT.PUT_LINE('========================================');
        FOR rec IN c_hosp LOOP
            v_count := v_count + 1;
            DBMS_OUTPUT.PUT_LINE('------------------------------------------');
            DBMS_OUTPUT.PUT_LINE('ID Hosp  : ' || rec.idHosp);
            DBMS_OUTPUT.PUT_LINE('Patient  : ' || rec.nomPatient || ' ' || rec.prenomPatient);
            DBMS_OUTPUT.PUT_LINE('Service  : ' || rec.nomService);
            DBMS_OUTPUT.PUT_LINE('Entrée   : ' || TO_CHAR(rec.dateEntree, 'DD/MM/YYYY'));
            DBMS_OUTPUT.PUT_LINE('Sortie   : ' || NVL(TO_CHAR(rec.dateSortie, 'DD/MM/YYYY'), 'En cours'));
            DBMS_OUTPUT.PUT_LINE('Durée    : ' || ROUND(rec.dureeJours) || ' jour(s)');
        END LOOP;
        IF v_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Aucune hospitalisation enregistrée.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('------------------------------------------');
            DBMS_OUTPUT.PUT_LINE('Total : ' || v_count || ' hospitalisation(s).');
        END IF;
        DBMS_OUTPUT.PUT_LINE('========================================');
    EXCEPTION
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END liste_hospitalisations;

    -- --------------------------------------------------------
    -- COLLECTIONS - Médicaments en rupture
    -- --------------------------------------------------------
    PROCEDURE medicaments_rupture AS
        v_liste  t_liste_medicaments := t_liste_medicaments();
        v_index  NUMBER := 0;
    BEGIN
        FOR rec IN (SELECT idMed, nom, stock FROM Medicament WHERE stock = 0) LOOP
            v_liste.EXTEND;
            v_index := v_index + 1;
            v_liste(v_index) := t_medicament(rec.idMed, rec.nom, rec.stock);
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('     MÉDICAMENTS EN RUPTURE DE STOCK    ');
        DBMS_OUTPUT.PUT_LINE('========================================');
        IF v_liste.COUNT = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Aucun médicament en rupture de stock.');
        ELSE
            FOR i IN 1 .. v_liste.COUNT LOOP
                DBMS_OUTPUT.PUT_LINE('------------------------------------------');
                DBMS_OUTPUT.PUT_LINE('ID    : ' || v_liste(i).idMed);
                DBMS_OUTPUT.PUT_LINE('Nom   : ' || v_liste(i).nom);
                DBMS_OUTPUT.PUT_LINE('Stock : ' || v_liste(i).stock);
            END LOOP;
            DBMS_OUTPUT.PUT_LINE('------------------------------------------');
            DBMS_OUTPUT.PUT_LINE('Total : ' || v_liste.COUNT || ' médicament(s) en rupture.');
        END IF;
        DBMS_OUTPUT.PUT_LINE('========================================');
    EXCEPTION
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END medicaments_rupture;

    -- --------------------------------------------------------
    -- GESTION DES EXCEPTIONS
    -- --------------------------------------------------------
    PROCEDURE rechercher_patient(p_idPatient IN Patient.idPatient%TYPE) AS
        v_patient Patient%ROWTYPE;
    BEGIN
        SELECT * INTO v_patient FROM Patient WHERE idPatient = p_idPatient;
        DBMS_OUTPUT.PUT_LINE('Patient trouvé : ' || v_patient.nom || ' ' || v_patient.prenom);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Erreur : Aucun patient trouvé avec l''identifiant ' || p_idPatient);
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Erreur inattendue : ' || SQLERRM);
    END rechercher_patient;

    PROCEDURE rechercher_medecin_specialite(p_specialite IN Medecin.specialite%TYPE) AS
        v_medecin Medecin%ROWTYPE;
    BEGIN
        SELECT * INTO v_medecin FROM Medecin WHERE specialite = p_specialite;
        DBMS_OUTPUT.PUT_LINE('Médecin trouvé : ' || v_medecin.nom);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Erreur : Aucun médecin trouvé pour la spécialité ' || p_specialite);
        WHEN TOO_MANY_ROWS THEN
            DBMS_OUTPUT.PUT_LINE('Erreur : Plusieurs médecins correspondent à la spécialité ' || p_specialite);
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Erreur inattendue : ' || SQLERRM);
    END rechercher_medecin_specialite;

    PROCEDURE verifier_stock_et_diviser(p_idMed IN NUMBER, p_diviseur IN NUMBER) AS
        ex_stock_insuffisant EXCEPTION;
        v_stock  NUMBER;
        v_result NUMBER;
    BEGIN
        SELECT stock INTO v_stock FROM Medicament WHERE idMed = p_idMed;
        IF v_stock < 5 THEN RAISE ex_stock_insuffisant; END IF;
        v_result := v_stock / p_diviseur;
        DBMS_OUTPUT.PUT_LINE('Résultat : ' || v_result);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Erreur : médicament introuvable.');
        WHEN ZERO_DIVIDE THEN
            DBMS_OUTPUT.PUT_LINE('Erreur : division par zéro impossible.');
        WHEN TOO_MANY_ROWS THEN
            DBMS_OUTPUT.PUT_LINE('Erreur : plusieurs médicaments trouvés avec le même ID.');
        WHEN ex_stock_insuffisant THEN
            DBMS_OUTPUT.PUT_LINE('Erreur : stock insuffisant (moins de 5 unités).');
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Erreur inattendue : ' || SQLERRM);
    END verifier_stock_et_diviser;

    -- --------------------------------------------------------
    -- PROCÉDURE MÉTIER COMPLEXE
    -- --------------------------------------------------------
    PROCEDURE prescrire_medicament(
        p_idPresc   IN Prescription.idPresc%TYPE,
        p_idPatient IN Prescription.idPatient%TYPE,
        p_idMedecin IN Prescription.idMedecin%TYPE,
        p_datePresc IN Prescription.datePresc%TYPE,
        p_idMed     IN Ligne_Prescription.idMed%TYPE,
        p_quantite  IN Ligne_Prescription.quantite%TYPE
    ) AS
        ex_stock_insuffisant     EXCEPTION;
        ex_patient_inexistant    EXCEPTION;
        ex_medecin_inexistant    EXCEPTION;
        ex_medicament_inexistant EXCEPTION;
        v_stock  NUMBER;
        v_count  NUMBER;
        CURSOR c_prescriptions(c_idPatient Prescription.idPatient%TYPE) IS
            SELECT pr.idPresc, m.nom, lp.quantite
            FROM Prescription pr
            JOIN Ligne_Prescription lp ON pr.idPresc = lp.idPresc
            JOIN Medicament m ON lp.idMed = m.idMed
            WHERE pr.idPatient = c_idPatient;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM Patient WHERE idPatient = p_idPatient;
        IF v_count = 0 THEN RAISE ex_patient_inexistant; END IF;
        SELECT COUNT(*) INTO v_count FROM Medecin WHERE idMedecin = p_idMedecin;
        IF v_count = 0 THEN RAISE ex_medecin_inexistant; END IF;
        SELECT COUNT(*) INTO v_count FROM Medicament WHERE idMed = p_idMed;
        IF v_count = 0 THEN RAISE ex_medicament_inexistant; END IF;
        SELECT stock INTO v_stock FROM Medicament WHERE idMed = p_idMed;
        IF v_stock < p_quantite THEN RAISE ex_stock_insuffisant; END IF;

        DBMS_OUTPUT.PUT_LINE('--- Prescriptions existantes du patient ' || p_idPatient || ' ---');
        FOR rec IN c_prescriptions(p_idPatient) LOOP
            DBMS_OUTPUT.PUT_LINE('Prescription : ' || rec.idPresc ||
                                 ' | Médicament : ' || rec.nom ||
                                 ' | Quantité : '   || rec.quantite);
        END LOOP;

        INSERT INTO Prescription(idPresc, idPatient, idMedecin, datePresc)
        VALUES (p_idPresc, p_idPatient, p_idMedecin, p_datePresc);
        INSERT INTO Ligne_Prescription(idPresc, idMed, quantite)
        VALUES (p_idPresc, p_idMed, p_quantite);
        UPDATE Medicament SET stock = stock - p_quantite WHERE idMed = p_idMed;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Prescription enregistrée. Stock restant : ' || (v_stock - p_quantite));
    EXCEPTION
        WHEN ex_patient_inexistant THEN
            ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : Le patient ' || p_idPatient || ' n''existe pas.');
        WHEN ex_medecin_inexistant THEN
            ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : Le médecin ' || p_idMedecin || ' n''existe pas.');
        WHEN ex_medicament_inexistant THEN
            ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : Le médicament ' || p_idMed || ' n''existe pas.');
        WHEN ex_stock_insuffisant THEN
            ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : Stock insuffisant. Disponible : ' || v_stock || ', demandé : ' || p_quantite);
        WHEN DUP_VAL_ON_INDEX THEN
            ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur : La prescription ' || p_idPresc || ' existe déjà.');
        WHEN OTHERS THEN
            ROLLBACK; DBMS_OUTPUT.PUT_LINE('Erreur inattendue : ' || SQLERRM);
    END prescrire_medicament;

    -- --------------------------------------------------------
    -- CONTRAINTES MÉTIER AVANCÉES
    -- --------------------------------------------------------
    PROCEDURE verifier_capacite_service(p_idService IN Service.idService%TYPE) AS
        ex_capacite_depassee EXCEPTION;
        v_capacite NUMBER;
        v_occupes  NUMBER;
    BEGIN
        SELECT s.capacite, COUNT(h.idHosp)
        INTO v_capacite, v_occupes
        FROM Service s
        LEFT JOIN Hospitalisation h ON s.idService = h.idService AND h.dateSortie IS NULL
        WHERE s.idService = p_idService
        GROUP BY s.capacite;
        IF v_occupes >= v_capacite THEN RAISE ex_capacite_depassee; END IF;
        DBMS_OUTPUT.PUT_LINE('Service disponible. Lits occupés : ' || v_occupes || ' / ' || v_capacite);
    EXCEPTION
        WHEN ex_capacite_depassee THEN
            DBMS_OUTPUT.PUT_LINE('Erreur : Capacité du service ' || p_idService || ' atteinte (' || v_occupes || '/' || v_capacite || ').');
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Erreur : Le service ' || p_idService || ' n''existe pas.');
        WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    END verifier_capacite_service;

END pkg_hopital;
/



/*
CREATE USER tp_user IDENTIFIED BY tp123;
GRANT CONNECT, RESOURCE TO tp_user;
ALTER USER tp_user QUOTA UNLIMITED ON USERS;


run this command pour connect to tp_user ********

sqlplus tp_user/tp123@localhost:1521/XEPDB1

 @1000-complet.sql
 @100-test.sql
 @delete.sql
*/
