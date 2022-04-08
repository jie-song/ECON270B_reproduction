/* consumption percetile plot */

/* load settings */
do $pmgsy_code/settings

/* percentile consumption plot */
local range 5(5)95

forval pctile = `range' {

  /* use the individual pctile file - these won't be in the master
  file, too many vars! */
  use $pmgsy_data/percentiles/secc_cons_imputed_p`pctile', clear

  /* merge in the other things we need for regressing */
  merge 1:1 pc01_state_id pc01_village_id using $pmgsy_data/cons_boot_in, keepusing(r2012 t left right $controls vhg_dist_id kernel_tri_$mainband mainsample)
  keep if _merge == 3
  drop _merge
  
  /* show our progress */
  disp_nice "working on the `pctile'th percentile - `c(current_time)'"

  /* then create intermediary datafiles for each of our ps */
  local int_f $tmp/cons_pct_coefs_p`pctile'_boot_int.csv
  cap erase `int_f'

  /* now run the bootstrap */
  cons_boot, outfile("`int_f'") name(pc_p`pctile') spec("ivregress 2sls secc_cons_pcBOOTSTRAPNUM_p`pctile'_ln (r2012 = t) left right $controls i.vhg_dist_id [aw = weight_BOOTSTRAPNUM] if mainsample, vce(robust)") 
}

/* now create our data that will be used for the plot - mean across
1000 bootstraps for beta and CI for each of the percentiles. */
cap rm $tmp/cons_pct_coefs_boot_final.csv
append_to_file using $tmp/cons_pct_coefs_boot_final.csv, s(pctile,beta,beta_high,beta_low)

/* bring in the each pctile datafile and modify it to get mean beta,
upper bound, and lower bound. */
local range 5(5)95
forval pctile = `range' {

  /* specify the input data file - which was the output file from
  cons_boot */
  local f $tmp/cons_pct_coefs_p`pctile'_boot_int.csv

  insheet using `f', clear
  gen beta_high = beta + 1.96 * se
  gen beta_low  = beta - 1.96 * se

  /* get means of beta, beta_high, and beta_low across our 1,000 bootstraps */
  foreach var in beta beta_high beta_low {
    qui sum `var', d
    local `var' `r(mean)'
  }

  /* write out our plotting data for this percentile to our csv */
  append_to_file using $tmp/cons_pct_coefs_boot_final.csv, s(`pctile',`beta',`beta_high',`beta_low')
}
    
/* read in our pretty data */
insheet using $tmp/cons_pct_coefs_boot_final.csv, clear

/* draw our percentile plot */
twoway (scatter beta pctile, mcolor(black)) (rcap beta_high beta_low pctile, yline(0, lcolor(gs8)) xtitle("Percentile in village consumption distribution") ytitle("Coefficient of new road on log consumption/capita") graphregion(color(white)) legend(off))
graph export $out/pmgsy_cons_pctiles.eps, replace
!epstopdf $out/pmgsy_cons_pctiles.eps
