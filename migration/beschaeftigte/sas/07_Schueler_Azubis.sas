
*Schüler und Azubis

Datum: 13.06.2025 - ViE 

Datum: 25.04.2022
Bearbeiter: SOH


Benötigte Input Variablen:

- Einwohner nach Altersklasse
- Schüler auf Kreisebene vom Amt
- Auszubildende auf Kreisebene vom Amt


Vorgehen:

Die Anzahl der Schüler auf Kreisebene wird über die Einwohnerzahl (6 bis unter 18 Jährige)
auf die Siedlungsblöcke verteilt und anschließend auf Ortsteil aggregiert.

Die Anzahl der Auszubildenden auf Kreisebene wird über die Einwohnerzahl (15 bis unter 30 Jährige)
auf die Siedlungsblöcke verteilt und anschließend auf Ortsteil aggregiert.

;

*----------------------------------------------------------;

libname besch "/mnt/sachdaten/Mikrodaten/Beschäftigte/Datensätze/PAGS2025";

*Match Altersstruktur und Daten auf Kreis;

*Amtliche Daten auf Kreisebene ziehen; 
data kr_schueler; set pg_proc.kr_schueler_2023 (schema=roh_genesis); run; 

	proc sql;
	create table chk_kr_sum
	as select sum(kr_schueler) as sum_schüler
	from KR_SCHUELER;
	quit; * 8.693.343 ;


* Einwohner ziehen;
data _SB_EW / view=_SB_EW; set pg_prod.mv_ags20 (schema=variablen2025
keep= AGS20 SB_EW_ANZ SB_EW_00U18_ANZ SB_EW_06U10_ANZ SB_EW_10U15_ANZ SB_EW_15U18_ANZ SB_EW_18U30_ANZ);
ags5 = substr(ags20,1,5);
run;

*Match Daten;
proc sql; create table A1a (where=(sb_ew_anz ne .))
as select
a.*,
b.kr_schueler as kr_schueler
from _SB_EW as a
left join KR_SCHUELER as b on a.AGS5=b.AGS5;
quit;
/*1.925.647*/

	proc sql;
	create table chk_kr1
	as select 
	distinct ags5
	from A1a (where=(kr_schueler=.));
	quit; *0;

*Schüler ausrechnen;
data A1; set A1a;
SB_EW_06U18_ANZ = sum(of SB_EW_06U10_ANZ SB_EW_10U15_ANZ SB_EW_15U18_ANZ);
run;

*Aufsummieren auf Kreis;
PROC SQL; create table A2a
as select *,
sum(SB_EW_06U18_ANZ) as AGS5_EW_06U18_ANZ
from A1
group by AGS5;
quit;

*Verteilen;
data A2b; set A2a;
if AGS5_EW_06U18_ANZ NE 0 then sb_schueler = (SB_EW_06U18_ANZ/AGS5_EW_06U18_ANZ)*kr_schueler;
if AGS5_EW_06U18_ANZ = 0 then sb_schueler = 0;
ags11=substr(ags20,1,11);
run;

*Zahlen anpassen, wenn zu hoch;
data A2; set A2b;
if SB_SCHUELER GT round(SB_EW_06U18_ANZ+SB_EW_06U18_ANZ*0.1) then do;
	SB_SCHUELER_2=round(SB_EW_06U18_ANZ+SB_EW_06U18_ANZ*0.1);
	mark = 1;
	end;

*Anteil, der sich auf die 18-29 Jährigen bezieht. Ist ok;
ant = (SB_SCHUELER_2 - SB_EW_06U18_ANZ)/SB_EW_18U30_ANZ;

if SB_SCHUELER_2 NE . then SB_SCHUELER = SB_SCHUELER_2;
run;

	proc freq data=A2;
	tables mark;
	run;
	*81513 Fälle werden so ersetzt;

data A3; set A2;
sb_schueler = round(SB_SCHUELER);
run;

