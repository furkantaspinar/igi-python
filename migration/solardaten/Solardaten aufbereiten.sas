*
Bearbeiter: ErS
Datum: 17.04.2025 
Anpassung 24.04.25 ViE
;

/*Rohaten wurden im XML-Format heruntergeladen und hier gespeichert:U:\Marktdaten\Energiedaten\Rohdaten_Marktstammdatenregister\Gesamtdatenexport_20230314_22.2_1eb569b91e004723aa9bf42f40fb3247
U:\Marktdaten\Energiedaten\Rohdaten_Marktstammdatenregister\Gesamtdatenexport_20250415_25.1

XML-Dateien wurden in Python aufbereitet 
Skript: U:\Marktdaten\Energiedaten\PAGS2025\xml_processing_2025.py
und hier als csv abgelegt: 
U:\Marktdaten\Energiedaten\PAGS2025\CSV\EinheitenSolar.csv

csv einlesen: insg. 5135228 F�lle*/

*neuer Gesamtdatensatz wurde runtergeladen und geokodiert (�ber 2 Mio F�lle). Allerdings enth�lt dieser nur 193k F�lle mit Adresse oder Koordinaten.
Daher wird dieser Datensatz als Erg�nzung zum bestehenden Gesamtdatensatz verwendet

als solar_ges in home zwischengespeichert
;

DATA home.solar_ges; 
set work.einheitensolar; 
run; 
/*Bsp: SEE910091133276 hat eine Nettonennleistung von */

	proc means data=work.einheitensolar min max mean n nmiss; 
	var bruttoleistung nettonennleistung; 
	where Breitengrad NE . or Strasse NE '';
	run;


*F�r Geokodierung;
data solar_20250416; set home.solar_ges ;
if Breitengrad NE . or Strasse NE '';

rename csv_id = id; 
rename postleitzahl = PLZ;
sol_jr=year(Inbetriebnahmedatum);
if year(Inbetriebnahmedatum) le 1990 then sol_jr=1990;
if year(Inbetriebnahmedatum) =. then sol_jr=.;

nl_net=Nettonennleistung;
nl_brut=Bruttoleistung;

* Datumsangaben f�r das Upload Skript in String umwandeln;
DatBeginnVoruebergehendeStilll = put(DatumBeginnVoruebergehendeStilll, yymmdd10.);
DatDesBetreiberwechsels = put(DatumDesBetreiberwechsels, yymmdd10.);
DatEndgueltigeStilllegung = put(DatumEndgueltigeStilllegung, yymmdd10.);
DatRegistrierungDesBetreiberwe = put(DatumRegistrierungDesBetreiberwe, yymmdd10.);
DatWiederaufnahmeBetrieb = put(DatumWiederaufnahmeBetrieb, yymmdd10.);
GeplantesInbetriebnahmedat = put(GeplantesInbetriebnahmedatum, yymmdd10.);
Inbetriebnahmedatum = put(Inbetriebnahmedatum, yymmdd10.);
NetzbetreiberpruefungDatum = put(NetzbetreiberpruefungDatum, yymmdd10.);
Registrierungsdatum = put(Registrierungsdatum, yymmdd10.);

array datvar DatBeginnVoruebergehendeStilll DatDesBetreiberwechsels DatEndgueltigeStilllegung DatRegistrierungDesBetreiberwe DatWiederaufnahmeBetrieb GeplantesInbetriebnahmedat;
do over datvar;
	if datvar = "         ." then datvar = "";
	end;

drop DatumBeginnVoruebergehendeStilll DatumDesBetreiberwechsels DatumEndgueltigeStilllegung DatumRegistrierungDesBetreiberwe DatumWiederaufnahmeBetrieb GeplantesInbetriebnahmedatum Inbetriebnahmedatum NetzbetreiberpruefungDatum Registrierungsdatum;
run;
*238826;

proc means data=solar_20250416; 
var nl_brut nl_net sol_jr;
run;

* Upload f�r das Geocoding;
%sas_to_pg
(from= solar_20250416
,to= vie_solar_20250424
,server= 172.30.30.114
,port= 5432
,uid= %SUBSTR(&_CLIENTUSERID.,2,%EVAL(%LENGTH(&_CLIENTUSERID.)-2))
,pwd= &_PWD.
,database=prod
,schema=staging
,pk=id
);


**** Weiter, wenn Geocodiert;
*** Anspielen ben�tigten Werte aus der Rohtabelle mit geocodierten Werten;
DATA rohdaten (index=(id)); set pg_prod.vie_solar_20250424 (schema=staging); 
run; 

