/* first stage */

/* load settings */
do $pmgsy_code/settings

/* load data */
use $pmgsy_data/pmgsy_working_aer, clear

/* table */
cap rm $tmp/fs_by_band_data.csv
foreach i in $rdbands {
  reg r2012 t left right $controls i.vhg_dist_id [aw = kernel_${kernel}_`i'] if $states & rd_band_`i' & $noroad & $nobad, robust
  store_est_tpl using $tmp/fs_by_band_data.csv, all coef(t) name(t`i')
  test t
  store_val_tpl using $tmp/fs_by_band_data.csv, name("t`i'_f") value(`r(F)') format("%7.1f")
}
table_from_tpl, t($table_templates/fs_by_band_tpl.tex) r($tmp/fs_by_band_data.csv) o($out/fs_by_band.tex) dropstars

/* binscatter */
rd r2012 v_pop if mainsample, bw xq(bins20) xtitle("Normalized population") ytitle("New road by 2012") msize(small) ylabel(,labsize(small)) degree(1) start(-84) end(84) 
graph export $out/bin_r2012_leftright_bandik_nocontrols_ci.eps, replace
graphout          bin_r2012_leftright_bandik_nocontrols_ci
!epstopdf    $out/bin_r2012_leftright_bandik_nocontrols_ci.eps

