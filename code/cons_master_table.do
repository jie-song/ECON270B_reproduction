/****************/
/*  Consumption */
/****************/

/* reset maximum number of vars we can have in our dataset */
clear all
clear mata
set maxvar 30000

/* load settings */
do $pmgsy_code/settings

/* use the bootstrapped data previously created. this assumes we
already have maxvars set to 30K. */
use $pmgsy_data/cons_boot_in, clear

cap rm $tmp/cons_boot_intermed.csv
cap rm $tmp/cons_boot_pov_intermed.csv
cap rm $tmp/cons_master_boot.csv

/* Consumption per Capita (logs with level means) */
cons_boot, outfile("$tmp/cons_boot_intermed.csv") name(pc) spec("ivregress 2sls secc_conspcBOOTSTRAPNUMwinln (r2012 = t) left right $controls i.vhg_dist_id [aw = weight_BOOTSTRAPNUM] if mainsample, vce(robust)") sumvar(secc_conspcBOOTSTRAPNUMwinln)
store_est_tpl_boot using $tmp/cons_master_boot.csv, infile("$tmp/cons_boot_intermed.csv") name(pc) sumvar(secc_conspcwinln_mean) sumvarformat("%6.3f")

/* Poverty Rate (Tendulkar) */
use $pmgsy_data/cons_boot_in, clear
cons_boot, outfile("$tmp/cons_boot_pov_intermed.csv") name(pov_rate_tend) spec("ivregress 2sls secc_pov_rate_tendBOOTSTRAPNUM (r2012 = t) left right $controls i.vhg_dist_id [aw = weight_BOOTSTRAPNUM] if mainsample, vce(robust)") sumvar(secc_pov_rate_tendBOOTSTRAPNUM)
store_est_tpl_boot using $tmp/cons_master_boot.csv, infile("$tmp/cons_boot_pov_intermed.csv") name(pov_rate_tend) sumvar(secc_pov_rate_tend_mean) sumvarformat("%6.3f")

/* use the mainsample working data again for non-bootstrapped regressions */
use $pmgsy_data/pmgsy_working_aer_mainsample, clear

/* Asset Index */
ivregress 2sls secc_asset_index_norm (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample, vce(robust)
store_est_tpl using $tmp/cons_master_boot.csv, all coef(r2012) name(asset_index_norm)
sum secc_asset_index_norm if e(sample) & t == 0
store_val_tpl using $tmp/cons_master_boot.csv, name("asset_index_norm_mean") value(`r(mean)') format("%5.3f")

/* Night Lights */
ivregress 2sls ln_light2011_2013   (r2012 = t) left right ln_light2001 $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample, vce(robust)
store_est_tpl using $tmp/cons_master_boot.csv, all coef(r2012) name(light)
sum ln_light2012 if e(sample) & t == 0
store_val_tpl using $tmp/cons_master_boot.csv, name("light_mean") value(`r(mean)') format("%5.3f")

/* Individual Assets - Solid House, Refrigerator, Vehicle, Phone, Earning above 5k */
foreach y in solid_house refrig veh_any phone inc_5k_plus {
  ivregress 2sls secc_`y'_share (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample, vce(robust)
  store_est_tpl using $tmp/cons_master_boot.csv, all coef(r2012) name(`y')
  sum secc_`y'_share if e(sample) & t == 0
  store_val_tpl using $tmp/cons_master_boot.csv, name("`y'_mean") value(`r(mean)') format("%5.3f")
}

/* make table */
table_from_tpl, t($table_templates/cons_master_boot_tpl.tex) r($tmp/cons_master_boot.csv) o($out/cons_master_boot.tex)

