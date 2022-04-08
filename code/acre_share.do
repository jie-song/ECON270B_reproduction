use $pmgsy_data/pmgsy_working_aer_mainsample, clear
do $pmgsy_code/settings

/* share of households owning each land size */
eststo clear
foreach i in landless 02 24 4p {
  ivregress 2sls secc_acre_`i'_share (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_${kernel}_${mainband}] if mainsample, vce(robust)
  sum secc_acre_`i'_share if e(sample) & t == 0
  estadd scalar outcome_mean = r(mean)
  eststo
}
estout using $out/acre_share_rd.tex, keep(r2012) mlabel("Landless" "0-2 Acres" "2-4 Acres" "4+ Acres") $estout_params_means_outcome
