
***		Erwerbstätige am Arbeitsort
		Erwerbstätige am Arbeitsort nach Wirtschaftszweig

		Datum Ersterstellung: 06.07.2022
		Bearbeiter: SE

		Datum Ersterstellung: 15.08.2023
		Bearbeiter: SE

		Datum: 25.07.2024
		Bearbeiter: SoH

		Datum: 24.06.2025
		Bearbeiter: ViE

Inputdaten: Beschäftigtenzahlen aus den Firmendaten (Bedirect)
Amtliche Zahlen zu ERWERBSTÄTIGEN (NICHT Sozialversicherungspflichtig Beschäftigte) auf Kreis:


ANMERKUNG:
Falls keine aktuellen (zum Gebietsstand) kreisgenauen Zahlen zu Erwerbstätigen vorhande,
dann Eichen der Gesamtzahlen zum Gebietsstand an aktuellen Zahlen auf Bundesland aus der (Google) "Erwerbstätigenrechnung des Bundes und der Länder"
LINK: https://www.statistikportal.de/de/etr/ergebnisse/erwerbstaetige-personen/erwerbstaetige-jahresdurchschnitt 
Datei:
U:\Marktdaten\Amtliche Daten\3_Arbeitsmarkt\Rohdaten\Bundesland\2022\BL_ERWT_AO_2022.xlsx
=> "import" Reiter!

Kreisdatei => sind ganz aktuell also fällt eichen an BL weg
U:\Marktdaten\Amtliche Daten\3_Arbeitsmarkt\Aufbereitet\2022\KR_ERWT_WZ_ao_2022.csv 
(RegioStat Tabellencode "13312-01-05-4")

ANMERKUNG aus PAGS204:
Durch Kundenrückfragen ist aufgefallen, dass die Berechnung so wie sie in PAGS2023 
durchgeführt wurde bei den ERWT_AO gesamt gut passt aber bei den ERWT nach Branchen
extrem abweicht, daher wird die Berechung überarbeitet:
- Eichen an amtlichen Daten nach Branchen auf dem Kreis => dafür auch Anpassung der resultierenden Variablen 
	an die Branchen so wie sie in den amtlichen Daten vorliegen:
		Land-, Forstwirtschaft und Fischerei
		Produzierendes Gewerbe ohne Baugewerbe und verarbeitendes Gewerbe
		Verarbeitendes Gewerbe
		Baugewerbe	
		Handel, Verkehr, Gastgewerbe, Information und Kommunikation
		Finanz-, Versicherungs-, Unternehmensdienstleistungen, Grundstücks- und Wohnungswesen
		Öffentliche und sonstige Dienstleistungen, Erziehung, Gesundheit

;;

* Löschen des Work-Verzeichnisses (Cleanup);
/*
proc datasets lib=work kill nolist memtype=all;
quit;
*/

* Arbeitsverzeichnisse;
libname besch "/mnt/sachdaten/Mikrodaten/Beschäftigte/Datensätze/PAGS2025";



*** kurzer Check der Gesamtzahlen;;
	proc means data=pg_proc.kr_erwt_br_2022 (schema=roh_genesis) sum n nmiss maxdec=0;
	var kr_erwt_ges;
	run;
		* 2025:  45595800 -> weil auch 2022 Tabelle;
		* (2024) 45595800;;
		* (2023) 44979800;;
		* (2022) 45270300;;


* da noch keine Daten von 2023 veröffentlich, werden die von 2022 verwendet, liegen auch in Datenbank; 
data KR; set pg_proc.kr_erwt_br_2022 (schema=roh_genesis); run;


*	Hauptbranche 3 ist in der 2 enthalten. 
Für weitere Rechnungen wird die 3 aus der 2 entfernt 
(Gesamtzahl bleibt erhalten);
data KR_00; set KR;
KR_ERWT_BR2 = KR_ERWT_BR2 - KR_ERWT_BR3;
DELTA =  KR_ERWT_GES - sum(of KR_ERWT_BR:);
KR_ERWT_BR3 = KR_ERWT_BR3 + delta;
DELTAn =  KR_ERWT_GES - sum(of KR_ERWT_BR:);
ags2 = substr(ags5,1,2);
run;

			* Check der Deltas;
			proc freq data=KR_00;
			tables delta:;
			run;

			proc means data=KR_00 min max sum maxdec=0;
			run;

/* Wenn Zahlen zum aktuellen Datenstand nicht vorhanden
* Eichen an Bundeslandzahlen der "Erwerbstätigenrechnung des Bundes und der Länder";
proc sql; create table KR_01
as select
 *
,sum(KR_ERWT_GES) as BL_ERWT_GES_a
from KR_00
group by AGS2;
quit;

proc sql;
create table KR_01
as select 
a.*,
b.ERWT as BL_ERWT_GES
from KR_01 a
left join BL_ERWT_AO_2022 b
on a.ags2=b.ags2;
quit;
*/
data KR_02; set KR_00

/*KR_01
(rename=(
	KR_ERWT_GES = KR_ERWT_GES_alt
	KR_ERWT_BR1 = KR_ERWT_alt_BR1
	KR_ERWT_BR2 = KR_ERWT_alt_BR2
	KR_ERWT_BR3 = KR_ERWT_alt_BR3
	KR_ERWT_BR4 = KR_ERWT_alt_BR4
	KR_ERWT_BR5 = KR_ERWT_alt_BR5
	KR_ERWT_BR6 = KR_ERWT_alt_BR6
	KR_ERWT_BR7 = KR_ERWT_alt_BR7
))*/
;
/*delta_01 = BL_ERWT_GES - BL_ERWT_GES_a;
delta_02 = BL_ERWT_GES/BL_ERWT_GES_a;

chk1 = KR_ERWT_GES_alt - sum(of KR_ERWT_alt_BR1-KR_ERWT_alt_BR7);

KR_ERWT_GES	= round((KR_ERWT_GES_alt/BL_ERWT_GES_a)*BL_ERWT_GES);
KR_ERWT_BR1	= round((KR_ERWT_alt_BR1/BL_ERWT_GES_a)*BL_ERWT_GES);
KR_ERWT_BR2	= round((KR_ERWT_alt_BR2/BL_ERWT_GES_a)*BL_ERWT_GES);
KR_ERWT_BR3 = round((KR_ERWT_alt_BR3/BL_ERWT_GES_a)*BL_ERWT_GES);
KR_ERWT_BR4	= round((KR_ERWT_alt_BR4/BL_ERWT_GES_a)*BL_ERWT_GES);
KR_ERWT_BR5 = round((KR_ERWT_alt_BR5/BL_ERWT_GES_a)*BL_ERWT_GES);
KR_ERWT_BR6	= round((KR_ERWT_alt_BR6/BL_ERWT_GES_a)*BL_ERWT_GES);
KR_ERWT_BR7	= round((KR_ERWT_alt_BR7/BL_ERWT_GES_a)*BL_ERWT_GES);*/

