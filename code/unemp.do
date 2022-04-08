/* load data and settings */
use $pmgsy_data/pmgsy_working_aer_mainsample, clear
qui do $pmgsy_code/settings.do

/* generate table */
eststo clear
foreach y in secc_nco04_1d_Y_share secc_nco04_1d_Z_share {
  ivregress 2sls `y' (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_${kernel}_${mainband}] if mainsample,  vce(robust)
  sum `y' if t == 0 & e(sample)
  estadd scalar outcome_mean = r(mean)
  eststo
}
estout using $out/unemp_unclass_rd.tex, keep(r2012) mlabel("Unemployed" "Unclassifiable") $estout_params_means_outcome
