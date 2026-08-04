
*
Datum: 12.06.2025 - ViE -> mit Änderungen, s.u.!
Datum: 19.03.2024 Bearbeiter: SoH
Datum: 07.07.2023 Bearbeiter: RE
Datum: 05.07.2022 Bearbeiter: RE



Sozialversicherungspflichtige Beschäftigte, insgesamt (am Arbeitsort)



Benötigte Input Variablen:

- Beschäftigtenanzahl von Bedirect
- Sozialvers.pflichtig Beschäftigte am Arbeitsort auf Gemeinde- und Kreisebene vom Amt


Vorgehen:

Die Anzahl der SvB am Arbeitsort vom Amt auf Gemeinde-und Kreisebene wird über
die Anzahl der Beschäftigten auf die Ortsteile verteilt.

Änderungen von PAGS25: 
- in den letzten zwei Jahren wurden Vorjahreswerte übertragen, jetzt wird neu berechnet
- hierzu Orientierung am Skript vom PAGS22
- Hintergrund: neue Firmendaten (von Bedirect), die wieder absolute Mitarbeiterzahlen ausgeben




*----------------------------------------------------------;

*Daten einlesen:

Kreisdaten einlesen:
U:\Marktdaten\Amtliche Daten\3_Arbeitsmarkt\Aufbereitet\2021\KR_besch_AO_2022.csv
;
* Ab PAGS25 in Datenbank;
data AMT_KR; set pg_proc.KR_besch_AO_2023 (schema=roh_genesis); run; /*400*/

*Gemeindedaten einlesen - Ab PAGS25 in Datenbank
U:\Marktdaten\Amtliche Daten\3_Arbeitsmarkt\Aufbereitet\2022\GEM_BESCH_AO_2022.csv
und U:\Marktdaten\Amtliche Daten\1_Demographie\Aufbereitet\2022\GEM_BEV_2022.csv
bzw. benötigte Variablen direktzusammen aus Tabelle, in der Schlüssel schon an unseren Pags angepasst wurden, 
wenn schon verfügbar, siehe auskommentierter libname vom PAGS23 Update;;

/*libname amt '/mnt/u/Marktdaten/Amtliche Daten/Datasets/PAGS23_Stand2021';*/

proc sql;
	create table AMT_GEM
	as select
	a.ags8,a.gemeindename,
	b.gem_ew_anz,
	c.gem_be_ao as GEM_be_ao_ges
	from pg_prod.ags8 (schema=variablen2025 keep=ags8 gemeindename) as a
	left join pg_proc.GEM_BEV_2023 (schema=roh_genesis)  as b on a.ags8=b.ags8
	left join pg_proc.GEM_BESCH_AO_2023 (schema=roh_genesis) as c on a.ags8=c.ags8;
quit;

data AMT_GEM;
set AMT_GEM;
if GEM_be_ao_ges = . and gem_ew_anz not in (0,.) then miss=1;
run;
/*2025: 10978, davon haben 1.375 keine Beschäftigten, obwohl Einwohner*/
/*2024: 10990, davon haben 1.319 keine Beschäftigten, obwohl Einwohner*/

*Beschäftigte von Gemeinde auf Kreis aggregieren (amtliche Daten);
PROC SQL;
	create table AMT_GEM_AGS5
	as select min(substr(AGS8,1,5)) as AGS5,
	sum(GEM_be_ao_ges) as GEM_be_ao_AGS5,
	sum(miss) as GEM_be_ao_miss,
	count(*) as anz_GEM
	from AMT_GEM
	group by substr(AGS8,1,5);
quit;
*400;



* ----- FIRMEN -----
* Firmendaten einlesen; 
data firmen; set pg_prod.bedirect_vie_20250409 (schema=bedirect); 
keep ags27 ags11 ags8 ags5 mitarbeiter_real; Run; *4.717.215; 

* Firmendaten aggregieren auf OT-Ebene;
proc sql; 
	create table firmen2 
	as select 
	ags5, ags8, ags11,  
	sum(mitarbeiter_real) as beschäftigte, 
	count(*) as anz
	from Firmen
	where ags11 ^= ''
	group by ags5,ags8,ags11; 
quit; *61.501;

* Firmendaten aggregieren auf Gemeinde-Ebene;
proc sql; 
	create table firmen3 
	as select 
	*,   
	sum(beschäftigte) as beschäftigte_ags8
	from Firmen2
	group by ags8; 
quit; *61.501;


* Firmendaten aggregieren auf Kreis-Ebene;
proc sql; 
	create table firmen4 
	as select 
	*,    
	sum(beschäftigte) as beschäftigte_ags5 
	from Firmen3
	group by ags5; 
quit; *400;





* ----- POIs -----
*POIs einlesen;
data POI; set pg_prod.AGS27_CASA_POI (schema=variablen2025 keep=AGS27 CASA_POI_:);
	sumPOI = sum(of CASA_POI_:);
	if sumPOI = . then sumPOI = 0;
	ags11=substr(ags27,1,11);
	ags8=substr(ags27,1,8);
	ags5=substr(ags27,1,5);