chk2 = KR_ERWT_GES - sum(of KR_ERWT_BR1-KR_ERWT_BR7);
run;
	
	proc means data=KR_02 n nmiss min mean max;
	var chk2;
	run; *überall 0  (Rundungsdifferenzen aufm Kreis nach dem eichen an BL wären hier auch ok!;;

		proc sql;
		create table chk_sum
		as select 
		sum(KR_ERWT_GES)
		from KR_02;
		quit; *45595800;;
		/** Kleiner Check der Abweichungen auf BL-Ebene;
		proc means data=KR_02 min max mean range;
		var delta_:;
		run;
		proc univariate data=KR_02 noprint;
		var delta_:;
		histogram;
		inset min max mean range / position=ne;
		run;*/

**			Ortsteildaten;;

data OT_00; set pg_prod.ags11_ot_soz 
(schema=variablen2025 keep=ags11 OT_BE_AO OT_SELBST );
ags5 = substr(ags11,1,5);
OT_ERWT_BASIS = sum(of ot_be_ao	 ot_selbst);
if OT_ERWT_BASIS = . then OT_ERWT_BASIS = 0;
run;
* 65243;;

proc sql; create table OT_01
as select *, sum(OT_ERWT_BASIS) as KR_ERWT_BASIS
from OT_00 (drop=OT_BE_AO OT_SELBST )
group by ags5;
quit;
* 65243;;

*Firmendaten - PAGS25 = Bedirect;
data firm; set pg_prod.bedirect_vie_20250409 (schema=bedirect);
keep qid ags27 ags11 ags8 ags5 br_absch_hptcode mitarbeiter_real br_abt_hptcode;
where ags27 ^= "";
run;*4.717.215;


proc means data=firm n nmiss;
var mitarbeiter_real;
run;

*** Teilweise missings, sollen später dann über Mittelwerte nach Branche auf OT, GEM, KR aufgefüllt werden;
data DATAB_00a2;
set firm;
mitarbeiter_estm_anp = mitarbeiter_real; 
where ags11 ^= "";
run;

* Auffüllen bei fehlenden Mitarbeiterzahlen;;
* auf OT;
proc sql; create table DATAB_00b 
as select *
,round(mean(mitarbeiter_estm_anp)) as mn_mitarbeiter_estm_anp
from DATAB_00a2
group by ags11, br_absch_hptcode;
quit; 

* auf Gemeinde;
proc sql; create table DATAB_00c
as select *
,round(mean(mitarbeiter_estm_anp)) as mn2_mitarbeiter_estm_anp
from (select *, substr(ags11,1,8) as ags8 from DATAB_00b)
group by ags8, br_absch_hptcode;
quit;

* auf Kreis;
proc sql; create table DATAB_00d
as select *
,round(mean(mitarbeiter_estm_anp)) as mn3_mitarbeiter_estm_anp
from DATAB_00c
group by ags5, br_absch_hptcode;
quit;

* Insgesamt nach Branche;
proc sql; create table DATAB_00e
as select *
,round(mean(mitarbeiter_estm_anp)) as mn4_mitarbeiter_estm_anp
from DATAB_00d
group by br_absch_hptcode;
quit;

* Missings ersetzen mit Mittelwerten;
data DATAB_00f; set DATAB_00e;
if mitarbeiter_estm_anp = . and	mn_mitarbeiter_estm_anp ^= . 
	then mitarbeiter_estm_anp = mn_mitarbeiter_estm_anp;
if mitarbeiter_estm_anp = . and	mn_mitarbeiter_estm_anp = . and mn2_mitarbeiter_estm_anp ^= . 
	then mitarbeiter_estm_anp = mn2_mitarbeiter_estm_anp;
if mitarbeiter_estm_anp = . and	mn_mitarbeiter_estm_anp = . and	mn2_mitarbeiter_estm_anp = . and mn3_mitarbeiter_estm_anp ^= . 
	then mitarbeiter_estm_anp = mn3_mitarbeiter_estm_anp;
if mitarbeiter_estm_anp = . and	mn_mitarbeiter_estm_anp = . and mn2_mitarbeiter_estm_anp = . and mn3_mitarbeiter_estm_anp = . and mn4_mitarbeiter_estm_anp ^= . 
	then mitarbeiter_estm_anp = mn4_mitarbeiter_estm_anp;
drop mn: ags8;
run;

proc means data=DATAB_00f n nmiss;
var mitarbeiter_estm_anp mn:;
run; *alles gefüllt;

data DATAB_01; set DATAB_00f;
if br_absch_hptcode = 1							then casa_anz_firm_b1=1; *(A) Land-, Forstwirtschaft und Fischerei;
if br_absch_hptcode in (2,4,5)					then casa_anz_firm_b2=1; *(B-E ohne C) Produzierendes Gewerbe ohne Baugwerbe und verarbeitendes Gewerbe;
if br_absch_hptcode = 3 						then casa_anz_firm_b3=1; *(C) Verarbeitendes Gewerbe;
if br_absch_hptcode = 6							then casa_anz_firm_b4=1; *(F) Baugewerbe;
if br_absch_hptcode in (7,8,9,10) 				then casa_anz_firm_b5=1; *Handel, Vekehr, Gastgewerbe, Information und Kommunikation;
if br_absch_hptcode in (11,12,13,14) 			then casa_anz_firm_b6=1; *Finanz-, Versicheruns-, Unternehemnsdienstleistungen, Grundstücks- und Wohnungswese;
if br_absch_hptcode in (15,16,17,18,19,20,21)  	then casa_anz_firm_b7=1; *Öffentliche und sonstige Dienstleistungen, Erziehung, Gesundheit;
if br_absch_hptcode=. 							then casa_anz_firm_b99=1;
where ags27 ne '';
rename mitarbeiter_estm_anp=Mitarbeiter_imp;
run;
* 4.651.386;

**			Mitarbeiter auf AGS5 und AGS11 aggregieren;;
proc sql; create table DATAB_02
as select ags11
,min(ags5) as ags5
,sum(case when  casa_anz_firm_b1 = 1 then Mitarbeiter_imp else 0 end) as OT_DATAB_MA_HBR01
,sum(case when  casa_anz_firm_b2 = 1 then Mitarbeiter_imp else 0 end) as OT_DATAB_MA_HBR02
,sum(case when  casa_anz_firm_b3 = 1 then Mitarbeiter_imp else 0 end) as OT_DATAB_MA_HBR03
,sum(case when  casa_anz_firm_b4 = 1 then Mitarbeiter_imp else 0 end) as OT_DATAB_MA_HBR04
,sum(case when  casa_anz_firm_b5 = 1 then Mitarbeiter_imp else 0 end) as OT_DATAB_MA_HBR05
,sum(case when  casa_anz_firm_b6 = 1 then Mitarbeiter_imp else 0 end) as OT_DATAB_MA_HBR06
,sum(case when  casa_anz_firm_b7 = 1 then Mitarbeiter_imp else 0 end) as OT_DATAB_MA_HBR07
,sum(case when casa_anz_firm_b99 = 1 then Mitarbeiter_imp else 0 end) as OT_DATAB_MA_HBR99
from DATAB_01 
group by ags11;
quit;
*61.336;

*				Missings mit 0 füllen;;
data DATAB_02b; set DATAB_02;
array nullen _numeric_;
	do over nullen;
	if nullen = . then nullen = 0;
	end;

OT_Mitarbeiter = sum(of OT_DATAB_MA_HBR:);
run;

*	Check der Aggregation;;
		data CHECK (where=(TEST ^= 0)); set DATAB_02b;
		TEST = OT_Mitarbeiter-(sum(of OT_DATAB_MA_HBR:));
		run;*leer, passt;

proc sql; create table DATAB_03 (where=(ags11 ^= ""))
as select
 *
,sum(OT_Mitarbeiter) as KR_Mitarbeiter
,sum(OT_DATAB_MA_HBR01) as KR_DATAB_MA_HBR01
,sum(OT_DATAB_MA_HBR02) as KR_DATAB_MA_HBR02
,sum(OT_DATAB_MA_HBR03) as KR_DATAB_MA_HBR03
,sum(OT_DATAB_MA_HBR04) as KR_DATAB_MA_HBR04
,sum(OT_DATAB_MA_HBR05) as KR_DATAB_MA_HBR05
,sum(OT_DATAB_MA_HBR06) as KR_DATAB_MA_HBR06
,sum(OT_DATAB_MA_HBR07) as KR_DATAB_MA_HBR07
,sum(OT_DATAB_MA_HBR99) as KR_DATAB_MA_HBR99
from DATAB_02b
group by ags5;
quit; *61.336;;

data datab_03; set home.datab_03; run;

***		Anspielen der Kreisdaten und Eichen;;
proc sql; create table DATAB_04
as select
 a.*
,b.*
,c.*
from DATAB_03				as a
left join (select *, 1 as vollst from  KR_02)	as b on a.ags5 = b.ags5
left join (select *, 1 as vollst2	from OT_01)	as c on a.ags11 = c.ags11;
quit;

		* Check, ob Match vollständig;;
		data CHECK; set DATAB_04;
		where vollst = .  or vollst2 = .;
		run; * Tabelle leer? Gut!;;

		* Check, ob die KR_ERWT_BASIS immer kleiner ist, als die amtl. ERTW Zahl;;
		data CHECK (keep=ags: kr_erwt_basis kr_erwt_ges differenz:); set DATAB_04;
		where kr_erwt_basis > KR_ERWT_GES;
		differenz = kr_erwt_basis - KR_ERWT_GES;
		differenz_rel = round(kr_erwt_basis / KR_ERWT_GES,.01);
		run; * Tabelle sollte leer sein! 
		=> 0 Fälle vorhanden!;
		proc sql;
		create table tst
		as select distinct ags5
		from CHECK;
		quit; * => 0;
		* kein Problem mehr in PAGS25;
		*im PAGS24 gibt es jetzt so Fälle, zuvor keine, es sollten im besten Fall auch keine sein,
		es lag bei einem Kreis an widersprüchlichen amtlichen Daten bei den 
		BE_AO und den ERWT_AO
		und bei zwei Kreisen an überschätzen Selbstständigen
		=> im nächsten Update sollen Selbstständige/MITHFAM parallel berechnet 
		werden um ggf sowas noch anpassen zu können);

