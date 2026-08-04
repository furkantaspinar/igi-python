
/******	CASA_OPNV_IDX PAGS2025

Bearbeiter:	ErS
Datum:		08.05.2025

Benötigte Variablen:
gem_bbsr_typ CASA_DIST_BHF CASA_DIST_BUSH CASA_DIST_USTRAB

*************************************/

%let _pagsakt = 2025;

***	Daten einlesen und vorbereiten;;
data gem1; set pg_prod.ags8 (schema=variablen&_pagsakt. keep=ags8 gemeindename);
run;

data gem2; set pg_prod.ags8_gem_lage (schema=variablen&_pagsakt. keep=ags8 gem_bbsr_typ);
run;

proc sql; create table BBSR
as select 
a.*,
b.* 
from gem1 as a
left join gem2 as b on a.ags8=b.ags8;
quit;

data _LAGE (index=(ags27)); set pg_prod.casa_dist_opnv (schema=staging keep=ags27 CASA_DIST_BHF CASA_DIST_BUSH CASA_DIST_USTRAB);
if CASA_DIST_BHF > 10000 then CASA_DIST_BHF = 10000;
if CASA_DIST_BUSH > 10000 then CASA_DIST_BUSH = 10000;
if CASA_DIST_USTRAB > 10000 then CASA_DIST_USTRAB = 10000;
run;

    proc means data=_LAGE n nmiss max;
    var casa_dist:;
    run;
    *keine Missings;

**	Aus Postgress ziehen;;
data _AGS27 (index=(ags27)); set PG_PROD.AGS27 (schema=variablen&_pagsakt. keep=AGS27 AGS20 AGS8 AGS5);
run;

proc sql;
create table preOPNV_00
as select 
a.*
,b.CASA_DIST_BHF
,b.CASA_DIST_BUSH
,b.CASA_DIST_USTRAB
from _AGS27	as a
left join _LAGE as b on a.ags27 = b.ags27;
quit;
* 23503292;;

		data tst; set preOPNV_00;
		where CASA_DIST_BHF ^= . and CASA_DIST_BUSH ^= . and CASA_DIST_USTRAB ^= .;
		run;
		* PAGS25) 23503292;
		* PAGS24) 23453827 (Distanzen wurden ohne Obergrenze berechnet)
		* PAGS23) 7394084 
		* PAGS22) 7587948
		* PAGS21) 7510979
		* PAGS20) 7407184
		* PAGS19) 7558976;;


**	Variablen anpassen und weitere Variablen anspielen;;
*	Anspielen des BBSR_TYPS;;
proc sql; create table preOPNV_02
as select
 a.*
,b.gemeindename			as GEM_NAME
,b.GEM_BBSR_TYP			as BBSR_TYP
from preOPNV_00	as a
left join BBSR 	as b on a.ags8 = b.ags8;
quit;


*	Missings bei BBSR deklarieren;;
*	Markieren, ab welcher Distanz eine Haltestelle ignoriert wird;;
data OPNV_01 (rename=(BBSR_TYP_ = BBSR_TYP)); set preOPNV_02;
BBSR_TYP_ = -99;;
if BBSR_TYP ^= . then BBSR_TYP_ = BBSR_TYP;

* Markieren, welche Distanzen unter 1km haben;
* AB PAGS2020 und später: Unterscheidung zwischen BBSR_TYPEN;;
BUSH_ZUWEIT 	= 0;
USTRAB_ZUWEIT 	= 0;
BHF_ZUWEIT 		= 0;

if BBSR_TYP_ in (10 20) then do;
	if CASA_DIST_BUSH 	< 200	THEN BUSH_ZUWEIT = 1;
	if CASA_DIST_USTRAB < 500	THEN USTRAB_ZUWEIT = 1;
	if CASA_DIST_BHF 	< 1000	THEN BHF_ZUWEIT = 1;
end;

if BBSR_TYP_ in (30 40 50 -99) then do;
	if CASA_DIST_BUSH 	< 1000	THEN BUSH_ZUWEIT = 1;
	if CASA_DIST_USTRAB < 1000	THEN USTRAB_ZUWEIT = 1;
	if CASA_DIST_BHF 	< 1000	THEN BHF_ZUWEIT = 1;
