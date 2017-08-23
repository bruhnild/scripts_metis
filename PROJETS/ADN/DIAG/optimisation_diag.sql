/*
-------------------------------------------------------------------------------------
Auteur : Marine FAUCHER (METIS)
Date de création : 16/03/2017
Objet : Structuration des tables de cables et chambres/optimisation de production diagnostique réseaux
Modification : Nom : ///// - Date : date_de_modif - Motif/nature : //////

Prerequis:

- FT_Chambre (I:\6 - AMOA DIVERS\4 - IBSE\1 - ADN\MS2\0-Données d'entrée\Reception\ORANGE\%communeetudiee%\Chambre) 
- Ft_ArcIti (I:\6 - AMOA DIVERS\4 - IBSE\1 - ADN\MS2\0-Données d'entrée\Reception\ORANGE%communeetudiee%\Iti) 

/!\ reprojection en 2154

-------------------------------------------------------------------------------------
*/



--********************* Structuration des tables ***************************

--- Schema : ep
--- Table : ft_arc_iti

--- Renommage de tables dans le schema


ALTER TABLE ep."FT_Chambre" RENAME TO ft_chambre;
ALTER TABLE ep."Ft_ArcIti" RENAME TO ft_arc_iti;

----Remplacer charactère inconnu par le PHI grec dans les champs de composition des fourreaux

UPDATE ep.ft_arc_iti
SET compositio = REPLACE(compositio, '�' , 'Ø');

---- Caractériser le type de conduite 

ALTER TABLE ep.ft_arc_iti
ADD type_reseau varchar  --- ajout champ "type_reseau"
;

UPDATE ep.ft_arc_iti 
SET type_reseau = 'autre'  
WHERE compositio is null 
;

UPDATE ep.ft_arc_iti 
SET type_reseau = 'distribution'  
WHERE compositio like '%Ø2%' --- diamètre ~ 20 
OR compositio like '%Ø3%' --- diamètre ~ 30 
OR compositio like '%Ø4%' --- diamètre ~ 40 
OR compositio like '%Ø5%' --- diamètre ~ 50 
AND mode_pose = '7' --- selection des conduites uniquement
;

UPDATE ep.ft_arc_iti 
SET type_reseau = 'transport'  
WHERE compositio like '%Ø6%' --- diamètre ~ 60 
OR compositio like '%Ø7%' --- diamètre ~ 70 
OR compositio like '%Ø8%' --- diamètre ~ 80 
OR compositio like '%Ø9%' --- diamètre ~ 90 
OR compositio like '%Ø1%' --- diamètre ~ 100 
AND mode_pose = '7' --- selection des conduites uniquement 
;

UPDATE ep.ft_arc_iti 
SET type_reseau = 'autre' --- Reste des cables de réseaux non caractérisés
WHERE type_reseau is null 
;

--- Schema : ep
--- Table : ft_chambre

ALTER TABLE ep.ft_chambre
ADD ref_chambr_valid varchar  --- ajout champ "ref_chambr_valid"
;

--- Caractériser les chambres d'après leur références en percutable/non percutable 

UPDATE ep.ft_chambre 
SET ref_chambr_valid = 'non percutable' 
WHERE 
ref_chambr = 'REG' 
OR ref_chambr = '30X'
OR ref_chambr = 'L1T'
OR ref_chambr = 'LOT'
OR ref_chambr = 'L1P'
OR ref_chambr = 'L2C'
OR ref_chambr = 'L2P'
OR ref_chambr = 'L2T'
OR ref_chambr = 'L4T'
OR ref_chambr = 'A/2'
OR ref_chambr = 'A/1'
OR ref_chambr = 'A1'
OR ref_chambr = 'A2'
OR ref_chambr = 'A3'
OR ref_chambr = 'A10'
OR ref_chambr = 'TB'
OR ref_chambr = 'TBT'
;

UPDATE ep.ft_chambre 
SET ref_chambr_valid = 'percutable'  
WHERE 
ref_chambr_valid is null
;

--- Controle topologique : on ne traite que les chambres raccrochées aux cables

DROP TABLE IF EXISTS ep.topo_chambre; --- On stocke les chambres à supprimer dans une table
CREATE TABLE ep.topo_chambre AS 
SELECT 
 ch.id, 
 ch.code_ch1,
 ch.cle_mkt2,
 ch.ref_chambr,
 ch.ref_chambr_valid,
 ch.geom
FROM ep.ft_chambre AS ch
WHERE
ch.id NOT IN 
  (
    SELECT 
      chambre.id
    FROM 
     ep.ft_arc_iti as cable,
     ep.ft_chambre as chambre
    WHERE 
      ST_Intersects(chambre.geom,cable.geom)
  ) 
 ;