*Gesamtzahl;;
PROC SQL; create table test1
as select sum(SB_SCHUELER) as SB_SCHUELER
from A3;
quit;
*8724172;
* Amt (Rohdatentabelle, siehe oben):  8.693.343




*------------------------------------------------------;
*PRÜFUNG;

data test; set A3;
delta = SB_EW_06U18_ANZ-SB_SCHUELER;
ant1 = SB_SCHUELER/SB_EW_06U18_ANZ;
ant = SB_SCHUELER/SB_EW_ANZ;
run;

data test2; set test;
if delta LT 0 and delta NE .;
run;
proc sort data=test2 (where=(delta LT 0 and delta NE .));
by delta;
run;
* 2025: Für 39.561 SB gibt es mehr Schüler als U18 Jährige,höchstens 39 mehr, was schlechter als in den Vorjahren 
ist, aber durch Zensus-Änderungen bei den Einwohnern letztlich erwartbar;
*Für 26.978 SB gibt es mehr Schüler als U18 Jährige, höchsten 46 mehr (besser als PAGS23);
*Für 30.416 SB gibt es mehr Schüler als U18 Jährige, (wieder) höchstens 45 mehr (besser als PAGS22);
*Für 31.867 SB gibt es mehr Schüler als U18 Jährige, (wieder) höchstens 45 mehr (besser als PAGS21);
*Für 34.131 SB gibt es mehr Schüler als U18 Jährige, höchstens 45 mehr (besser als PAGS20);

data test3; set test;
if ant1=1;
run;
proc sort data=test3;
by descending SB_SCHUELER;
run;
*2025: Für 685808 SB ist U18=Anzahl Schüler, mit höchstens 240 Schülern;
*Für 687159 SB ist U18=Anzahl Schüler, mit höchstens 325 Schülern;
*Für 717698 SB ist U18=Anzahl Schüler, mit höchstens 372 Schülern;
*Für 703514 SB ist U18=Anzahl Schüler, mit höchstens 372 Schülern;
*Für 695264 SB ist U18=Anzahl Schüler, mit höchstens 364 Schülern;

proc sort data=test out=test4 (keep=ags20 ant1 sb_schueler SB_EW_06U18_ANZ delta);
by descending sb_schueler;
where ant1 ^= . and (ant1 > 1 or ant1 < 0);
run;
proc means data=test4;
var ant1;
run;
*2025: 39561 SB mit Anteilen über 100%;
* 26978 SB mit Anteilen über 100%;
* 30416 SB mit Anteilen über 100%;
* 31867 SB mit Anteilen über 100%;

data test4; set test4;
_n = _n_;
run;
proc sgplot data=test4;
series x=_n y=delta;
xaxis grid;
yaxis grid;
run;
proc corr data=test4;
var delta ant1 sb_schueler;
run;
* Mit sinkender Schüleranzahl sinkt das Delta, 
aber die Abweichung über 100% steigt -> Summeneffekt;

*Abspeichern;
*Auf SB;
data besch.SB_SCHUELER;
set A3 (keep=ags20 sb_schueler);
run; /*1.925.647*/

proc sql;
create table besch.OT_SCHUELER
as select ags11,
sum(sb_schueler) as ot_Schueler
from A3
group by ags11;
quit; /*64378*/



*-----------------;

*AZUBIS;
 

* Amtliche Daten aus Datenbank ziehen;
data KR_INPUT; set pg_proc.kr_ausbildung_2023 (schema=roh_genesis); run;


	proc sql;
	create table chk_kr_sum
	as select sum(kr_azubi) as sum_azubis
	from KR_INPUT;
	quit; * 2255591 ;

*Daten einlesen;
proc sql; create table A1 (where=(sb_ew_anz ne .))
as select
a.*,
b.kr_azubi 
from _SB_EW as a
left join KR_INPUT as b on a.AGS5=b.AGS5;
quit; 
/*1.925.647*/
/*17.737 SB mit Missings (kr_azubi in (0,.))*/

