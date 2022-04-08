/* summary statistics for pc01 villages, by road type */

/* load settings */
do $pmgsy_code/settings

/* load data */
use $shrug_data/shrug_pcec, clear

/* drop uninhabitated villages */
drop if mi(pc01_pca_tot_p) | pc01_pca_tot_p == 0

/* clean variables we'll use */
gen app_pr = pc01_vd_app_pr == 1
gen primary_school = pc01_vd_p_sch > 0 if !mi(pc01_vd_p_sch)
gen med_center = pc01_vd_medi_fac
gen electric = pc01_vd_power_all == 1
gen pc01_sc_share = pc01_pca_p_sc / pc01_pca_tot_p
gen pc01_lit_share = 1 - (pc01_pca_p_ill / pc01_pca_tot_p)
gen irr_share = pc01_vd_tot_irr / (pc01_vd_un_irr + pc01_vd_tot_irr)
/* other variables we'll use: pc01_pca_tot_p, pc01_vd_dist_town */

/* delete data file */
cap rm $tmp/pc01_sumstats_data.csv


/* cycle over variables for summary stats table to calculate mean and SD */
foreach var in primary_school med_center electric irr_share pc01_lit_share pc01_sc_share {
  sum `var' if app_pr == 0
  store_val_tpl using $tmp/pc01_sumstats_data.csv, name("`var'_mean0") value(`r(mean)') format("%7.3f")
  store_val_tpl using $tmp/pc01_sumstats_data.csv, name("`var'_sd0") value(`r(sd)') format("%7.3f")
  sum `var' if app_pr == 1
  store_val_tpl using $tmp/pc01_sumstats_data.csv, name("`var'_mean1") value(`r(mean)') format("%7.3f")
  store_val_tpl using $tmp/pc01_sumstats_data.csv, name("`var'_sd1") value(`r(sd)') format("%7.3f")
  sum `var'
  store_val_tpl using $tmp/pc01_sumstats_data.csv, name("`var'_mean") value(`r(mean)') format("%7.3f")
  store_val_tpl using $tmp/pc01_sumstats_data.csv, name("`var'_sd") value(`r(sd)') format("%7.3f")
}

foreach var in pc01_vd_dist_town pc01_pca_tot_p {
  sum `var' if app_pr == 0
  store_val_tpl using $tmp/pc01_sumstats_data.csv, name("`var'_mean0") value(`r(mean)') format("%7.1f")
  store_val_tpl using $tmp/pc01_sumstats_data.csv, name("`var'_sd0") value(`r(sd)') format("%7.1f")
  sum `var' if app_pr == 1
  store_val_tpl using $tmp/pc01_sumstats_data.csv, name("`var'_mean1") value(`r(mean)') format("%7.1f")
  store_val_tpl using $tmp/pc01_sumstats_data.csv, name("`var'_sd1") value(`r(sd)') format("%7.1f")
  sum `var'
  store_val_tpl using $tmp/pc01_sumstats_data.csv, name("`var'_mean") value(`r(mean)') format("%7.1f")
  store_val_tpl using $tmp/pc01_sumstats_data.csv, name("`var'_sd") value(`r(sd)') format("%7.1f")
}

  
/* count villages by paved road */
count if app_pr == 0
store_val_tpl using $tmp/pc01_sumstats_data.csv, name("count0") value(`r(N)') format("%7.0f")
count if app_pr == 1
store_val_tpl using $tmp/pc01_sumstats_data.csv, name("count1") value(`r(N)') format("%7.0f")
count
store_val_tpl using $tmp/pc01_sumstats_data.csv, name("count") value(`r(N)') format("%7.0f")

/* generate table */
table_from_tpl, t($table_templates/pc01_sumstats_tpl.tex) r($tmp/pc01_sumstats_data.csv) o($out/pc01_sumstats.tex)