DROP TABLE IF EXISTS ep.ft_chambre_clean; --- Par différentiation on ne garde que les chambres sur cables
CREATE TABLE  ep.ft_chambre_clean as 
SELECT 
 DISTINCT ON (geom)geom,  
 id,
 code_ch1,
 cle_mkt2,
 ref_chambr, 
 ref_chambr_valid
FROM ep.ft_chambre AS ch
WHERE ch.id NOT IN
	(
		SELECT 
		 chambre.id
		FROM
		 ep.topo_chambre AS topo,
		 ep.ft_chambre AS chambre
		WHERE ST_Equals(chambre.geom,topo.geom))
;

--- Cast du type du champ "code_ch1"

ALTER TABLE ep.ft_chambre_clean ALTER COLUMN code_ch1 TYPE integer USING (code_ch1::integer);

--********************* Requête récursive ***************************

/*
-------------------------------------------------------------------------------------
I. La premiere partie de la requete trouve tous les cables partant de la chambre de départ 
et connectés a des chambres (geomroom)
-------------------------------------------------------------------------------------
*/
 
DROP TABLE IF EXISTS ep.analyse_chambre;
CREATE TABLE ep.analyse_chambre as 

WITH RECURSIVE tmp AS (
SELECT 
 r.id AS id_chambre_src, 
 c.id AS id_cable, 
 1::INT AS step, 
 ARRAY[r2.id] AS idrooms,
 r2.geom AS geomroom
FROM ep.ft_chambre_clean r JOIN ep.ft_arc_iti c ON st_dwithin(st_boundary(c.geom), r.geom, 0.001) --- lien entre la chambre de départ et un câble
JOIN ep.ft_chambre_clean r2 ON st_dwithin(st_boundary(c.geom), r2.geom, 0.001) --- lien entre un cable et sa chambre d'arrivée
WHERE r.id = 16 AND r2.id <> 16  --- id chambre de départ

/*
-------------------------------------------------------------------------------------
II. La deuxieme partie, récursive, cherche tous les cables connectés aux chambres 
trouvées à l'étape précédente.
-------------------------------------------------------------------------------------
*/

UNION ALL --- selection des cables connectés aux chambres courantes,
SELECT 
 t.id_chambre_src, 
 c.id, 
 step+1, 
 t.idrooms||r.id, 
 r.geom
FROM ep.ft_arc_iti c JOIN tmp t ON st_dwithin(st_boundary(c.geom), t.geomroom, 0.001)
JOIN ep.ft_chambre_clean r ON st_dwithin(st_boundary(c.geom), r.geom, 0.001)
WHERE c.id <> t.id_cable AND NOT (r.id = ANY(t.idrooms)) --- on ne prend pas les câbles et les chambres déjà traitées (condition de stop de la récursion)
AND step <=2 --- on s'arrête à N+5
) 
SELECT * FROM tmp
ORDER BY id_cable
;
CREATE INDEX idx_analyse_chambre_id ON ep.analyse_chambre (id_chambre_src) ; --- index attributaire
CREATE INDEX idx_analyse_chambre_geom ON ep.analyse_chambre (geomroom) ; --- index spatial

--- Cast du champ array "idrooms" en text

ALTER TABLE ep.analyse_chambre ALTER COLUMN idrooms TYPE varchar USING (idrooms::varchar);

--- On retire les accolades 

UPDATE ep.analyse_chambre
SET idrooms = REPLACE(idrooms, '{' , '');
UPDATE ep.analyse_chambre
SET idrooms = REPLACE(idrooms, '}' , '');

--- Chambres traversées stockées dans un tableau
--- On split le tableau en autant de colonnes qu'il y a de valeurs séparées par une virgule 

DROP TABLE IF EXISTS ep.analyse_chambre_reformat;
CREATE TABLE ep.analyse_chambre_reformat AS 
SELECT 
 geomroom,
 step, 
 id_cable,
 id_chambre_src AS "N+2",
 split_part(idrooms, ',', 1) AS "N+3",
 split_part(idrooms, ',', 2) AS "N+4",
 split_part(idrooms, ',', 3) AS "N+5"
FROM  ep.analyse_chambre;
;

--- Remplace les valeurs non numériques par des null

UPDATE ep.analyse_chambre_reformat
SET "N+3" = null where "N+3" !~ '[0-9]'
;
UPDATE ep.analyse_chambre_reformat
SET "N+4" = null where "N+4" !~ '[0-9]'
;
UPDATE ep.analyse_chambre_reformat
SET "N+5" = null where "N+5" !~ '[0-9]'
;