**		SELBST und ERWT_AO werden als Basis verteilt, die Differenz zu den amtlichen Kreiszahlen wird anhand der Mitarbeiter verteilt;;
data DATAB_05a; set DATAB_04 (drop= vollst vollst2);

*	Wenn Basis größer als amtliche Gesamtzahl, dann amtliche Zahl gleich setzen, wenn relative Abweichung kleiner als 1.3;
differenz_rel = round(kr_erwt_basis / KR_ERWT_GES,.01);
if kr_erwt_basis > KR_ERWT_GES and differenz_rel < 1.3 then do;
		marke_anpassung = 1;
		KR_ERWT_GES = KR_ERWT_BASIS;
		end;

REST_DIFFERENZ = KR_ERWT_GES-KR_ERWT_BASIS;

ANT_Mitarbeiter = (OT_Mitarbeiter / KR_Mitarbeiter);

DELTA_BASIS = REST_DIFFERENZ*(OT_Mitarbeiter / KR_Mitarbeiter);

mini = min(of OT_ERWT_BASIS DELTA_BASIS);
maxi = max(of OT_ERWT_BASIS DELTA_BASIS);
run;
	
	* Check, wo Anpassungen geschehen sind;
	proc freq data=DATAB_05a;
	tables marke_anpassung / missing;
	run;

	proc univariate data=DATAB_05a;
	var REST_DIFFERENZ;
	histogram;
	run;

proc sql; create table DATAB_05b
as select *
,sum(mini) as kr_mini
,sum(maxi) as kr_maxi
from DATAB_05a
group by ags5;
quit;

data DATAB_05; set DATAB_05b;

OT_ERWT_AO_ = (kr_mini*(OT_Mitarbeiter / KR_Mitarbeiter)) + maxi;

OT_ERWT_AO_B01 = OT_ERWT_AO_ * (OT_DATAB_MA_HBR01/OT_Mitarbeiter);
OT_ERWT_AO_B02 = OT_ERWT_AO_ * (OT_DATAB_MA_HBR02/OT_Mitarbeiter);
OT_ERWT_AO_B03 = OT_ERWT_AO_ * (OT_DATAB_MA_HBR03/OT_Mitarbeiter);
OT_ERWT_AO_B04 = OT_ERWT_AO_ * (OT_DATAB_MA_HBR04/OT_Mitarbeiter);
OT_ERWT_AO_B05 = OT_ERWT_AO_ * (OT_DATAB_MA_HBR05/OT_Mitarbeiter);
OT_ERWT_AO_B06 = OT_ERWT_AO_ * (OT_DATAB_MA_HBR06/OT_Mitarbeiter);
OT_ERWT_AO_B07 = OT_ERWT_AO_ * (OT_DATAB_MA_HBR07/OT_Mitarbeiter);
OT_ERWT_AO_B99 = OT_ERWT_AO_ * (OT_DATAB_MA_HBR99/OT_Mitarbeiter);
OT_ERWT_AO_ANZ = sum(of OT_ERWT_AO_B:);

