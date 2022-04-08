do $pmgsy_code/settings

use $pmgsy_data/pmgsy_working_aer_mainsample, clear

/* generate data for index tables: main table and spillovers */
cap rm $tmp/family_index_data.csv
foreach family in transport occupation firms agriculture consumption {
  ivregress 2sls `family'_index_andrsn  (r2012 = t) left right  $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample, vce(robust)
  store_est_tpl using $tmp/family_index_data.csv, all coef(r2012) name(`family')
  ivregress 2sls `family'_index_andrsn_5k  (r2012 = t) left right  $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample, vce(robust)
  store_est_tpl using $tmp/family_index_data.csv, all coef(r2012) name(`family'_5k)
}

/* unemployment for spillover table */
ivregress 2sls unemp_5k  (r2012 = t) left right  $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample, vce(robust)
store_est_tpl using $tmp/family_index_data.csv, all coef(r2012) name(unemp_5k)


/* main table */
table_from_tpl, t($table_templates/family_index_tpl.tex) r($tmp/family_index_data.csv) o($out/family_index.tex) dropstars

/* spillovers index */
table_from_tpl, t($table_templates/family_index_spillovers_tpl.tex) r($tmp/family_index_data.csv) o($out/spillovers_index.tex) dropstars