--- Cast des champs N+3, N+4, N+5 en integer

ALTER TABLE ep.analyse_chambre_reformat ALTER COLUMN "N+3" TYPE integer USING ("N+3"::integer);
ALTER TABLE ep.analyse_chambre_reformat ALTER COLUMN "N+4" TYPE integer USING ("N+4"::integer);
ALTER TABLE ep.analyse_chambre_reformat ALTER COLUMN "N+5" TYPE integer USING ("N+5"::integer);

--- Cast du champ code_ch1 de ft_chambre en integer

ALTER TABLE ep.ft_chambre ALTER COLUMN code_ch1 TYPE integer USING (code_ch1::integer);

--- Remplace les id par les code_ch1 des chambres percutables

UPDATE ep.analyse_chambre_reformat as a 
SET "N+2" = b.code_ch1
FROM ep.ft_chambre AS b 
WHERE a."N+2"=b.id;
UPDATE ep.analyse_chambre_reformat as a 
SET "N+3" = b.code_ch1
FROM ep.ft_chambre AS b 
WHERE a."N+3"=b.id;
UPDATE ep.analyse_chambre_reformat as a 
SET "N+4" = b.code_ch1
FROM ep.ft_chambre AS b 
WHERE a."N+4"=b.id;
UPDATE ep.analyse_chambre_reformat as a 
SET "N+5" = b.code_ch1
FROM ep.ft_chambre AS b 
WHERE a."N+5"=b.id;

--- Gid 

ALTER TABLE ep.analyse_chambre_reformat ADD COLUMN gid SERIAL PRIMARY KEY;
--- Classement des chambres

DROP TABLE IF EXISTS ep.analyse_chambre_reformat_order;
CREATE TABLE ep.analyse_chambre_reformat_order AS 
SELECT 
 geomroom, 
 step, 
 id_cable, 
 "N+2",
 1::int AS one, 
 "N+3", 
 2::int AS two, 
 "N+4", 
 3::int AS three, 
 "N+5", 
 4::int AS four, 
 gid
 FROM ep.analyse_chambre_reformat;

--- Structuration de la table en chambre a (origine) ==> chambre b (destination)

DROP TABLE IF EXISTS ep.analyse_chambre_reformat_order_rows;
CREATE TABLE ep.analyse_chambre_reformat_order_rows AS 
SELECT * FROM
(
    SELECT "N+2" AS chambre_a, "N+3" AS chambre_b, gid, one AS id, id_cable FROM ep.analyse_chambre_reformat_order
    UNION ALL
    SELECT "N+3" as chambre_a, "N+4" as chambre_b, gid,  two as id, id_cable  from ep.analyse_chambre_reformat_order
    UNION ALL
    SELECT "N+4" as chambre_a, "N+5" as chambre_b, gid,  three as id, id_cable  from ep.analyse_chambre_reformat_order
) AS a
WHERE chambre_a IS NOT NULL AND chambre_b IS NOT NULL
ORDER BY gid, id;

/*
-------------------------------------------------------------------------------------
with tmp as (
  select *
  from ep.analyse_chambre_reformat
), tmp1 as (
    SELECT gid, unnest(ARRAY ["N+2","N+3","N+4","N+5"]) AS ch
    FROM tmp
    ORDER BY gid
), tmp2 as (
    SELECT
      t.*,
      row_number()
      OVER () AS rn
    FROM tmp1 t
) select t1.ch as chambre_a, t2.ch as chambre_b
from tmp2 t1, tmp2 t2
where t2.rn = t1.rn + 1 and t1.gid = t2.gid and t1 IS NOT NULL AND t2 IS NOT NULL
-------------------------------------------------------------------------------------
*/

--********************* Table pour diagnostique implantation NRO ***************************

--- Serial chambre

ALTER TABLE ep.analyse_chambre_reformat_order_rows ADD COLUMN serial SERIAL PRIMARY KEY;

--- Formatage table chambre_a

DROP TABLE IF EXISTS ep.analyse_chambre_reformat_order_rows_a;
CREATE TABLE ep.analyse_chambre_reformat_order_rows_a AS 
SELECT 
 chambre_a, 
 ref_chambr AS type_chb_a, 
 ref_chambr_valid AS ref_chambre_valid_a, 
 serial
FROM ep.analyse_chambre_reformat_order_rows AS a
LEFT JOIN ep.ft_chambre_clean AS b ON a.chambre_a=b.code_ch1;

--- Formatage table chambre_b

