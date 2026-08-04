
-- Indizes für Joins erstellen
CREATE INDEX ix_hs_final_plus_2_ags20_5km__ags20
ON staging.hs_final_plus_2_ags20_5km using btree (ags20);

CREATE INDEX ix_hs_final_plus_2_ags20_5_10km__ags20
ON staging.hs_final_plus_2_ags20_5_10km using btree (ags20);

CREATE INDEX ix_hs_final_plus_2_ags20_10_25km__ags20
ON staging.hs_final_plus_2_ags20_10_25km using btree (ags20);

CREATE INDEX ix_hs_final_plus_2_ags20_25_50km__ags20
ON staging.hs_final_plus_2_ags20_25_50km using btree (ags20);

CREATE INDEX ix_hs_final_plus_2_ags20_50_100km__ags20
ON staging.hs_final_plus_2_ags20_50_100km using btree (ags20);

CREATE INDEX ix_hs_final_plus_2_ags20_50_100km__hs_no
ON staging.hs_final_plus_2_ags20_25_50km using btree (hs_no);

CREATE INDEX ix_hs_final_plus_2_ags20_25_50km__hs_no
ON staging.hs_final_plus_2_ags20_25_50km using btree (hs_no);

CREATE INDEX ix_hs_final_plus_2_ags20_10_25km__hs_no
ON staging.hs_final_plus_2_ags20_10_25km using btree (hs_no);

CREATE INDEX ix_hs_final_plus_2_ags20_5_10km__hs_no
ON staging.hs_final_plus_2_ags20_5_10km using btree (hs_no);

CREATE INDEX ix_hs_final_plus_2_ags20_5km__hs_no
ON staging.hs_final_plus_2_ags20_5km using btree (hs_no);

CREATE INDEX ix_hochschulen_final_plus__hs_no
ON poi2025.hochschulen_final_plus using btree (hs_no);

CREATE MATERIALIZED VIEW staging.mv_hs_final_ags20_5km
TABLESPACE pg_default
AS
 SELECT a.hs_no, a.ags20, b.hs_studierende, c.SB_EW_ANZ, c.SB_EW_18U30_ANZ
    FROM staging.hs_final_plus_2_ags20_5km a
     LEFT JOIN poi2025.hochschulen_final_plus b ON a.hs_no=b.hs_no 
	left join variablen2025.ags20_sb_ew c on a.ags20=c.ags20
where b.hs_studierende != '' and c.sb_ew_anz != 0 and c.sb_ew_anz is not null;

CREATE MATERIALIZED VIEW staging.mv_hs_final_ags20_5_10km
TABLESPACE pg_default
AS
 SELECT a.hs_no, a.ags20, b.hs_studierende, c.SB_EW_ANZ, c.SB_EW_18U30_ANZ
    FROM staging.hs_final_plus_2_ags20_5_10km a
     LEFT JOIN poi2025.hochschulen_final_plus b ON a.hs_no=b.hs_no 
	left join variablen2025.ags20_sb_ew c on a.ags20=c.ags20
where b.hs_studierende != '' and c.sb_ew_anz != 0 and c.sb_ew_anz is not null;

CREATE MATERIALIZED VIEW staging.mv_hs_final_ags20_10_25km
TABLESPACE pg_default
AS
 SELECT a.hs_no, a.ags20, b.hs_studierende, c.SB_EW_ANZ, c.SB_EW_18U30_ANZ
    FROM staging.hs_final_plus_2_ags20_10_25km a
     LEFT JOIN poi2025.hochschulen_final_plus b ON a.hs_no=b.hs_no 
	left join variablen2025.ags20_sb_ew c on a.ags20=c.ags20
where b.hs_studierende != '' and c.sb_ew_anz != 0 and c.sb_ew_anz is not null;

CREATE MATERIALIZED VIEW staging.mv_hs_final_ags20_25_50km
TABLESPACE pg_default
AS
 SELECT a.hs_no, a.ags20, b.hs_studierende, c.SB_EW_ANZ, c.SB_EW_18U30_ANZ
    FROM staging.hs_final_plus_2_ags20_25_50km a
     LEFT JOIN poi2025.hochschulen_final_plus b ON a.hs_no=b.hs_no 
	left join variablen2025.ags20_sb_ew c on a.ags20=c.ags20
where b.hs_studierende != '' and c.sb_ew_anz != 0 and c.sb_ew_anz is not null;

CREATE MATERIALIZED VIEW staging.mv_hs_final_ags20_50_100km
TABLESPACE pg_default
AS
 SELECT a.hs_no, a.ags20, b.hs_studierende, c.SB_EW_ANZ, c.SB_EW_18U30_ANZ
    FROM staging.hs_final_plus_2_ags20_50_100km a
     LEFT JOIN poi2025.hochschulen_final_plus b ON a.hs_no=b.hs_no 
	left join variablen2025.ags20_sb_ew c on a.ags20=c.ags20
where b.hs_studierende != '' and c.sb_ew_anz != 0 and c.sb_ew_anz is not null;