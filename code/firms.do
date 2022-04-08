use $pmgsy_data/pmgsy_working_aer_mainsample, clear
do $pmgsy_code/settings

/* delete old estimates */
cap rm $tmp/firms_data.csv

/* Loop over outcomes */
foreach y in all ag t_noag nt act2 act3 act6 act12 act20 {
  ivregress 2sls ec13_emp_`y'_ln  (r2012 = t) left right  $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample & $nobad_firms, vce(robust)
  store_est_tpl using $tmp/firms_data.csv, all coef(r2012) name(`y')
  ivregress 2sls ec13_emp_`y'  (r2012 = t) left right  $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample & $nobad_firms, vce(robust)
  store_est_tpl using $tmp/firms_data.csv, all coef(r2012) name(`y'_lev)
  sum ec13_emp_`y' if e(sample) & t == 0
  store_val_tpl using $tmp/firms_data.csv, name("`y'_lev_mean") value(`r(mean)') format("%5.1f")
}

table_from_tpl, t($table_templates/firms_tpl.tex) r($tmp/firms_data.csv) o($out/firms.tex) dropstars