* Anpassungen bei Branchen, bei denen eine Abrundung auf 0 eine Firma ohne Mitarbeiter hinterlassen würde;;
array letztrest OT_ERWT_AO_B:;
do over letztrest;
	if letztrest < 0.5 and letztrest > 0 then letztrest = 1;
	end;
run;


* Werte runden und finalisieren;;
data DATAB_06; set DATAB_05;
OT_ERWT_AO_B01 = round(OT_ERWT_AO_B01);
OT_ERWT_AO_B02 = round(OT_ERWT_AO_B02);
OT_ERWT_AO_B03 = round(OT_ERWT_AO_B03);
OT_ERWT_AO_B04 = round(OT_ERWT_AO_B04);
OT_ERWT_AO_B05 = round(OT_ERWT_AO_B05);
OT_ERWT_AO_B06 = round(OT_ERWT_AO_B06);
OT_ERWT_AO_B07 = round(OT_ERWT_AO_B07);
OT_ERWT_AO_B99 = round(OT_ERWT_AO_B99);
OT_ERWT_AO_ANZ = sum(of OT_ERWT_AO_B:);

if OT_ERWT_AO_ANZ = . then OT_ERWT_AO_ANZ = round(OT_ERWT_BASIS);

if OT_ERWT_AO_B01 = . and OT_ERWT_AO_ANZ = 0 then do;
	OT_ERWT_AO_B01 = 0;
	OT_ERWT_AO_B02 = 0;
	OT_ERWT_AO_B03 = 0;
	OT_ERWT_AO_B04 = 0;
	OT_ERWT_AO_B05 = 0;
	OT_ERWT_AO_B06 = 0;
	OT_ERWT_AO_B07 = 0;
	OT_ERWT_AO_B99 = 0;
	end;

delta1 = OT_ERWT_BASIS - OT_ERWT_AO_ANZ;

if delta1 > 0 then do;
	OT_ERWT_AO_B99 = OT_ERWT_AO_B99 + delta1;
	OT_ERWT_AO_ANZ = OT_ERWT_AO_ANZ + delta1;
	end;

delta2 = OT_ERWT_BASIS - OT_ERWT_AO_ANZ;
run;

		*	ERWT_ZAHLEN auf OT größer als Basis?;;
		data check; set DATAB_06;
		where OT_ERWT_BASIS	> OT_ERWT_AO_ANZ;
		run; *keine Fälle;

		proc means data=DATAB_06 min max range;
		var delta:;
		run;


**		Differenz zur amtlichen Kreis-Gesamtzahl auf größte Branche packen);;

*			Deltas ermitteln;;
proc sql; create table DATAB_07
as select
*, 
/*ags5, KR_ERWT_GES,*/
sum(OT_ERWT_AO_ANZ) as KR_OT_ERWT_AO_ANZ
,KR_ERWT_GES - sum(OT_ERWT_AO_ANZ) as delta_abs
,round(KR_ERWT_GES / sum(OT_ERWT_AO_ANZ),.0001) as delta_rel
from DATAB_06
group by ags5;
quit;

	proc means data=DATAB_07 min max;
	var delta_abs delta_rel;
	run;
	* relative Delta extrem klein 0.9985 bis 1.013;;

	proc sort data=DATAB_07
 	/*(keep=ags5 KR_ERWT_GES KR_OT_ERWT_AO_ANZ delta_abs delta_rel)*/
	out=tst;
	by descending delta_rel;
	run;

	data tst1;
	set DATAB_07;
	diff_sum = OT_ERWT_AO_ANZ - sum(of
		OT_ERWT_AO_B01 
		OT_ERWT_AO_B02
		OT_ERWT_AO_B03
		OT_ERWT_AO_B04
		OT_ERWT_AO_B05
		OT_ERWT_AO_B06
		OT_ERWT_AO_B07
		OT_ERWT_AO_B99);
	run;
	proc means data=tst1 n nmiss min mean max;
	var diff_sum
	OT_ERWT_AO_ANZ
	OT_ERWT_AO_B01 
	OT_ERWT_AO_B02
	OT_ERWT_AO_B03
	OT_ERWT_AO_B04
	OT_ERWT_AO_B05
	OT_ERWT_AO_B06
	OT_ERWT_AO_B07
	OT_ERWT_AO_B99;
	run;

*		Werte vorerst finalisieren;;
proc sql; create table DATAB_11
as select
ags11
,OT_ERWT_AO_ANZ as OT_ERWT_AO
,OT_ERWT_AO_B01
,OT_ERWT_AO_B02
,OT_ERWT_AO_B03
,OT_ERWT_AO_B04
,OT_ERWT_AO_B05
,OT_ERWT_AO_B06
,OT_ERWT_AO_B07
,OT_ERWT_AO_B99
from DATAB_07;
quit;

data DATAB_12; set DATAB_11;
SUMME = sum(of 
OT_ERWT_AO_B01 OT_ERWT_AO_B02 OT_ERWT_AO_B03 OT_ERWT_AO_B04 OT_ERWT_AO_B05 
OT_ERWT_AO_B06 OT_ERWT_AO_B07 OT_ERWT_AO_B99);

if SUMME = 0 then do;
	OT_ERWT_AO		= .;
	OT_ERWT_AO_B01	= .;
	OT_ERWT_AO_B02	= .;
	OT_ERWT_AO_B03	= .;
	OT_ERWT_AO_B04	= .;
	OT_ERWT_AO_B05	= .;
	OT_ERWT_AO_B06	= .;
	OT_ERWT_AO_B07	= .;
	OT_ERWT_AO_B99	= .;
	marke = 1;
end;
ags5 = substr(ags11,1,5);
run;

		data check; set DATAB_12;
		where marke = 1;
		run; * keine Fälle;

* Stand jetzt: 
	Summe der Branchen im OT zur Gesamtzahl OT passt
	Kreisgesamtzahl passt zur aggregierten OT Gesamtzahl
