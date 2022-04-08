use $pmgsy_data/pmgsy_working_aer, clear

/* load settings */
do $pmgsy_code/settings

/* drop saved estimates */
cap rm $tmp/placebo_index_data.csv

/* placebo output for tpl */
reg r2012 t left right $controls i.vhg_dist_id [aw = kernel_tri_ik] if mainsample, r
store_est_tpl using $tmp/placebo_index_data.csv, all coef(t) name(mainr2012)
sum r2012 if e(sample) & t == 0
store_val_tpl using $tmp/placebo_index_data.csv, name("mainr2012_mean") value(`r(mean)') format("%5.2f")

reg r2012 t left right $controls i.vhg_dist_id [aw = kernel_tri_ik] if !$states & rd_band_ik & $noroad & $nobad & (inlist(pmgsy_state_id, "AP", "AS", "BR", "GJ", "KN", "JH", "UP") | inlist(pmgsy_state_id, "UK", "MH", "OR", "RJ")), r
store_est_tpl using $tmp/placebo_index_data.csv, all coef(t) name(placebor2012)
sum r2012 if e(sample) & t == 0
store_val_tpl using $tmp/placebo_index_data.csv, name("placebor2012_mean") value(`r(mean)') format("%5.2f")

foreach family in transport occupation firms agriculture consumption {

  reg `family'_index_andrsn t left right $controls i.vhg_dist_id [aw = kernel_tri_ik] if mainsample, r
  store_est_tpl using $tmp/placebo_index_data.csv, all coef(t) name(main`family')
  sum `family'_index_andrsn if e(sample) & t == 0
  store_val_tpl using $tmp/placebo_index_data.csv, name("main`family'_mean") value(`r(mean)') format("%5.2f")


  reg `family'_index_andrsn t left right $controls i.vhg_dist_id [aw = kernel_tri_ik] if !$states & rd_band_ik & $noroad & $nobad & (inlist(pmgsy_state_id, "AP", "AS", "BR", "GJ", "KN", "JH", "UP") | inlist(pmgsy_state_id, "UK", "MH", "OR", "RJ")), r
  store_est_tpl using $tmp/placebo_index_data.csv, all coef(t) name(placebo`family')
  sum `family'_index_andrsn if e(sample) & t == 0
  store_val_tpl using $tmp/placebo_index_data.csv, name("placebo`family'_mean") value(`r(mean)') format("%5.2f")
}

table_from_tpl, t($table_templates/placebo_index_tpl.tex) r($tmp/placebo_index_data.csv) o($out/placebo_index.tex) dropstars
