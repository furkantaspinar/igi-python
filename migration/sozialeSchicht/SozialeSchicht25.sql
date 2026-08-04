
/*

Bearbeiter:
BEN 11.08.2025


Berechnung CASA_SOZ_SCH

*/




--Daten importieren
Drop Table if exists staging.casa_soz_sch_data;
Create Table staging.casa_soz_sch_data as
SELECT a.ags27, a.ags5,
    b.casa_wh_preis AS wh_preis,
	round((b.casa_wh_preis * 5.5 / 1200.0)::numeric, 1) AS bel_k
FROM variablen2025.ags27 a
LEFT JOIN sas_dbupdate._ags27_ben_0522_wh_preis b ON a.ags27 = b.ags27
;

--23503292
--AGS5 Schichten nach Perzentilen einteilen und an Ausgangsdaten spielen + monatliches Einkommen berechnen
Drop Table if exists staging.casa_soz_sch_mon_eink;
Create Table staging.casa_soz_sch_mon_eink as
with perc as
(
	SELECT
	    ags5,
	    round(percentile_cont(0.25) WITHIN GROUP (ORDER BY bel_k)::numeric,1) AS p25,
	    round(percentile_cont(0.50) WITHIN GROUP (ORDER BY bel_k)::numeric,1) AS p50,
	    round(percentile_cont(0.75) WITHIN GROUP (ORDER BY bel_k)::numeric,1) AS p75
	FROM staging.casa_soz_sch_data
	group by ags5
)
Select a.ags27, a.ags5, a.wh_preis, a.bel_k,
		b.p25, b.p50, b.p75,
		CASE
            WHEN a.bel_k <= b.p25 THEN BEL_K * 3
            WHEN a.bel_k <= b.p75 THEN BEL_K * 4
            WHEN a.bel_k > b.p75  THEN BEL_K * 5
            ELSE NULL
        END AS mon_eink
from staging.casa_soz_sch_data a
left join perc b on a.ags5 = b.ags5
;

--23503292
--Schwellenwerte zur Einteilung der Klassen aus Perzentilen ableiten
Drop Table if exists staging.casa_soz_sch_final;
Create Table staging.casa_soz_sch_final as
with perc as
(
	SELECT
	    percentile_cont(0.10) WITHIN GROUP (ORDER BY mon_eink) AS p10,
	    percentile_cont(0.40) WITHIN GROUP (ORDER BY mon_eink) AS p40,
	    percentile_cont(0.60) WITHIN GROUP (ORDER BY mon_eink) AS p60,
	    percentile_cont(0.90) WITHIN GROUP (ORDER BY mon_eink) AS p90
	FROM staging.casa_soz_sch_mon_eink
)
Select a.ags27, a.mon_eink, 
	case 
		when a.mon_eink <= p10 then 5
		when a.mon_eink <= p40 then 4
		when a.mon_eink <= p60 then 3
		when a.mon_eink <= p90 then 2
		when a.mon_eink > p90 then 1
	else
		-99
	end::smallint as casa_soz_sch
from staging.casa_soz_sch_mon_eink a
left join perc b on True
;

ALTER TABLE staging.casa_soz_sch_final ADD PRIMARY KEY (ags27);

/*
  Bedeutung der Codes für CASA_SOZ_SCH:
  -99 = k.A.
  1 = Oberschicht
  2 = obere Mittelschicht
  3 = Mittelschicht
  4 = untere Mittelschicht
  5 = Unterschicht
*/

--Prüfung:
with cnt1 as
(
	SELECT count(*) as cnt2025, casa_soz_sch
	FROM staging.casa_soz_sch_final
	group by casa_soz_sch
),
cnt2 as
(
	SELECT count(*) as cnt2024, casa_soz_sch
	FROM variablen2024.ags27_casa_soz
	group by casa_soz_sch
)
SELECT a.casa_soz_sch, cnt2025, cnt2024
FROM cnt1 a
left join cnt2 b on a.casa_soz_sch = b.casa_soz_sch
order by a.casa_soz_sch
;

--0
SELECT count(*)
FROM variablen2025.ags27_casa_hh a
LEFT JOIN staging.casa_soz_sch_final b ON a.ags27 = b.ags27
WHERE a.casa_hh > 0 and 
	b.casa_soz_sch = -99;


Drop Table if exists staging.casa_soz_sch_data;
Drop Table if exists staging.casa_soz_sch_mon_eink;