Abweichungen zu amtlichen Zahlen vom Kreis nach Bracnhen noch checken;;
proc sql;
create table kr_agg1
as select 
ags5
,sum(OT_ERWT_AO) as KR_agg_AO
,sum(OT_ERWT_AO_B01) as KR_agg_AO_B01
,sum(OT_ERWT_AO_B02) as KR_agg_AO_B02
,sum(OT_ERWT_AO_B03) as KR_agg_AO_B03
,sum(OT_ERWT_AO_B04) as KR_agg_AO_B04
,sum(OT_ERWT_AO_B05) as KR_agg_AO_B05
,sum(OT_ERWT_AO_B06) as KR_agg_AO_B06
,sum(OT_ERWT_AO_B07) as KR_agg_AO_B07
,sum(OT_ERWT_AO_B99) as KR_agg_AO_B99
from DATAB_12
group by ags5;
quit;

proc sql;
create table kr_agg2
as select
a.*, b.*
from kr_agg1 a
left join KR_02 b on a.ags5=b.ags5;
quit;

data kr_chk1;
set kr_agg2;
diff_ges = kr_agg_ao - kr_erwt_ges;
diff_b01 = kr_agg_ao_b01 - kr_erwt_br1;
diff_b02 = kr_agg_ao_b01 - kr_erwt_br2;
diff_b03 = kr_agg_ao_b01 - kr_erwt_br3;
diff_b04 = kr_agg_ao_b01 - kr_erwt_br4;
diff_b05 = kr_agg_ao_b01 - kr_erwt_br5;
diff_b06 = kr_agg_ao_b01 - kr_erwt_br6;
diff_b07 = kr_agg_ao_b01 - kr_erwt_br7;
diff_ges_r = (diff_ges / kr_erwt_ges) *100;
diff_b01_r = (diff_b01 / kr_erwt_br1) *100;
diff_b02_r = (diff_b02 / kr_erwt_br2) *100;
diff_b03_r = (diff_b03 / kr_erwt_br3) *100;
diff_b04_r = (diff_b04 / kr_erwt_br4) *100;
diff_b05_r = (diff_b05 / kr_erwt_br5) *100;
diff_b06_r = (diff_b06 / kr_erwt_br6) *100;
diff_b07_r = (diff_b07 / kr_erwt_br7) *100;
run;

proc means data=kr_chk1 n nmiss min mean max;
var diff:;
run;

*** Da es zu den amtlichen Zahlen vom Kreis noch große Abweichungen gibt 
		noch eine abschließende Runde daran eichen;;

proc sql;
create table eich1 (drop=marke SUMME chk: BL_: DELTA: ags2 KR_ERWT_GES_alt KR_ERWT_alt:)
as select 
a.*, b.*
from DATAB_12 as a
left join KR_02 as b 
on substr(a.ags11,1,5) = b.ags5;
quit;

proc sql; create table eich2
as select 
*
,sum(ot_erwt_ao) as kr_ot_erwt_ao
,sum(OT_ERWT_AO_B01) as kr_ot_erwt_ao_hbr01
,sum(OT_ERWT_AO_B02) as kr_ot_erwt_ao_hbr02
,sum(OT_ERWT_AO_B03) as kr_ot_erwt_ao_hbr03
,sum(OT_ERWT_AO_B04) as kr_ot_erwt_ao_hbr04
,sum(OT_ERWT_AO_B05) as kr_ot_erwt_ao_hbr05
,sum(OT_ERWT_AO_B06) as kr_ot_erwt_ao_hbr06
,sum(OT_ERWT_AO_B07) as kr_ot_erwt_ao_hbr07
,sum(OT_ERWT_AO_B99) as kr_ot_erwt_ao_hbr99
,count(*) as kr_anz_ot
from eich1
group by ags5;
quit;  

	proc contents data=eich2;
	run;
	proc means data=eich2 n nmiss min mean max;
	var OT_ERWT_AO_B01-OT_ERWT_AO_B07 OT_ERWT_AO_B99 OT_ERWT_AO;
	run;

data eich3;
set eich2;
OT_ERWT_AO_B01_n = OT_ERWT_AO_B01*(KR_ERWT_BR1/kr_ot_erwt_ao_hbr01);
OT_ERWT_AO_B02_n = OT_ERWT_AO_B02*(KR_ERWT_BR2/kr_ot_erwt_ao_hbr02);
OT_ERWT_AO_B03_n = OT_ERWT_AO_B03*(KR_ERWT_BR3/kr_ot_erwt_ao_hbr03);
OT_ERWT_AO_B04_n = OT_ERWT_AO_B04*(KR_ERWT_BR4/kr_ot_erwt_ao_hbr04);
OT_ERWT_AO_B05_n = OT_ERWT_AO_B05*(KR_ERWT_BR5/kr_ot_erwt_ao_hbr05);
OT_ERWT_AO_B06_n = OT_ERWT_AO_B06*(KR_ERWT_BR6/kr_ot_erwt_ao_hbr06);
OT_ERWT_AO_B07_n = OT_ERWT_AO_B07*(KR_ERWT_BR7/kr_ot_erwt_ao_hbr07);
OT_ERWT_AO_B99_n = OT_ERWT_AO_B99;
OT_ERWT_AO_n = OT_ERWT_AO*(KR_ERWT_GES/KR_OT_ERWT_AO);
if OT_ERWT_AO_B01_n = . then OT_ERWT_AO_B01_n = OT_ERWT_AO_B01;
if OT_ERWT_AO_B02_n = . then OT_ERWT_AO_B02_n = OT_ERWT_AO_B02;
if OT_ERWT_AO_B03_n = . then OT_ERWT_AO_B03_n = OT_ERWT_AO_B03;
if OT_ERWT_AO_B04_n = . then OT_ERWT_AO_B04_n = OT_ERWT_AO_B04;
if OT_ERWT_AO_B05_n = . then OT_ERWT_AO_B05_n = OT_ERWT_AO_B05;
if OT_ERWT_AO_B06_n = . then OT_ERWT_AO_B06_n = OT_ERWT_AO_B06;
if OT_ERWT_AO_B07_n = . then OT_ERWT_AO_B07_n = OT_ERWT_AO_B07;
if OT_ERWT_AO_B99_n = . then OT_ERWT_AO_B99_n = OT_ERWT_AO_B99;
if OT_ERWT_AO_n = . then OT_ERWT_AO_n = OT_ERWT_AO;
delta1 = OT_ERWT_AO_n - sum(of OT_ERWT_AO_B01_n--OT_ERWT_AO_B99_n);
run;