end;

VORH_ÖPNV_CODE = compress(BUSH_ZUWEIT || USTRAB_ZUWEIT || BHF_ZUWEIT);
SUM_ÖPNV = sum(of BUSH_ZUWEIT USTRAB_ZUWEIT BHF_ZUWEIT);

drop BBSR_TYP;
run;

proc means data=OPNV_01 min max mean Q1 median Q3 maxdec=2;
class BBSR_TYP;
var CASA_DIST_:;
run;

***	Vorangehende Analysen;;
**	Fälle und Verteilungen pro BBSR_TYP;;
proc sort data=OPNV_01;
by SUM_ÖPNV BBSR_TYP;
run;


***	Berechnungen;;
**	Bewertungen auf Skala von 0 bis 100 bringen und invertieren;;

* Skala der Bewertung vereinheitlichen (und für Bewertungen umkehren);;

**	Umskalieren der Distanzen auf Skalen von 0 bis 100.000 ;;
*	Min und Maxwerte pro BBSR_Berechnen;;
proc sql; create table OPNV_04
as select *
,max(CASA_DIST_BUSH) 	as max_CASA_DIST_BUSH
,max(CASA_DIST_USTRAB) 	as max_CASA_DIST_USTRAB
,max(CASA_DIST_BHF) 	as max_CASA_DIST_BHF
,min(CASA_DIST_BUSH) 	as min_CASA_DIST_BUSH
,min(CASA_DIST_USTRAB) 	as min_CASA_DIST_USTRAB
,min(CASA_DIST_BHF) 	as min_CASA_DIST_BHF
from OPNV_01
group by BBSR_TYP;
quit;


* Skala der Bewertung vereinheitlichen (und für Bewertungen umkehren);;
* gewichtete Version der Skala berechnen;
data OPNV_05; set OPNV_04;
/* Anpassung im PAGS20: Rundung auf 5 Nachkommastellen da es sonst zu komischen minimalen Rundungsdifferenzen 
(vermutlich auf Grund der Zahlenformate) kommen kann*/
NOR_CASA_DIST_BUSH		= round(100000-((CASA_DIST_BUSH - min_CASA_DIST_BUSH)		*100000) / (max_CASA_DIST_BUSH - min_CASA_DIST_BUSH),0.00001);
NOR_CASA_DIST_USTRAB	= round(100000-((CASA_DIST_USTRAB - min_CASA_DIST_USTRAB)	*100000) / (max_CASA_DIST_USTRAB - min_CASA_DIST_USTRAB),0.00001);
NOR_CASA_DIST_BHF		= round(100000-((CASA_DIST_BHF - min_CASA_DIST_BHF)			*100000) / (max_CASA_DIST_BHF - min_CASA_DIST_BHF),0.00001);
drop
max_CASA_DIST_BUSH max_CASA_DIST_USTRAB max_CASA_DIST_BHF
min_CASA_DIST_BUSH min_CASA_DIST_USTRAB min_CASA_DIST_BHF;
run;

/*
		proc means data=OPNV_05 min max;
		var 
		NOR_CASA_DIST_BUSH 
		NOR_CASA_DIST_USTRAB 
		NOR_CASA_DIST_BHF;
		class BBSR_TYP;
		run;

		proc univariate data=OPNV_05 noprint;
		var 
		NOR_CASA_DIST_BUSH 
		NOR_CASA_DIST_USTRAB 
		NOR_CASA_DIST_BHF ;
		histogram 
		NOR_CASA_DIST_BUSH 
		NOR_CASA_DIST_USTRAB 
		NOR_CASA_DIST_BHF ;
		run;

		proc univariate data=OPNV_05 noprint;
		class BBSR_TYP;
		var 
		NOR_CASA_DIST_BUSH 
		NOR_CASA_DIST_USTRAB 
		NOR_CASA_DIST_BHF ;
		histogram 
		NOR_CASA_DIST_BUSH 
		NOR_CASA_DIST_USTRAB 
		NOR_CASA_DIST_BHF ;
		run;
*/

