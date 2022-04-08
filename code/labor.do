use $pmgsy_data/pmgsy_working_aer_mainsample, clear
do $pmgsy_code/settings

/* labor market outcomes */
foreach var in cultiv manlab {

  ivregress 2sls secc_inc_`var'_share (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_${kernel}_${mainband}] if mainsample, first vce(robust)
  sum secc_inc_`var'_share if e(sample) & t == 0
  estadd scalar outcome_mean = r(mean)
  eststo `var'rd_inc
  
  ivregress 2sls nco2d_`var'_share (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_${kernel}_${mainband}] if mainsample, first vce(robust)
  sum nco2d_`var'_share if e(sample) & t == 0
  estadd scalar outcome_mean = r(mean)
  eststo `var'rd_occ
}

/* output table */
estout cultivrd_occ manlabrd_occ cultivrd_inc manlabrd_inc using $out/labor_shift_rd_final.tex, keep(r2012) mlabel("Agriculture" "Manual Labor" "Agriculture" "Manual Labor") mgroups("Occupation" "Household Income Source", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) $estout_params_means_outcome

* robustness check to the exclusion of top and bottom 0.5 percentile of outcome values
use $pmgsy_data/pmgsy_working_aer_mainsample, clear
do $pmgsy_code/settings

foreach var in cultiv manlab {
	
	egen bot_secc_inc_`var'_share = pctile(secc_inc_`var'_share), p(0.05)
	egen top_secc_inc_`var'_share = pctile(secc_inc_`var'_share), p(99.5)
	
	gen dm_trim_secc_inc_`var'_share = 1 if secc_inc_`var'_share <= bot_secc_inc_`var'_share | secc_inc_`var'_share >= top_secc_inc_`var'_share
	
  ivregress 2sls secc_inc_`var'_share (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_${kernel}_${mainband}] if mainsample & dm_trim_secc_inc_`var'_share != 1, first vce(robust)
  sum secc_inc_`var'_share if e(sample) & t == 0
  estadd scalar outcome_mean = r(mean)
  eststo `var'rd_inc

	egen bot_nco2d_`var'_share = pctile(nco2d_`var'_share), p(0.05)
	egen top_nco2d_`var'_share = pctile(nco2d_`var'_share), p(99.5)
	
	gen dm_trim_nco2d_`var'_share = 1 if nco2d_`var'_share <= bot_nco2d_`var'_share | nco2d_`var'_share >= top_nco2d_`var'_share
	
  ivregress 2sls nco2d_`var'_share (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_${kernel}_${mainband}] if mainsample & dm_trim_nco2d_`var'_share != 1, first vce(robust)
  sum nco2d_`var'_share if e(sample) & t == 0
  estadd scalar outcome_mean = r(mean)
  eststo `var'rd_occ
}


/* output table */
estout cultivrd_occ manlabrd_occ cultivrd_inc manlabrd_inc using $out/labor_shift_rd_rob_trim.tex, keep(r2012) mlabel("Agriculture" "Manual Labor" "Agriculture" "Manual Labor") mgroups("Occupation" "Household Income Source", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) $estout_params_means_outcome

* robustness check to clustering standard errors on district level 

foreach var in cultiv manlab {

  ivregress 2sls secc_inc_`var'_share (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_${kernel}_${mainband}] if mainsample, first cluster(pc01_district_id)
  sum secc_inc_`var'_share if e(sample) & t == 0
  estadd scalar outcome_mean = r(mean)
  eststo `var'rd_inc
  
  ivregress 2sls nco2d_`var'_share (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_${kernel}_${mainband}] if mainsample, first cluster(pc01_district_id)
  sum nco2d_`var'_share if e(sample) & t == 0
  estadd scalar outcome_mean = r(mean)
  eststo `var'rd_occ
}

/* output table */
estout cultivrd_occ manlabrd_occ cultivrd_inc manlabrd_inc using $out/labor_shift_rd_cluster.tex, keep(r2012) mlabel("Agriculture" "Manual Labor" "Agriculture" "Manual Labor") mgroups("Occupation" "Household Income Source", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) $estout_params_means_outcome