proc sql; create table eich3b
as select 
*
,sum(ot_erwt_ao_n) as kr_ot_erwt_ao_n
,sum(OT_ERWT_AO_B01_n) as kr_ot_erwt_ao_hbr01_n
,sum(OT_ERWT_AO_B02_n) as kr_ot_erwt_ao_hbr02_n
,sum(OT_ERWT_AO_B03_n) as kr_ot_erwt_ao_hbr03_n
,sum(OT_ERWT_AO_B04_n) as kr_ot_erwt_ao_hbr04_n
,sum(OT_ERWT_AO_B05_n) as kr_ot_erwt_ao_hbr05_n
,sum(OT_ERWT_AO_B06_n) as kr_ot_erwt_ao_hbr06_n
,sum(OT_ERWT_AO_B07_n) as kr_ot_erwt_ao_hbr07_n
,sum(OT_ERWT_AO_B99_n) as kr_ot_erwt_ao_hbr99_n
,count(*) as kr_anz_ot
from eich3
group by ags5;
quit; 

data eich3c 
/*(keep=ags11 OT_ERWT_AO_B01-OT_ERWT_AO_B09 OT_ERWT_AO_B99 OT_ERWT_AO
OT_ERWT_AO_B01-OT_ERWT_AO_B09 OT_ERWT_AO_B99 OT_ERWT_AO
diff_kr_n: delta1)*/;
set eich3b;
diff_kr_n = kr_ot_erwt_ao_n - KR_ERWT_GES;
diff_kr_n_1 = kr_ot_erwt_ao_hbr01_n - KR_ERWT_BR1;
diff_kr_n_2 = kr_ot_erwt_ao_hbr02_n - KR_ERWT_BR2;
diff_kr_n_3 = kr_ot_erwt_ao_hbr03_n - KR_ERWT_BR3;
diff_kr_n_4 = kr_ot_erwt_ao_hbr04_n - KR_ERWT_BR4;
diff_kr_n_5 = kr_ot_erwt_ao_hbr05_n - KR_ERWT_BR5;
diff_kr_n_6 = kr_ot_erwt_ao_hbr06_n - KR_ERWT_BR6;
diff_kr_n_7 = kr_ot_erwt_ao_hbr07_n - KR_ERWT_BR7;
run;

	proc means data=eich3c n nmiss min mean max;
	var diff_kr_n: OT_ERWT_AO_B01_n--OT_ERWT_AO_n delta1;
	run;

data eich4;
set eich3b
(keep=
ags11
ags5
ot_erwt_ao_n
ot_erwt_ao_b01_n
ot_erwt_ao_b02_n
ot_erwt_ao_b03_n
ot_erwt_ao_b04_n
ot_erwt_ao_b05_n
ot_erwt_ao_b06_n
ot_erwt_ao_b07_n
ot_erwt_ao_b99_n
KR_ERWT_GES
KR_ERWT_BR1
KR_ERWT_BR2
KR_ERWT_BR3
KR_ERWT_BR4
KR_ERWT_BR5
KR_ERWT_BR6
KR_ERWT_BR7
kr_ot_erwt_ao_n
kr_ot_erwt_ao_hbr01_n
kr_ot_erwt_ao_hbr02_n
kr_ot_erwt_ao_hbr03_n
kr_ot_erwt_ao_hbr04_n
kr_ot_erwt_ao_hbr05_n
kr_ot_erwt_ao_hbr06_n
kr_ot_erwt_ao_hbr07_n
kr_ot_erwt_ao_hbr99_n
);
diff_old_ges = kr_ot_erwt_ao_n - KR_ERWT_GES;
diff_old_b01 = kr_ot_erwt_ao_hbr01_n - KR_ERWT_BR1;
diff_old_b02 = kr_ot_erwt_ao_hbr01_n - KR_ERWT_BR1;
diff_old_b03 = kr_ot_erwt_ao_hbr01_n - KR_ERWT_BR1;
diff_old_b04 = kr_ot_erwt_ao_hbr01_n - KR_ERWT_BR1;
diff_old_b05 = kr_ot_erwt_ao_hbr01_n - KR_ERWT_BR1;
diff_old_b06 = kr_ot_erwt_ao_hbr01_n - KR_ERWT_BR1;
diff_old_b07 = kr_ot_erwt_ao_hbr01_n - KR_ERWT_BR1;
delta_old = ot_erwt_ao_n - sum(of
ot_erwt_ao_b01_n
ot_erwt_ao_b02_n
ot_erwt_ao_b03_n
ot_erwt_ao_b04_n
ot_erwt_ao_b05_n
ot_erwt_ao_b06_n
ot_erwt_ao_b07_n
ot_erwt_ao_b99_n);
ot_erwt_ao_fin = ot_erwt_ao_n;
ot_erwt_ao_b01_fin = ot_erwt_ao_b01_n;
ot_erwt_ao_b02_fin = ot_erwt_ao_b02_n;
ot_erwt_ao_b03_fin = ot_erwt_ao_b03_n;
ot_erwt_ao_b04_fin = ot_erwt_ao_b04_n;
ot_erwt_ao_b05_fin = ot_erwt_ao_b05_n;
ot_erwt_ao_b06_fin = ot_erwt_ao_b06_n;
ot_erwt_ao_b07_fin = ot_erwt_ao_b07_n;
ot_erwt_ao_b99_fin = ot_erwt_ao_b99_n;
ot_erwt_ao_fin = sum(of 
ot_erwt_ao_b01_fin
ot_erwt_ao_b02_fin
ot_erwt_ao_b03_fin
ot_erwt_ao_b04_fin
ot_erwt_ao_b05_fin
ot_erwt_ao_b06_fin
ot_erwt_ao_b07_fin
ot_erwt_ao_b99_fin);
run;

proc sql;
create table eich5
as select 
*
,sum(ot_erwt_ao_fin) as kr_ot_erwt_ao_fin
,sum(OT_ERWT_AO_B01_fin) as kr_ot_erwt_ao_hbr01_fin
,sum(OT_ERWT_AO_B02_fin) as kr_ot_erwt_ao_hbr02_fin
,sum(OT_ERWT_AO_B03_fin) as kr_ot_erwt_ao_hbr03_fin
,sum(OT_ERWT_AO_B04_fin) as kr_ot_erwt_ao_hbr04_fin
,sum(OT_ERWT_AO_B05_fin) as kr_ot_erwt_ao_hbr05_fin
,sum(OT_ERWT_AO_B06_fin) as kr_ot_erwt_ao_hbr06_fin
,sum(OT_ERWT_AO_B07_fin) as kr_ot_erwt_ao_hbr07_fin
,sum(OT_ERWT_AO_B99_fin) as kr_ot_erwt_ao_hbr99_fin
,count(*) as kr_anz_ot
from eich4
group by ags5;
quit;