***	Berechnen der Mittelwerte mit gewichteten Distanzen;;
data OPNV_06; set OPNV_05;

if SUM_ÖPNV > 0 THEN BEW_IDX = round(((BUSH_ZUWEIT*NOR_CASA_DIST_BUSH)+(USTRAB_ZUWEIT*NOR_CASA_DIST_USTRAB)+(BHF_ZUWEIT*NOR_CASA_DIST_BHF))/SUM_ÖPNV);
if SUM_ÖPNV = 0 THEN BEW_IDX = round((NOR_CASA_DIST_BUSH+NOR_CASA_DIST_USTRAB+NOR_CASA_DIST_BHF)/3);

BEW_IDX_3 = round((NOR_CASA_DIST_BUSH+NOR_CASA_DIST_USTRAB+NOR_CASA_DIST_BHF)/3);
run;

/*
		* grafischer Check auf BBSR;;
		proc univariate data=OPNV_06;
		var  BEW_IDX BEW_IDX_3;
		histogram BEW_IDX BEW_IDX_3;
		run;
		proc univariate data=OPNV_06;
		var BEW_IDX BEW_IDX_3;
		histogram BEW_IDX   /CBARLINE=BLACK CFILL=cx20797B PFILL=SOLID;
		INSET MAX MEDIAN MIN MEAN / POSITION=NE CTEXT=BLACK CFILL=LIGHTGREY CFRAME=BLACK CHEADER=BLACK HEIGHT=2;
		histogram BEW_IDX_3   /CBARLINE=BLACK CFILL=RED PFILL=SOLID;
		INSET MAX MEDIAN MIN MEAN / POSITION=NE CTEXT=BLACK CFILL=LIGHTGREY CFRAME=BLACK CHEADER=BLACK HEIGHT=2;
		by BBSR_typ;
		run;
*/


*grafischer Check auf SUM_ÖPNV;;
proc sort data=OPNV_06 out=OPNV_06s;
by 'SUM_ÖPNV'N;
run;