run;

*POIs auf OT aggregieren;
proc sql; 
	create table POI_AGS11
	as select AGS11,
	sum(sumPOI) as OT_POI
	from POI
	group by AGS11;
quit; /*64811*/

*POIs auf Gemeinde aggregieren;
proc sql; 
	create table POI_AGS8
	as select AGS8,
	sum(sumPOI) as GEM_POI
	from POI
	group by AGS8;
quit; /*10840*/

*POIs auf Kreis aggregieren;
proc sql; 
	create table POI_AGS5
	as select AGS5,
	sum(sumPOI) as KR_POI
	from POI
	group by AGS5;
quit; /*400*/



* ----- MERGEN -----
*Daten zusammenspielen;
proc sql;
create table AO1
as select
a.*,
b.GEM_be_ao_ges, b.gem_ew_anz, b.Gemeindename,
c.GEM_be_ao_AGS5, c.GEM_be_ao_miss, c.anz_gem,
d.KR_be_ao as KR_be_ao_ges,
e.OT_POI,
f.GEM_POI,
g.KR_POI
from Firmen4 as a
left join AMT_GEM as b on a.AGS8=b.AGS8
left join AMT_GEM_AGS5 as c on a.AGS5=c.AGS5
left join work.AMT_KR as d on a.AGS5=d.AGS5
left join POI_AGS11 as e on a.AGS11=e.AGS11
left join POI_AGS8 as f on a.AGS8=f.AGS8
left join POI_AGS5 as G on a.AGS5=g.AGS5;
quit; /*64897*/

*Differenz Beschäftigte Gemeinde und Kreis berechnen;
data AO2; set AO1;
GEM_be_ao_delta=KR_be_ao_ges-GEM_be_ao_AGS5;
run;

proc sort data=AO2 out=sort;
by GEM_be_ao_delta;
where GEM_be_ao_delta not in (0,.);
run; /*17.891*/

*Da Gemeindedaten nicht stimmig mit Kreisdaten, werden Gemeindedaten an Kreisdaten geeicht;;
proc sqL; create table AO2_2 (drop = anz)
as select
AGS5
,ags8
,GEM_BE_AO_GES
,GEM_be_ao_AGS5
,KR_be_ao_ges
,count(*) as ANZ
from AO2
group by AGS5, AGS8, GEM_BE_AO_GES, GEM_be_ao_AGS5, KR_be_ao_ges;
quit;

proc sql; create table AO2_3
as select *,
sum(GEM_BE_AO_GES) as GEM_be_ao_AGS5_alt
from AO2_2
group by AGS5;
quit;

data AO2_4; set AO2_3;
GEM_BE_AO_GES_neu = round((GEM_BE_AO_GES/GEM_be_ao_AGS5_alt)*KR_be_ao_ges);
run;

proc sql; create table AO2_5
as select *, sum(GEM_BE_AO_GES_neu) as GEM_be_ao_AGS5_neu
from AO2_4
group by AGS5;
quit;

proc sql; create table AO2n
as select 
 a.*
,b.GEM_BE_AO_GES_neu
,b.GEM_BE_AO_AGS5_neu
,a.KR_be_ao_ges-b.GEM_be_ao_AGS5_neu as GEM_be_ao_delta_neu
from AO2 as a
left join AO2_5	as b
on a.ags8 = b.ags8;
quit;

*Beschäftigte verteilen, wo Gemeindewerte nicht Missing sind;
data AO3; set AO2n;
OT_BESCH_AO=round((((Beschäftigte/Beschäftigte_AGS8) + (OT_POI/GEM_POI))* GEM_be_ao_ges)/2);
if OT_POI = . then OT_BESCH_AO=round(Beschäftigte/Beschäftigte_AGS8*GEM_be_ao_ges);
if GEM_be_ao_ges = 0 then OT_BESCH_AO = 0;
if OT_BESCH_AO = . then delete;
run; /*58.179*/

*Zahlen verteilen, wo Gemeindewerte Missing sind;
data AO4; set AO2;
if GEM_BE_AO_GES = .;
run; /*1895*/

*Mitarbeiter auf Kreis aggregieren;
PROC SQL;
create table AO5
as select AGS5, AGS8, AGS11, Beschäftigte, OT_POI, KR_be_ao_ges, GEM_be_ao_AGS5, GEM_be_ao_delta,
sum(Beschäftigte) as Beschäftigte_AGS5,
sum(OT_POI) as KR_POI
from AO4
group by AGS5;
run;

*Differenz zwischen Gemeinden und Kreis verteilen;
data AO6;
set AO5;
OT_BESCH_AO = round((((Beschäftigte/Beschäftigte_AGS5) + (OT_POI/KR_POI)) *GEM_be_ao_delta)/2);
if OT_POI = . then OT_BESCH_AO=round(Beschäftigte/Beschäftigte_AGS5*GEM_be_ao_delta);
if GEM_be_ao_delta=0 then OT_BESCH_AO=0;
if OT_BESCH_AO=. then delete;
run; /*1846*/

