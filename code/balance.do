/* balance and summary stats table */
do $pmgsy_code/settings

use $pmgsy_data/pmgsy_working_aer, clear

/* wipe out existing results file and create new one */
cap rm $tmp/balancedata.csv

/* loop over balance variables */
foreach i in $controls {
  
  /* mean full sample */
  sum `i' if mainsample 
  local btmean `r(mean)'
  store_val_tpl using $tmp/balancedata.csv, name("`i'_mean") value(`r(mean)') format("%5.3f")
  store_val_tpl using $tmp/balancedata.csv, name("N_mean") value(`r(N)') format("%10.0f")
  
  /* mean below threshold */
  sum `i' if mainsample & t == 0
  local btmean `r(mean)'
  store_val_tpl using $tmp/balancedata.csv, name("`i'_bt") value(`r(mean)') format("%5.3f")
  store_val_tpl using $tmp/balancedata.csv, name("N_bt") value(`r(N)') format("%10.0f")
  
  /* mean over threshold */
  sum `i' if mainsample & t == 1
  local otmean `r(mean)'
  store_val_tpl using $tmp/balancedata.csv, name("`i'_ot") value(`r(mean)') format("%5.3f")
  store_val_tpl using $tmp/balancedata.csv, name("N_ot") value(`r(N)') format("%10.0f")

  /* difference */
  local diff = `otmean' - `btmean'
  store_val_tpl using $tmp/balancedata.csv, name("`i'_dm") value(`diff') format("%5.2f")

  /* test equality of means */
  ttest `i' if mainsample, by(t)
  store_val_tpl using $tmp/balancedata.csv, name("`i'_pv") value(`r(p)') format("%5.2f")
  
  /* rd estimate */
  local exclude `i'
  local controls $controls
  local controls_here : list controls - exclude
  ivregress 2sls `i' (r2012=t) left right `controls_here'  i.vhg_dist_id [aw=kernel_${kernel}_${mainband}] if mainsample, r
  
  store_est_tpl using $tmp/balancedata.csv, name("`i'") coef(r2012) format("%5.3f") beta p
  
}
  
/* make tables */
table_from_tpl, t($table_templates/balance_tpl.tex) r($tmp/balancedata.csv) o($out/balance.tex) dropstars