data eich6;
set eich5;
diff_new_ges = kr_ot_erwt_ao_fin - KR_ERWT_GES;
diff_new_b01 = kr_ot_erwt_ao_hbr01_fin - KR_ERWT_BR1;
diff_new_b02 = kr_ot_erwt_ao_hbr01_fin - KR_ERWT_BR1;
diff_new_b03 = kr_ot_erwt_ao_hbr01_fin - KR_ERWT_BR1;
diff_new_b04 = kr_ot_erwt_ao_hbr01_fin - KR_ERWT_BR1;
diff_new_b05 = kr_ot_erwt_ao_hbr01_fin - KR_ERWT_BR1;
diff_new_b06 = kr_ot_erwt_ao_hbr01_fin - KR_ERWT_BR1;
diff_new_b07 = kr_ot_erwt_ao_hbr01_fin - KR_ERWT_BR1;
delta_new = ot_erwt_ao_fin - sum(of
ot_erwt_ao_b01_fin
ot_erwt_ao_b02_fin
ot_erwt_ao_b03_fin
ot_erwt_ao_b04_fin
ot_erwt_ao_b05_fin
ot_erwt_ao_b06_fin
ot_erwt_ao_b07_fin
ot_erwt_ao_b99_fin);
run;

proc means data=eich6 n nmiss min mean max;
var diff: delta:
ot_erwt_ao_fin
ot_erwt_ao_b01_fin
ot_erwt_ao_b02_fin
ot_erwt_ao_b03_fin
ot_erwt_ao_b04_fin
ot_erwt_ao_b05_fin
ot_erwt_ao_b06_fin
ot_erwt_ao_b07_fin
ot_erwt_ao_b99_fin;
run;

/* das sollte hinfälig werden?!
data eich4;
set eich3;
ant_B08 = OT_ERWT_AO_B08_n/sum(of OT_ERWT_AO_B08_n OT_ERWT_AO_B09_n OT_ERWT_AO_B99_n);
ant_B09 = OT_ERWT_AO_B09_n/sum(of OT_ERWT_AO_B08_n OT_ERWT_AO_B09_n OT_ERWT_AO_B99_n);
ant_B99 = OT_ERWT_AO_B99_n/sum(of OT_ERWT_AO_B08_n OT_ERWT_AO_B09_n OT_ERWT_AO_B99_n);
OT_ERWT_AO_B08_n = OT_ERWT_AO_B08_n + (delta1*ant_B08);
OT_ERWT_AO_B09_n = OT_ERWT_AO_B09_n + (delta1*ant_B09);
OT_ERWT_AO_B99_n = OT_ERWT_AO_B99_n + (delta1*ant_B99);
delta2 = OT_ERWT_AO_n - sum(of OT_ERWT_AO_B01_n--OT_ERWT_AO_B99_n);
run;
*/

data eich7; set eich6;
SUMME = sum(of 
OT_ERWT_AO_B01_fin OT_ERWT_AO_B02_fin OT_ERWT_AO_B03_fin OT_ERWT_AO_B04_fin
OT_ERWT_AO_B05_fin OT_ERWT_AO_B06_fin OT_ERWT_AO_B07_fin OT_ERWT_AO_B99_fin);

if SUMME = 0 then do;
	OT_ERWT_AO_fin		= .;
	OT_ERWT_AO_B01_fin	= .;
	OT_ERWT_AO_B02_fin	= .;
	OT_ERWT_AO_B03_fin	= .;
	OT_ERWT_AO_B04_fin	= .;
	OT_ERWT_AO_B05_fin	= .;
	OT_ERWT_AO_B06_fin	= .;
	OT_ERWT_AO_B07_fin	= .;
	OT_ERWT_AO_B99_fin	= .;
	marke = 1;
end;
run;

		data check; set eich7;
		where marke = 1;
		run; 
		* keine Fälle angepasst, 
		wenn Fälle vorhanden sollten es möglichst auch wenige sein!;;

******;;

data FINAL (keep=ags11 
OT_ERWT_AO_B01
OT_ERWT_AO_B02
OT_ERWT_AO_B03
OT_ERWT_AO_B04
OT_ERWT_AO_B05
OT_ERWT_AO_B06
OT_ERWT_AO_B07
OT_ERWT_AO_B99
OT_ERWT_AO); 
set eich7;
OT_ERWT_AO_B01 = round(OT_ERWT_AO_B01_fin);
OT_ERWT_AO_B02 = round(OT_ERWT_AO_B02_fin);
OT_ERWT_AO_B03 = round(OT_ERWT_AO_B03_fin);
OT_ERWT_AO_B04 = round(OT_ERWT_AO_B04_fin);
OT_ERWT_AO_B05 = round(OT_ERWT_AO_B05_fin);
OT_ERWT_AO_B06 = round(OT_ERWT_AO_B06_fin);
OT_ERWT_AO_B07 = round(OT_ERWT_AO_B07_fin);
OT_ERWT_AO_B99 = round(OT_ERWT_AO_B99_fin);
OT_ERWT_AO = round(OT_ERWT_AO_fin);
run;

* Entstanden Rundungsdifferenzen?!;
data chk1;
set FINAL;
delta = ot_erwt_ao - sum (of
OT_ERWT_AO_B01
OT_ERWT_AO_B02
OT_ERWT_AO_B03
OT_ERWT_AO_B04
OT_ERWT_AO_B05
OT_ERWT_AO_B06
OT_ERWT_AO_B07
OT_ERWT_AO_B99);
run;

proc means data=chk1 n nmiss min mean max;
var delta;
run;

* Rundungsdifferenzen auf BR99 drauf rechenn;;
data FINAL2;
set chk1;
if delta not in (0,.) then OT_ERWT_AO_B99 = OT_ERWT_AO_B99 + delta;
run;

* negative Werte entstanden?;
proc freq data=FINAL2;
tables OT_ERWT_AO_B99;
run;

* Bei BR07 werden die negatien Fälle aus BR99 ausgelichen wenn BR07 groß genug;;
data FINAL3;
set FINAL2;
if OT_ERWT_AO_B99 < 0 and OT_ERWT_AO_B99 ne . then do;
/* Define an array with the variables to be compared */
    array values[*] 
	OT_ERWT_AO_B01
	OT_ERWT_AO_B02
	OT_ERWT_AO_B03
	OT_ERWT_AO_B04
	OT_ERWT_AO_B05
	OT_ERWT_AO_B06
	OT_ERWT_AO_B07;

    /* Loop through the array to find the highest value and its index */
    do i = 1 to dim(values);
        if values[i] > max_value then do;
            max_value = values[i];
            max_index = i;
        end;
    end;

    /* Adjust the value in the column with the highest value */
    if max_index ne . then values[max_index] = values[max_index] + OT_ERWT_AO_B99;
	OT_ERWT_AO_B99 = 0; 
