
*Selbständige insgesamt (einschl. mithelfende Fam.angehörige)

Datum: 17.06.2025 - ViE
Datum: 25.03.2024 	Bearbeiter: SoH
Datum: 30.06.2023	Bearbeiter: RE
Datum: Juli 2022	Bearbeiter: SE


Benötigte Input Variablen:

- Beschäftigtenanzahl von Bedirect (früher Quadress, davor Bisnode)
- Neu in PAGS25: Selbständige auf Kreisebene vom Amt inkl. mithelf. Angehörige
--> keine Unterscheidung mehr zwischen Selbstständigen und deren mithelf. Angehörigen, d.h. 
ot_mithfam wird gedropt (d.h. einiges an Skript aus den Vorjahren wird gelöscht, da nicht mehr benötigt)
- aktuelle Zahlen auf Bundesland zum Eichen


Vorgehen:

Die Anzahl der Selbständigen vom Amt auf Kreisebene wird über je Wirtschaftszweig verteilt
und anschließend auf Ortsteil aggregiert. Die Zahl gibt somit die Selbständigen am Arbeitsort an (inklusive 
mithelfenden Familienangehörigen).
(Quelle: DIW, destatis)

Die stärkere Gewichtung vom Dienstleistungssektor wird ersetzt durch Differenzierung nach Wirtschaftszweigen;

*----------------------------------------------------------;

*früher wurde folgende Tabelle genutzt:
U:\Marktdaten\Amtliche Daten\3_Arbeitsmarkt\Aufbereitet\2005-2012\KR_Erwerbstätige_Kreis_2011.csv
;



libname BESCH "/mnt/sachdaten/Mikrodaten/Beschäftigte/Datensätze/PAGS2025/";


*Tabellen ins Work ziehen;

*Kreisdaten (leider noch von 2022); 
data kreis; set pg_proc.kr_selbst_2022 (schema=roh_genesis); run;*400;

*Firmendaten;
data _Firmen; set pg_prod.bedirect_vie_20250409 (schema=bedirect);
keep ags27 ags20 ags11 ags8 ags5 mitarbeiter_real mitarbeiter_staffel: br_abt_hptcode br_absch_hptcode; 
run;
/*4.717.215*/

* IMPUTATION fehlender Mitarbeiterzahlen in der kleinsten Staffelgröße (1-4 MA)

* Häufigkeit der Fälle mit 1, 2, 3 oder 4 Mitarbeitern; 
proc freq data=_firmen; 
table mitarbeiter_real; 
where mitarbeiter_staffel = '01'; 
run;
*
1
1471379 61.68 1471379 61.68 
2
509378 21.35 1980757 83.03 
3
247312 10.37 2228069 93.40 
4
157531 6.60 
;

*Beschäftigte im Dienstleistungssektor;
data S1; set _Firmen;
* Einordnung in Wirtschaftszweige; 
if br_absch_hptcode = 1							then br_code=1; *(A) Land-, Forstwirtschaft und Fischerei;
if br_absch_hptcode in (2,4,5)					then br_code=2; *(B-E ohne C) Produzierendes Gewerbe ohne Baugwerbe und verarbeitendes Gewerbe;
if br_absch_hptcode = 3 						then br_code=3; *(C) Verarbeitendes Gewerbe;
if br_absch_hptcode = 6							then br_code=4; *(F) Baugewerbe;
if br_absch_hptcode in (7,8,9,10) 				then br_code=5; *Handel, Vekehr, Gastgewerbe, Information und Kommunikation;
if br_absch_hptcode in (11,12,13,14) 			then br_code=6; *Finanz-, Versicheruns-, Unternehemnsdienstleistungen, Grundstücks- und Wohnungswese;
if br_absch_hptcode in (15,16,17,18,19,20,21)  	then br_code=7; *Öffentliche und sonstige Dienstleistungen, Erziehung, Gesundheit;
if br_absch_hptcode=. 							then br_code=.;
run;

* Durchschnittliche Anzahl Mitarbeiter nach Branche und SB; 
proc sql; 
	create table S2
	as select 
	*, 
	mean(round(mitarbeiter_real)) as ma_br 
	from S1 
	group by ags20, br_code; 
quit;



* Anpassungen;
data S3; set S2; 
* Beschäftigten-Zahl;
besch = mitarbeiter_real; 
* Missings mit Durchschnittswerten ersetzen;
if mitarbeiter_real = . and ma_br ^= . then besch = round(ma_br); 

* Dummy für Firmen mit geringer Anzahl Mitarbeitenden;
if  1 <= besch <= 4 then kleinst = 1; else kleinst = 0; 

if ags27 NE '';
run;
*4.651.386;

proc freq data=S3;
tables kleinst;
run;


*----------------------------------------------------------;
* Gesamtanzahl je Kreis und Branche; 
proc sql; create table S4
as select ags20, ags11, ags5, 
sum(case when br_code = 1 then besch else 0 end) as br1_anz,
sum(case when br_code = 2 then besch else 0 end) as br2_anz,
sum(case when br_code = 3 then besch else 0 end) as br3_anz,
sum(case when br_code = 4 then besch else 0 end) as br4_anz,
sum(case when br_code = 5 then besch else 0 end) as br5_anz,
sum(case when br_code = 6 then besch else 0 end) as br6_anz,
sum(case when br_code = 7 then besch else 0 end) as br7_anz,
sum(besch) as ags20_besch
from S3
group by AGS20;
quit;