*neu Geokodierter Masterdatensatz;
data solar0 (index=(id)); set pg_proc.solar_20250416_geo2025_final (where=(ags27 ^= "") schema=roh_mastr
keep=ags27 id);
run;
*216984;

proc sql; create table solar00
as select a.id, a.ags27, b.* 
from solar0 as a 
left join rohdaten as b on a.id = b.id;
quit;
*216984;

data solar2; set solar00;
format datum_stilllegung date9.;
datum_stilllegung = input(DatEndgueltigeStilllegung, yymmdd10.);
* Nur die Werte behalten, welche noch bis zum 31.12.2024 aktiv waren (Datum muss jedes Jahr angepasst werden);

solar=1;
sol_nl = nl_net; 

if datum_stilllegung > '31DEC2024'd or datum_stilllegung = .;
run;
*216692;

	proc means data=rohdaten min max n nmiss mean; 
	var nl_brut nl_net sol_jr;
	run;

	proc means data=solar2 min max n nmiss mean; 
	var nl_brut sol_nl sol_jr ;
	run;
/* sol_nl
min. 30005
max. 119520000
n 213888
nmiss 0
*/

*Bei mehreren Anlagen pro Adresse, wird die Summe der Nennleistung gebildet und das Maximum des Jahres;
proc sql; create table solar3
as select ags27, 1 as solar,
min(sol_jr) as sol_jr,
sum(sol_nl) as sol_nl 
from solar2
group by ags27;
quit;
*173171;

/*Nennleistungen sehr hoch; stichprobenhafte �berpr�fung der Adressen*/
	proc sql; create table test 
	as select
	a.*,
	b.stn, b.hnr, b.plz, b.ort 
	from solar3 a 
	left join pg_prod.ags27 (schema=variablen2025) b
	on a.ags27=b.ags27;
	quit; 

	proc sort data=test; 
	by descending sol_nl sol_jr; 
	run;
/*
120701490040000000150106001 D�llener Str. 55, 16866 Gumtow --> Auf Adresse unwahrscheinlich, nord�stlich ist Anlage (gr��er als Siedlung der Adresse)
130760070020000000010101001	An den Barniner Eichen	2	19089	Barnin --> Laut Koordinaten Umspannwerk
092761440130000004300101001 Pignet 4 Viechtach --> 

--> Teilweise sehr hohe Nennleistung an abgelegenen Orten, m�glich aber auff�llig. Wird zun�chst so belassen, da Echtf�lle;
*/

		proc sql; create table testt
		as select *,
		id, ags27, breitengrad, laengengrad
		from work.solar00
		where ags27 in ('130760070020000000010101001','120701490040000000150106001');
		quit;

*Match Werte letzten PAGS;
proc sql; create table solar4
as select 
a.*,
b.*,
c.casa_solar as sol,
c.casa_sol_jr as jr,
c.casa_sol_nl as nl
from pg_prod.ags27_2025_2_ags27_2024 (schema=mapping) as a 
left join solar3 as b on a.ags27_2025=b.ags27
left join pg_prod.mv_ags27 (schema=variablen2024) as c on a.ags27_2024=c.ags27;
quit;
*23372277;

*Werte altpags �bernehmen, wenn Missing oder wenn alte Werte h�her sind;
data solar5; set solar4;
if solar NE 1 and sol=1 then solar=1;
if sol_nl = . then sol_nl = nl;
if sol_jr = . then sol_jr = jr;

if nl > sol_nl and nl NE . then sol_nl = nl;
if jr > sol_jr and jr NE . then sol_jr = jr;

drop nl jr sol ags27;
run;

*aggregieren;
proc sql; create table solar6
as select ags27_2025 as ags27,
max(solar) as solar,
max(sol_jr) as sol_jr,
sum(sol_nl) as sol_nl 
from solar5
group by ags27_2025;
quit;
*23372277;

*Neue Daten anspielen;
proc sql; create table sol1
as select a.*,
b.ags27 as ags27_2,
b.solar as sol,
b.sol_nl as sol_nl2,
b.sol_jr as sol_jr2
from solar6 as  a 
left join solar3 as b on a.ags27=b.ags27;
quit;
*23222397;

	data test; set sol1;
	if sol_nl=. and sol_nl2 NE .;
	run;
	*keine F�lle;

*Aktuellstes Jahr �bernehmen, wenn nl auch h�her ist
Neue F�lle �bernehmen, ohne Jahr, wenn unplausibel
Wenn Jahre gleich, dann h�heren Nennwert �bernehmen
;

data sol2; set sol1;

sol_jr_neu=sol_jr;
sol_nl_neu=sol_nl;

if sol_jr2 > sol_jr and sol_nl2 > sol_nl then do;
sol_jr_neu=sol_jr2;
sol_nl_neu=sol_nl2;
end;