end;
run;

data chk2;
set FINAL3;
delta2 = ot_erwt_ao - sum (of
OT_ERWT_AO_B01
OT_ERWT_AO_B02
OT_ERWT_AO_B03
OT_ERWT_AO_B04
OT_ERWT_AO_B05
OT_ERWT_AO_B06
OT_ERWT_AO_B07
OT_ERWT_AO_B99);
run;

proc means data=chk2 n nmiss min mean max;
var delta2
OT_ERWT_AO_B01
OT_ERWT_AO_B02
OT_ERWT_AO_B03
OT_ERWT_AO_B04
OT_ERWT_AO_B05
OT_ERWT_AO_B06
OT_ERWT_AO_B07
OT_ERWT_AO_B99;
run;

data final4; set final3; 
drop delta i max_value max_index; 
run;

%sas_to_pg
(from= FINAL4
,to= z_ags11_vie_0625_erwt_ao_b
,server= 172.30.30.114
,port= 5432
,uid= %SUBSTR(&_CLIENTUSERID.,2,%EVAL(%LENGTH(&_CLIENTUSERID.)-2))
,pwd= &_PWD.
,database= prod
,schema= sas_dbupdate
,pk= ags11);



*****			CHECKS;;
**	Anspielen der Kreisdaten;;
data ert_00; set FINAL3;
ags5 = substr(ags11,1,5);
run;

data ert_01;
set ert_00;
delta = ot_erwt_ao - sum (of
OT_ERWT_AO_B01
OT_ERWT_AO_B02
OT_ERWT_AO_B03
OT_ERWT_AO_B04
OT_ERWT_AO_B05
OT_ERWT_AO_B06
OT_ERWT_AO_B07
OT_ERWT_AO_B99);
run;

proc means data=ert_01 n nmiss min mean max;
var delta;
run;

proc sql; create table ERT_kr_00
as select 
ags5
,sum(ot_erwt_ao) as kr_ot_erwt_ao
,sum(OT_ERWT_AO_B01) as kr_ot_erwt_ao_hbr01
,sum(OT_ERWT_AO_B02) as kr_ot_erwt_ao_hbr02
,sum(OT_ERWT_AO_B03) as kr_ot_erwt_ao_hbr03
,sum(OT_ERWT_AO_B04) as kr_ot_erwt_ao_hbr04
,sum(OT_ERWT_AO_B05) as kr_ot_erwt_ao_hbr05
,sum(OT_ERWT_AO_B06) as kr_ot_erwt_ao_hbr06
,sum(OT_ERWT_AO_B07) as kr_ot_erwt_ao_hbr07
,sum(OT_ERWT_AO_B99) as kr_ot_erwt_ao_hbr99
,count(*) as kr_anz_ot
from ert_00
group by ags5;
quit; 

proc sql; create table checks_01
as select
 a.*
,b.*
from ERT_kr_00		as a
left join KR_02    as b on a.ags5 = b.ags5;
quit;

data checks_01; set checks_01;
d0=KR_ERWT_GES-kr_ot_erwt_ao;
d0r=KR_ERWT_GES/kr_ot_erwt_ao;
d1=round(KR_ERWT_BR1/kr_ot_erwt_ao_hbr01,.1);
d2=round(KR_ERWT_BR2/kr_ot_erwt_ao_hbr02,.1);
d3=round(KR_ERWT_BR3/kr_ot_erwt_ao_hbr03,.1);
d4=round(KR_ERWT_BR4/kr_ot_erwt_ao_hbr04,.1);
d5=round(KR_ERWT_BR5/kr_ot_erwt_ao_hbr05,.1);
d6=round(KR_ERWT_BR6/kr_ot_erwt_ao_hbr06,.1);
d7=round(KR_ERWT_BR7/kr_ot_erwt_ao_hbr07,.1);
run;

	proc means data=checks_01 min max mean maxdec=2;
	var d0--d7;
	run;

	proc freq data=checks_01;
	tables d0--d7;
	run;

******* (im nächsten Update vermutlich nicht direkt nötig) PAGS24: Unstimmigkeiten beim Check aufgefallen, anschauen:;;

libname besch "/mnt/u/Mikrodaten/Beschäftigte/Datensätze/PAGS2024";

proc sql;
create table match1
as select
a.ags11, a.ags5,
b.*,
d.ot_selbst,
e.ot_be_ao,
f.*
from pg_prod.ags11 (keep=ags11 ags5
	schema=variablen2024) a
left join pg_prod.z_ags11_soh_0506_erwt_ao_b
	(schema=sas_dbupdate) b on a.ags11=b.ags11
left join besch.ot_selbst d on a.ags11=d.ags11
left join besch.ot_be_ao e on a.ags11=e.ags11
left join KR_02 f on a.ags5=f.ags5;
quit;

data tst1 (where=(diff1 < 0 and diff1 ne .));
set match1;
sum1 = sum(of ot_be_ao ot_mithfam ot_selbst);
diff1 = ot_erwt_ao - sum1;
run; *226 Fälle;;

proc sql;
create table tst2
as select ags5, count(*) as anz_ots
from tst1
group by ags5;
quit; *3 Kreise;;

data tst3;
set match1;
where ags5 in ('13003', '13004', '16063');
sum1 = sum(of ot_be_ao ot_mithfam ot_selbst);
diff1 = ot_erwt_ao - sum1;
if diff1 < 0 and diff1 ne . then mark = 1;
else mark = 0;
run; *278 Fälle;

proc freq data=tst3;
tables mark;
run;

proc sql;
create table tst4
as select
ags5, count(*) as anz_ots, sum(mark) as sum_mark,
sum(ot_erwt_ao) as kr_erwt_ao,
kr_erwt_ges,
sum(ot_be_ao) as kr_be_ao,
sum(ot_mithfam) as kr_mithfam,
sum(ot_selbst) as kr_selbst,
sum(sum1) as kr_sum1,
sum(diff1) as kr_diff1
from tst3
group by ags5, kr_erwt_ges;
quit;

proc sql;
create table tst5
as select
a.*,
b.kr_be_ao_ges
from tst4 a
left join KR_BESCH_AO_2022 b
on a.ags5=b.ags5;
quit;

proc export data=tst5
outfile="/mnt/u/Mikrodaten/Beschäftigte/Datensätze/PAGS2024/chk_alo.xlsx"
dbms=xlsx replace;
run;