* Dopplungen raus; 
proc sort data=S4; 
by ags20; 
data S5; set S4; 
by ags20; 
if last.ags20 then output s5; 
run;*1.241.513;


* Kreisdaten anspielen; 
proc sql; 
	create table S6
	as select 
	a.*, b.* 
	from S5 as a
	left join kreis as b 
	on a.ags5=b.ags5; 
quit;


* Aggregieren auf Kreisebene; 
proc sql; 
	create table S7
	as select 
	*, 
	sum(br1_anz) as br1_kr,
	sum(br2_anz) as br2_kr,
	sum(br3_anz) as br3_kr,
	sum(br4_anz) as br4_kr,
	sum(br5_anz) as br5_kr,
	sum(br6_anz) as br6_kr,
	sum(br7_anz) as br7_kr, 
	sum(ags20_besch) as ags5_besch
	from S6 
	group by ags5; 
quit;

* Eichen an Kreisdaten; 
data S8; set S7; 
br1_geeicht = round((br1_anz/br1_kr) * kr_selbst_br1);
br2_geeicht = round((br2_anz/br2_kr) * kr_selbst_br2);
br3_geeicht = round((br3_anz/br3_kr) * kr_selbst_br3);
br4_geeicht = round((br4_anz/br4_kr) * kr_selbst_br4);
br5_geeicht = round((br5_anz/br5_kr) * kr_selbst_br5);
br6_geeicht = round((br6_anz/br6_kr) * kr_selbst_br6);
br7_geeicht = round((br7_anz/br7_kr) * kr_selbst_br7);

sb_selbst = sum(of br1_geeicht--br7_geeicht);
run;

proc means data=s8 sum; 
var sb_selbst br1_geeicht--br7_geeicht; 
run;



* Prüfung (ohne Differenzierung bei Branchen);
	proc sql; create table test
	as select AGS5, kr_selbst,
	sum(sb_selbst) as erwerb_selb
	from S8
	group by AGS5, kr_selbst;
	quit;
	data test; set test;
	delta = erwerb_selb - kr_selbst;
	delta_rel = round(erwerb_selb / kr_selbst,0.001);
	run;
	proc sort data=test out=A;
	by delta;
	where delta ne .;
	run;
	proc sort data=test out=B;
	by delta_rel;
	where delta_rel ne .;
	run;
	proc means data=test sum;
	var erwerb_selb;
	run;
	*Zahl gesamt: 3.984.981.00;

	proc sql; create table tst1
	as select 
	ags5,
	kr_selbst,
	count(*) as anz
	from S8
	group by ags5, kr_selbst;
	quit;
	proc means data=tst1 sum;
	var kr_selbst;
	run;
	*3.908.700 - 82k Fehlen also zuviel verteilt;




*Differenz nochmal verteilen;
proc sql; 
	create table P1
	as select AGS5, AGS11, AGS20, SB_selbst, KR_selbst,
	sum(sb_selbst) as ags5_selbst
	from S8
	group by AGS5;
quit;

data P2; set P1;
delta = KR_selbst - ags5_selbst;

if ags5_selbst NE 0 then sb_selbst_2 = sb_selbst/ags5_selbst*delta;
if ags5_selbst = 0 then sb_selbst_2 = 0;

sb_selbst_neu=round(sum (of sb_selbst sb_selbst_2)) ;

run;

proc sql; create table test
as select sum(sb_selbst_neu) as ags5_selbst
from P2;
quit;
*Neue Zahl: 3.933.324 (noch 25k zuv iel);



*Zweite Runde: Differenz nochmal verteilen;
proc sql; 
	create table P3
	as select AGS5, AGS11, AGS20, SB_selbst_neu, KR_selbst,
	sum(sb_selbst_neu) as ags5_selbst
	from P2
	group by AGS5;
quit;

data P4; set P3;
delta = KR_selbst - ags5_selbst;

if ags5_selbst NE 0 then sb_selbst_2 = SB_selbst_neu/ags5_selbst*delta;
if ags5_selbst = 0 then sb_selbst_2 = 0;

sb_selbst=round(sum (of sb_selbst_neu sb_selbst_2)) ;

run;

proc sql; create table test
as select sum(sb_selbst) as ags5_selbst
from P4;
quit; *3.922.752 -> kann so bleiben; 
***********************************************************************************************;;



**************************;;

*Abspeichern in Ordner;;

*Auf SB;
data BESCH.SB_SELBST; set P4 (keep=ags20 sb_selbst_neu);
if ags20 NE '';
run;
*1.241.513;


*Auf OT;
proc sql; create table BESCH.OT_SELBST
as select AGS11,
sum(sb_selbst) as ot_selbst
from P4
where ags11 NE ''
group by AGS11;
quit;
*61.336;



