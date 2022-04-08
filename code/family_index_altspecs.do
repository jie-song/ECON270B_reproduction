use $pmgsy_data/pmgsy_working_aer, clear

/* load settings */
do $pmgsy_code/settings

/* index table with different weights and bandwidths */
cap rm $tmp/family_index_altspecs_data.csv

foreach family in transport occupation firms agriculture consumption {

  foreach i in 60 80 100 {

    foreach ker in tri rec {

      ivregress 2sls `family'_index_andrsn  (r2012 = t) left right  $controls i.vhg_dist_id [aw = kernel_`ker'_`i'] if $states & $noroad & $nobad & rd_band_`i', vce(robust)
      store_est_tpl using $tmp/family_index_altspecs_data.csv, all coef(r2012) name(`family'_`ker'_`i')

    }
  }
}

/* make table */
table_from_tpl, t($table_templates/family_index_altspecs_tpl.tex) r($tmp/family_index_altspecs_data.csv) o($out/family_index_altspecs.tex) dropstars
