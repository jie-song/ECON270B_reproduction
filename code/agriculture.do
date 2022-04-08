use $pmgsy_data/pmgsy_working_aer_mainsample, clear
do $pmgsy_code/settings

/* delete old estimates */
cap rm $tmp/ag_master_data.csv

/* Panel A: Output - NDVI Delta, Max, Cumul; EVI Full sample, wheat only */

/* NDVI and EVI */
foreach y in delta cumul max {
  foreach j in ndvi evi {
    ivregress 2sls `j'_`y'_2011_2013_ln (r2012 = t) `j'_`y'_2000_2002_ln left right $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample, vce(robust)
    store_est_tpl using $tmp/ag_master_data.csv, all coef(r2012) name(`j'_`y')
    sum `j'_`y'_2011_2013_ln if e(sample) & t == 0
    store_val_tpl using $tmp/ag_master_data.csv, name("`j'_`y'_mean") value(`r(mean)') format("%7.3f")
    store_val_tpl using $tmp/ag_master_data.csv, name("`j'_`y'_sd") value(`r(sd)') format("%5.3f")
  }
}
/* note mean and sd taken of log value */

/* Panel B: Inputs - Mech Farm, Irr Equip, Land Own */
foreach y in mech_farm irr_equip land_own {
  ivregress 2sls secc_`y'_share (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample, vce(robust)
  store_est_tpl using $tmp/ag_master_data.csv, all coef(r2012) name(`y')
  sum secc_`y'_share if e(sample) & t == 0
  store_val_tpl using $tmp/ag_master_data.csv, name("`y'_mean") value(`r(mean)') format("%5.3f")
}
ivregress 2sls pc11_ag_acre_ln (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_${kernel}_${mainband}] if mainsample & pc11_ag_acre_ln > 0, vce(robust)
store_est_tpl using $tmp/ag_master_data.csv, all coef(r2012) name(ag_acre)
sum pc11_ag_acre_ln if e(sample) & t == 0
store_val_tpl using $tmp/ag_master_data.csv, name("ag_acre_mean") value(`r(mean)') format("%5.3f")

/* Panel B: Crops */
foreach y in any_noncalorie any_noncerpul any_perish   {
  ivregress 2sls `y' (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample, vce(robust)
  store_est_tpl using $tmp/ag_master_data.csv, all coef(r2012) name(`y')
  sum `y' if e(sample) & t == 0
  store_val_tpl using $tmp/ag_master_data.csv, name("`y'_mean") value(`r(mean)') format("%5.3f")
}

/* produce table */
table_from_tpl, t($table_templates/ag_master_tpl.tex) r($tmp/ag_master_data.csv) o($out/ag_master.tex) dropstars
