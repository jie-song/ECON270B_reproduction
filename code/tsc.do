/* load data and settings */
use $pmgsy_data/pmgsy_working_aer_mainsample, clear
qui do $pmgsy_code/settings.do

/* generate table */
cap rm $tmp/tsc_data.csv
foreach var of varlist pc11r_hl_latrine_oth_open pc11r_hl_latrine_inprem pc11r_hl_latrine_pit_svi pc11r_hl_latrine_pit_sop {
  cap drop `var'_2
  gen `var'_2 = `var' / 100
  ivregress 2sls `var'_2 (r2011 = t) left right $controls i.vhg_dist_id [aw = kernel_${kernel}_${mainband}] if mainsample & v_high_group == 1, vce(robust)
  store_est_tpl using $tmp/tsc_data.csv, all coef(r2011) name(`var')
  sum `var'_2 if t == 0 & e(sample)
  store_val_tpl using $tmp/tsc_data.csv, name("`var'_mean") value(`r(mean)') format("%5.3f")
  drop `var'_2
}
table_from_tpl, t($table_templates/tsc_tpl.tex) r($tmp/tsc_data.csv) o($out/tsc.tex) dropstars