* Check der missings;;
proc sql; create table test1
as select distinct(ags5)
from A1
where kr_azubi in (0,.);
quit;

data test2; set KR_INPUT;
where kr_azubi in (0,.)
and ags5 in ('09471','09473','09573','09671', '16068');
run; 
/* 5 Kreise mit Missings, passen aber zu den Rohdaten, vier davon waren schon in PAGS24 missing*/

*EW 15-30 berechnen;
data A1b; set A1;
SB_EW_15U30_ANZ = SB_EW_15U18_ANZ+SB_EW_18U30_ANZ;
if SB_EW_ANZ=. then delete;
run; 


*Aufsummieren auf Kreis;
proc sql; create table A2b
as select AGS5, AGS20, SB_EW_15U30_ANZ, KR_AZUBI,
sum(SB_EW_15U30_ANZ) as AGS5_EW_15U30_ANZ
from A1b
group by AGS5;
quit;

*Verteilen;
data A2; set A2b;
if AGS5_EW_15U30_ANZ NE 0 then SB_AZUBI = (SB_EW_15U30_ANZ/AGS5_EW_15U30_ANZ)*KR_AZUBI;
if AGS5_EW_15U30_ANZ = 0 then SB_AZUBI = 0;

delta = SB_EW_15U30_ANZ - SB_AZUBI;
ags11=substr(ags20,1,11);
run;

proc sql; create table test
as select sum(round(SB_AZUBI)) as AZUBI /*2166729*/
from A2;
quit;

proc sql; create table test2
as select
sum(kr_azubi) as AZUBI_AMT /*2255591*/
from KR_INPUT;
quit;

proc sql; create table A3
as select AGS5, AGS11, AGS20, SB_EW_15U30_ANZ, AGS5_EW_15U30_ANZ, SB_AZUBI, KR_AZUBI,
sum(round(SB_AZUBI)) as AGS5_AZUBI
from A2
group by AGS5;
quit;

data A3; set A3;
delta = KR_AZUBI-AGS5_AZUBI;
if delta < 1 and delta ^= . then mark = 1; 
if delta > 1 then mark = 2;  
if delta = 0 then mark = 3; 
run;

		proc freq data=a3; 
		table mark delta; 
		run; * PAGS25: Spannweite von -188 bis +1120;



* ANPASSUNGEN ;
data A3b; set A3;
if AGS5_AZUBI NE 0 then SB_AZUBI_2 = round((SB_AZUBI/AGS5_AZUBI)*delta);
if AGS5_AZUBI = 0 then SB_AZUBI_2 = 0;
SB_AZUBI_neu=round(sum(of SB_AZUBI SB_AZUBI_2));
ant=SB_AZUBI_neu/SB_EW_15U30_ANZ;
run;

	proc sql; create table test
	as select 
	sum(SB_AZUBI_neu) as SB_AZUBI /*2.214.151, von Amt war: 2.255.591*/
	from A3b;
	quit;

*Prüfen;
data test; set A3b;
if (SB_EW_15U30_ANZ-SB_AZUBI) LT 0 and SB_AZUBI_neu NE .;
run; /*nein*/*/;
data test; set A3b;
if SB_AZUBI_2=.;
run; /*17.737 mit Missing*/
proc sort data=test;
by descending sb_ew_15u30_anz;
run; /*... davon 36 mit mehr als 50 EW 15-30*/
data test; set A3b;
if (SB_AZUBI/SB_EW_15_U30_ANZ) GT 0.8;
run; /*nein*/

*Abspeichern;

*Auf SB;
data BESCH.SB_AZUBI;
set A3b (keep=AGS20 SB_AZUBI_neu);
rename SB_AZUBI_neu=sb_azubi;
run; /*1.925.647*/

*Auf OT;
PROC SQL;
create table BESCH.OT_AZUBI
as select ags11,
sum(SB_AZUBI_neu) as ot_azubi
from A3b
group by ags11;
quit; /*64378*/