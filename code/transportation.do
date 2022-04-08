do $pmgsy_code/settings

use $pmgsy_data/pmgsy_working_aer_mainsample, clear

/* genereate table */
eststo clear
foreach y in bus_gov bus_priv taxi vans auto {
  ivregress 2sls pc11_vd_`y'  (r2012 = t) left right  $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample, vce(robust)
  sum pc11_vd_`y' if e(sample) & t == 0
  estadd scalar outcome_mean = r(mean)
  eststo
}
estout using $out/transportation.tex, keep(r2012) mlabel("Gov Bus" "Private Bus" "Taxi" "Van" "Autorickshaw") $estout_params_means_outcome
