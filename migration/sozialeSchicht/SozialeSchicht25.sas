
*****
Bearbeiterin:
AnW 26. April 2024
BEN 27.05.2025
;

proc sql;
create table wh_preis
as select 
a.ags27,
b.wh_preis
from pg_prod.ags27 (schema=variablen2025 keep=ags27) as a
left join (select ags27, casa_wh_preis as wh_preis from pg_prod.z_ags27_ben_0522_wh_preis (schema=sas_dbupdate)) as b
on a.ags27=b.ags27;
quit;

data GES; set wh_preis;
BEL_K=round(WH_PREIS*5.5/1200,1);
AGS5=substr(AGS27,1,5);
run; 
/*23.503.292*/

*Schichten nach Perzentilen einteilen;;
proc sort data=GES;
by ags5;
run;

PROC means data=GES noprint ;
output p25=p25 p50=p50 p75=p75 out=GES2 ;
var BEL_K ;
by AGS5;
run;

PROC SQL; create table GES3
as select
a.*,
b.*
from GES a
left join GES2 b
on a.AGS5=b.AGS5;
quit;

DATA GES4; set GES3;

if BEL_K le p25 then MON_EINK=BEL_K*3;
if BEL_K gt p25 and BEL_K le p75 then MON_EINK=BEL_K*4;
if BEL_K gt p75 then MON_EINK=BEL_K*5;

JAHR_EINK=MON_EINK*12;

run;

PROC means data=GES4 p10 p40 p60 p90;
var MON_EINK ;
run;

******************;;

DATA GES5; set GES4;
CASA_SOZ_SCH=-99;

if MON_EINK ne . then do;
if MON_EINK le 2364 then CASA_SOZ_SCH=5; *p10;
if 2364 <MON_EINK <= 5132 then CASA_SOZ_SCH=4; *p10-p40;
if 5132  <MON_EINK <= 7280 then CASA_SOZ_SCH=3;*p40-p60;
if 7280 <MON_EINK <= 13630 then CASA_SOZ_SCH=2;*p60-p90;
if 13630 <MON_EINK  then CASA_SOZ_SCH=1;*p90;
end;
run;

* zum Vergleich Stand PAGS24;;
data soz_sch_24;
set pg_prod.ags27_casa_soz (schema=variablen2024 keep=ags27 casa_soz_sch);
run;

PROC FREQ DATA=GES5;
table casa_soz_sch;
run;

proc freq data=soz_sch_24;
tables casa_soz_sch;
run;

* Ausprägungen
-99=k.A.
1=Oberschicht
2=obere Mittelschicht
3=Mittelschicht
4=untere Mittelschicht
5=Unterschicht;

* => etwas mehr missings...

*Speichern;;
data exp;
set GES5 (keep=ags27 casa_soz_sch);
run;

*In die DB laden;;
%sas_to_pg
(from=exp
,to=z_ags27_ben_0527_soz_schicht
,server=172.30.30.114
,port=5432
,uid=%SUBSTR(&_CLIENTUSERID.,2,%EVAL(%LENGTH(&_CLIENTUSERID.)-2))
,pwd=&_PWD.
,database=prod
,schema=sas_dbupdate
,pk=ags27);



*** Kurze Prüfung ob Problem vom letzten Jahr noch besteht 
(Fälle mit CASA_HH > 0 und CASA_SOZ_SCH = -99;
proc sql;
create table tst (where=(casa_hh>0 and casa_soz_sch in (. -99)))
as select 
a.ags27, a.casa_hh,
b.casa_soz_sch
from pg_prod.ags27_casa_hh (schema=variablen2025 keep=ags27 casa_hh) as a
left join exp as b
on a.ags27=b.ags27;
quit;
*nein;