DROP TABLE IF EXISTS ep.analyse_chambre_reformat_order_rows_b;
CREATE TABLE ep.analyse_chambre_reformat_order_rows_b AS
SELECT 
 chambre_b, 
 ref_chambr as type_chb_b, 
 ref_chambr_valid as ref_chambre_valid_b, 
 id_cable, 
 null::varchar as composition, 
 null::varchar as type_reseau, 
 null::float as longueur, 
 serial
FROM ep.analyse_chambre_reformat_order_rows AS a
LEFT JOIN ep.ft_chambre_clean AS b ON a.chambre_b=b.code_ch1;

--- Jointure des tables chambre_a & chambre_b

DROP TABLE IF EXISTS ep.diag_nro;
CREATE TABLE ep.diag_nro AS 
SELECT 
 chambre_a, 
 type_chb_a, 
 ref_chambre_valid_a, 
 chambre_b, 
 type_chb_b, 
 ref_chambre_valid_b, 
 id_cable, 
 composition, 
 type_reseau,
 longueur
FROM ep.analyse_chambre_reformat_order_rows_a AS a
LEFT JOIN ep.analyse_chambre_reformat_order_rows_b AS b ON a.serial=b.serial
ORDER BY a.serial;

ALTER TABLE ep.diag_nro ADD COLUMN classement SERIAL PRIMARY KEY;
CREATE INDEX idx_diag_nro_id ON ep.diag_nro (classement) ; --- index attributaire

--- Update composition infra
UPDATE ep.diag_nro AS a 
SET composition = b.compositio
FROM ep.ft_arc_iti AS b 
WHERE a.id_cable=b.id
;

--- Update type infra

UPDATE ep.diag_nro AS a 
SET type_reseau = b.type_reseau
FROM ep.ft_arc_iti AS b 
WHERE a.id_cable=b.id
;

--- Update longueur infra

UPDATE ep.diag_nro AS a 
SET longueur = b.longueur
FROM ep.ft_arc_iti AS b 
WHERE a.id_cable=b.id
;

--- Supprimer doublons 

DELETE FROM ep.diag_nro
WHERE classement IN (
	SELECT 
	 classement
    FROM (
    	SELECT 
    	 classement,
    	 ROW_NUMBER() OVER (partition BY chambre_a, chambre_b ORDER BY classement) AS rnum
        FROM ep.diag_nro) t
        WHERE t.rnum > 1);

--- Export en CSV

SET CLIENT_ENCODING TO 'utf8';
COPY ep.diag_nro
TO 'C:\csv\myfile1.csv' WITH DELIMITER	';' CSV HEADER ;

--********************* Tables export ***************************

--- Table CHB

DROP TABLE IF EXISTS ep.chb;
CREATE TABLE ep.chb AS
SELECT 
 distinct on(id) id, 
 classement,
 statut, 
 implant, 
 nature_cha, 
 ref_chambr, 
 ref_chambr_valid,
 ref_note, 
 code_com, 
 code_voie, 
 num_voie, 
 id_proprie, 
 type_trapp, 
 quantifica, 
 rotation, 
 code_ch1, 
 code_ch2, 
 note, 
 securisee, 
 cle_mkt1, 
 cle_mkt2, 
 code_ch1_c, 
 code_ch2_p, 
 classe,
 geom
FROM ep.ft_chambre as a, ep.diag_nro AS b
WHERE a.code_ch1=b.chambre_a OR a.code_ch1=b.chambre_b
;

CREATE INDEX idx_chb_id ON ep.chb (classement) ; --- index attributaire
CREATE INDEX idx_chb_geom ON ep.chb (geom) ; --- index spatial


--- TABLE INFRA

DROP TABLE IF EXISTS ep.infra;
CREATE TABLE ep.infra AS 
SELECT 
 distinct(id)
 statut, 
 mode_pose, 
 aut_passag, 
 aut_pass_1, 
 nature_con, 
 type_longu, 
 a.longueur, 
 note, 
 compositio, 
 a.type_reseau,
 id_proprie, 
 origine, 
 classe, 
 shape_len,
 a.geom
FROM ep.ft_arc_iti AS a, ep.diag_nro AS b
WHERE a.id = b.id_cable
;

--- Sppression tables intermédiaires

DROP TABLE IF EXISTS ep.topo_chambre;
DROP TABLE IF EXISTS ep.ft_chambre_clean;
DROP TABLE IF EXISTS ep.analyse_chambre;
DROP TABLE IF EXISTS ep.analyse_chambre_reformat;
DROP TABLE IF EXISTS ep.analyse_chambre_reformat_order;
DROP TABLE IF EXISTS ep.analyse_chambre_reformat_order_rows;
DROP TABLE IF EXISTS ep.analyse_chambre_reformat_order_rows_a;
DROP TABLE IF EXISTS ep.analyse_chambre_reformat_order_rows_b;