if sol_jr2 = sol_jr and sol_nl2 > sol_nl then do;
sol_nl_neu=sol_nl2;
end;

if sol_nl_neu=. then sol_nl_neu=sol_nl2;
if sol_jr_neu=. and sol_jr2 <= 2025 then sol_jr_neu=sol_jr2;

if sol_jr_neu > 2025 then sol_jr_neu=sol_jr;

if sol=1 then solar=1;
if solar=. then solar=0;
run;


data sol3; set sol2 (keep=ags27 solar sol_nl_neu sol_jr_neu);

rename solar = CASA_SOLAR;
rename sol_jr_neu = CASA_SOL_JR;
rename sol_nl_neu = CASA_SOL_NL;
run;


/*Perzentile zum Check berechnen (es werden aber die gleichen genommen)*/
proc means data=sol3 p10 p25 p50 p75 p90 min max mean n;
var casa_sol_nl; 
where casa_sol_nl NE .;
run;

proc univariate data=sol3;
    var casa_sol_nl;
	histogram casa_sol_nl;
	output out=percentiles pctlpts= 10 25 50 75 90 pctlpre=P_; 
run;

data _null_;
    set percentiles;
    call symputx('p10', P_10);
    call symputx('p25', P_25);
    call symputx('p50', P_50);
    call symputx('p75', P_75);
    call symputx('p90', P_90);
run;

%put WARNING: Perzentile: &p10, &p25, &p50, &p75, &p90;
*2025 Perzentile: 4, 6, 10, 28, 60000;
*2024 Perzentile: 4, 6, 10, 25, 40000;

data sol3; set sol3;
if .	 < CASA_SOL_NL <=4	   then CASA_SOL_KL = 1;
if 4	 < CASA_SOL_NL <=6	   then CASA_SOL_KL = 2;
if 6	 < CASA_SOL_NL <=10	   then CASA_SOL_KL = 3;
if 10	 < CASA_SOL_NL <=24	   then CASA_SOL_KL = 4;
if 24	 < CASA_SOL_NL <=40000 then CASA_SOL_KL = 5;
if 40000 < CASA_SOL_NL		   then CASA_SOL_KL = 6;
if CASA_SOL_NL = .			   then CASA_SOL_KL = -99;
run;
*1.075.027;

*Anspielen an Master;
data master (index=(ags27)); set pg_prod.ags27 (keep=ags27 schema=variablen2025);
run;
*23503292;

proc sql; create table sol4
as select a.ags27,b.*
from master as a
left join sol3 as b on a.ags27=b.ags27;
quit;
*23503292;

data sol4 (index=(ags27)); set sol4;
if CASA_SOLAR=. then CASA_SOLAR=0;
if casa_sol_kl=. then casa_sol_kl=-99;
run;

*Alte Daten;
DATA solar_alt (index=(ags27)); set pg_prod.ags27_casa_energie (schema=variablen2024 keep=ags27 CASA_SOLAR  CASA_SOL_JR  CASA_SOL_NL  CASA_SOL_KL);
run;

	DATA test; set solar_alt;
	if casa_solar=1;
	run;
	*1092164;

* Check auf Klassengrenzen;;
	proc means data=solar_alt min max n nmiss maxdec=1;
	class casa_sol_kl;
	var casa_sol_nl;
	run;
	proc means data=sol4 min max n nmiss maxdec=1;
	class casa_sol_kl;
	var casa_sol_nl;
	run;

	proc freq data=solar_alt; table casa_sol_kl; where casa_solar=1;
	proc freq data=sol4; table casa_sol_kl; where casa_solar=1;


*Match mit alten Daten f�r kurzen Check;
proc sql; create table match
as select a.*,b.*,
c.casa_solar as solar_alt,c.casa_sol_jr as jr,c.casa_sol_nl as nl
from pg_prod.ags27_2025_2_ags27_2024 (schema=mapping) a 
left join sol4 b on a.ags27_2025=b.ags27
left join solar_alt c on a.ags27_2024=c.ags27;
quit;
*23222397;

proc freq data=match;
tables casa_solar*solar_alt/ nocol norow nopercent;
run;

data test; set match;
if casa_sol_jr < jr;
run;
* keine F�lle;

%sas_to_pg
(from=sol4
,to=z_ags27_ers_0506_solar
,server=172.30.30.114
,port= 5432
,uid= %SUBSTR(&_CLIENTUSERID.,2,%EVAL(%LENGTH(&_CLIENTUSERID.)-2))
,pwd= &_PWD.
,database= prod
,schema= sas_dbupdate
,pk= ags27);