*Tabellen zusammenfügen;
data AO7;
set AO3 AO6;
run; /*60025*/

PROC SQL;
create table AO8
as select AGS5, AGS8, Gemeindename, AGS11, KR_be_ao_ges, GEM_be_ao_ges,
sum(Beschäftigte) as Beschäftigte_OT,
sum(OT_BESCH_AO) as OT_BESCH_AO,
count(*) as anz
from AO7
group by AGS11;
quit; /*60025*/

	*Beschäftigte von OT auf Gemeinde aggregieren und abgleichen mit amtlichen Werten;
	proc sql; create table test
	as select AGS8, Gemeindename, Gem_Be_ao_ges,
	sum(OT_BESCH_AO) as GEM_BESCH_AO
	from AO8
	group by AGS8, Gemeindename, GEM_be_ao_ges;
	quit;

	*delta;
	data test; set test;
	deltaGEM = GEM_be_ao_ges - GEM_BESCH_AO;
	run;

	proc freq data=test;
	tables deltaGEM;
	run;
	proc sort data=test;
	by deltaGEM;
	where deltaGEM not in (0,.);
	run; 
	*
	PAGS25: -443 bis +89 -> wieder Erhöhung der negativen Abweichung
	PAGS24: -157 bis +168 => deutlich höhere maximale negative Abweichungen als zuvor?!
	PAGS23: -8 bis +172
	;;
	
	*
	PAGS25: 34.851.136 BE_AO verteilt, Kreis Amt: 34.834.937
		-> 16k zu viel
	PAGS24: 34.444.364 BE_AO verteilt, Kreis Amt: 34.443.701
		-> etwas zu viel, daher eichen an Kreis (Wörth passt wieder perfekt)
	PAGS23: Insgesamt wurden 33.772.528 BE_AO verteilt, Kreis Amt: 3.380.0611
		-> zu wenig, daher eichen an Kreisdaten (Wörth passt perfekt (war vorher nicht so));
	PROC SQL;
	create table test
	as select 
	sum(OT_BESCH_AO) as OT_BESCH_AO
	from AO8;
	quit;
	proc sql;
	create table test
	as select
	sum(KR_be_ao) as KR_be_ao_ges
	from AMT_KR;
	quit;



*vor PAGS23: Werte für Wörth nochmal eichen an amtlicher Gemeindezahl;
proc sql;
create table AO9
as select *,
sum(OT_BESCH_AO) as OT_BESCH_AGS8_NEU
from AO8
group by AGS8;
quit;

data AO10;
set AO9;
OT_BESCH_AO_NEU = OT_BESCH_AO;
	/*
if AGS8='07334501' then OT_BESCH_AO_NEU = round(OT_BESCH_AO*GEM_be_ao_ges/OT_BESCH_AGS8_NEU);
	*/
run;

*Eichen an Werten auf Kreis;
proc sql;
create table AO11
as select *,
sum(OT_BESCH_AO_NEU) as OT_BESCH_AGS5
from AO10
group by AGS5;
quit;

data AO12;
set AO11;
OT_BESCH_AO_NEU2 = round(OT_BESCH_AO_NEU*KR_be_ao_ges/OT_BESCH_AGS5);
if OT_BESCH_AO_NEU = 0 then OT_BESCH_AO_NEU2 = 0;
run; /*60025*/

	PROC SQL;
	create table test
	as select AGS5,KR_be_ao_ges,
	sum(OT_BESCH_AO_NEU2) as OT_BESCH_AO
	from AO12
	group by AGS5, KR_be_ao_ges;
	quit;

	data test;
	set test;
	delta=round(KR_be_ao_ges-OT_BESCH_AO);
	run;
	proc sort data=test;
	by delta;
	proc freq data=test;
	tables delta;
	run; 
	*
	PAGS25: -60 bis +16
	PAGS24: -23 bis +31
	PAGS23: -10 bis 32
	;;
	proc means data=test min max n nmiss;
	run;

	*verteilt wurden: 34836939
	Besch_AO BRD: 34834937
	2002 zu viel 
	(PAGS24 518 zu viel, PAGS23 23173 zu wenig, PAGS22 1553 zu wenig, 
	PAGS21 3500 zu viel, PAGS20 1600 zu wenig)
	;
	PROC SQL;
	create table test
	as select 
	sum(OT_BESCH_AO_NEU2) as OT_BESCH_AO
	from AO12;
	quit;
	proc sql;
	create table test
	as select
	sum(KR_be_ao) as KR_be_ao_ges
	from AMT_KR;
	quit;

*Abspeichern in Ordner;
libname besch '/mnt/sachdaten/Mikrodaten/Beschäftigte/Datensätze/PAGS2025';

data besch.OT_BE_AO;
set AO12 (keep=AGS11 OT_BESCH_AO_NEU2);
rename OT_BESCH_AO_NEU2=ot_be_ao;
run; 