**	Umskalieren des BEW_IDX_3 auf 0 bis 100.000 pro SUM_OPNV (hier nun je näher an 100.000 desto besser ;;
*	Min und Maxwerte pro BBSR_Berechnen;;
proc sql; create table OPNV_07
as select *
,max(BEW_IDX_3) 	as max_BEW_IDX_3
,min(BEW_IDX_3) 	as min_BEW_IDX_3
from OPNV_06s
group by SUM_ÖPNV;
quit;

* Skala der Bewertung vereinheitlichen (und für Bewertungen umkehren);;
* gewichtete Version der Skala berechnen;
data OPNV_08; set OPNV_07;
NOR_BEW_IDX_3		= ((BEW_IDX_3 - min_BEW_IDX_3)*100000) / (max_BEW_IDX_3 - min_BEW_IDX_3);
drop max_BEW_IDX_3 min_BEW_IDX_3;
run;

data OPNV_09a; set OPNV_08;
AKT_NOR_BEW_IDX_3 = NOR_BEW_IDX_3 + (25000 * SUM_ÖPNV); /*Weichzeichner für Grenzen je niedriger die Zahl umso unschärfer*/
run;

		proc univariate data=OPNV_09a;
		var NOR_BEW_IDX_3 AKT_NOR_BEW_IDX_3;
		hist;
		run;
		proc sgplot data=OPNV_09a;
		histogram NOR_BEW_IDX_3 / group=SUM_ÖPNV transparency=0.75;
		run;
		proc sgplot data=OPNV_09a;
		histogram AKT_NOR_BEW_IDX_3 / group=SUM_ÖPNV transparency=0.75;
		run;

proc sql; create table OPNV_09b
as select *
,max(AKT_NOR_BEW_IDX_3) 	as max_BEW_AKT
,min(AKT_NOR_BEW_IDX_3) 	as min_BEW_AKT
from OPNV_09a;
quit;

data OPNV_11; set OPNV_09b;
NEW_BEW_IDX_3		= ((AKT_NOR_BEW_IDX_3 - min_BEW_AKT)*100000) / (max_BEW_AKT - min_BEW_AKT);
* Auf 100 Klassen runden;;
casa_opnv_idx = round(NEW_BEW_IDX_3/1000);
if casa_opnv_idx = . then casa_opnv_idx = -99;
run;

		proc freq data=OPNV_11;
		tables casa_opnv_idx ;
		run;
		proc means data=OPNV_11 min max mean median range n nmiss;
		var casa_opnv_idx  NEW_BEW_IDX_3;
		run;
		proc univariate data=OPNV_11 noprint;
		var casa_opnv_idx;
		where casa_opnv_idx ^= -99;
		histogram / midpoints=0 to 100 by 1;
		run;

* Klassieren auf Kreis;
proc sort data=OPNV_11 out=OPNV_11s;
by ags5;
run;
proc univariate data=OPNV_11s noprint;
var casa_opnv_idx;
by ags5;
output out=perzentile
pctlpts = 10 30 70 90
pctlpre = p_;
run;

data OPNV_11s; set OPNV_11s;
match = 360;
run;

proc sql; create table OPNV_12
as select a.*, b.*
from OPNV_11s		as a
left join perzentile	as b on a.ags5 = b.ags5;
quit;

data OPNV_13; set OPNV_12;
casa_opnv_idx_kl = -99;
if casa_opnv_idx >= 0	 and casa_opnv_idx < p_10	then casa_opnv_idx_kl = 1;
if casa_opnv_idx >= p_10 and casa_opnv_idx < p_30	then casa_opnv_idx_kl = 2;
if casa_opnv_idx >= p_30 and casa_opnv_idx < p_70	then casa_opnv_idx_kl = 3;
if casa_opnv_idx >= p_70 and casa_opnv_idx < p_90	then casa_opnv_idx_kl = 4;
if casa_opnv_idx >= p_90 	 						then casa_opnv_idx_kl = 5;
keep ags27 casa_opnv_idx casa_opnv_idx_kl;
run;

		proc freq data=OPNV_13;
		tables casa_opnv_idx casa_opnv_idx_kl;
		run;

		proc contents data=OPNV_13;
		run;

* Speichern;;
%sas_to_pg
(from= OPNV_13
,to= z_ags27_ers_0508_opnv_idx
,server=172.30.30.114
,port= 5432
,uid= %SUBSTR(&_CLIENTUSERID.,2,%EVAL(%LENGTH(&_CLIENTUSERID.)-2))
,pwd= &_PWD.
,database= prod
,schema= sas_dbupdate
,pk=ags27);

/*
	*** Für Kontrolle in Karte;;
	data HSO_CHECK_OPNV1 (where=(ags2 = '05')); 
	set OPNV_11 (keep=AGS27 casa_opnv_idx);
	ags2 = substr(ags27,1,2);
	ags5 = substr(ags27,1,5);
	ags11 = substr(ags27,1,11);
	ags20 = substr(ags27,1,20);
	run;

	proc sql;
	create table HSO_CHECK_OPNV2
	as select 
	ags11,
	count(*) as anz_adr,
	round(mean(casa_opnv_idx)) as ot_opnv_idx
	from HSO_CHECK_OPNV1
	group by ags11;
	quit;

	%sas_to_pg(from=HSO_CHECK_OPNV2,to=hso_check_opnv_0309,pk=ags11);

	proc sql;
	create table HSO_CHECK_OPNV_SEL1 
	as select ags20,
	count(*) as anz_adr,
	round(mean(casa_opnv_idx)) as sb_opnv_idx
	from HSO_CHECK_OPNV1 (where=(ags5 in ('05162','05315','05314','05111')))
	group by ags20;
	quit;

	%sas_to_pg(from=HSO_CHECK_OPNV_SEL1,to=hso_check_opnv_sel_0309,pk=ags20);

	*** Visueller Check des Histograms für Bonn;;
	proc univariate data=HSO_CHECK_OPNV;
	where ags5 = '05314';
	var casa_opnv_idx;
	histogram casa_opnv_idx/ midpoints=0 to 100 by 1;
	run;
*/