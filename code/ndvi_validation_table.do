/* validation of satellite data as an agricultural proxy */

/* load settings */
do $pmgsy_code/settings

/**************************/
/* (1) Prep district data */
/**************************/

/* merge together ndvi and evi data - not restricting to pmgsy sample
to get full district obs */
use $ndvi/ndvi_pc01.dta, clear
merge 1:1 pc01_state_id pc01_village_id using $ndvi/evi_pc01.dta
keep if _merge == 3
drop _merge

/* bring in shrid to merge in shrug */
merge 1:1 pc01_state_id pc01_village_id using $shrug_keys/shrug_pc01r_key
keep if _merge == 3
drop _merge

/* collapse to shrid */
collapse (sum) *delta*, by(shrid pc01_state_id pc01_district_id pc01_village_id)

/* drop duplicate shrug ids */
ddrop shrid

/* merge in village areas */
merge 1:1 shrid using $shrug_data/shrug_pcec, keepusing(pc01_vd_area)
keep if _merge == 3
drop _merge

/* remove zero-area villages */
drop if pc01_vd_area == 0 | mi(pc01_vd_area)

/* area-weight before collapsing to district */
bysort pc01_state_id pc01_district_id : egen pc01_vd_area_district = total(pc01_vd_area)
foreach var of varlist ndvi* evi* {
  replace `var' = `var' * (pc01_vd_area / pc01_vd_area_district)
}

/* aggregate ndvi to district */
collapse (sum) ndvi* evi* pc01_vd_area, by(pc01_state_id pc01_district_id)

/* gen state and dist groupings */
egen state_id = group(pc01_state_id)
egen dist_id = group(pc01_district_id)

/* merge in the superdistrict key, keeping only districts for which there is a match */
merge 1:1 pc01_state_id pc01_district_id using $keys/pc91pc01districtkey_01superdist.dta, keepusing(superdist)
keep if _merge == 3
drop _merge

/* area-weight before collapsing to superdist */
bysort superdist : egen pc01_vd_area_superdist = total(pc01_vd_area)
foreach var of varlist ndvi* {
  replace `var' = `var' * (pc01_vd_area / pc01_vd_area_superdist)
}

/* keep only the years for which there is good earnings data */
order superdist ndvi_delta_k* evi_delta_k*, first
keep ndvi_delta_k_2000 - ndvi_delta_k_2006 evi_delta_k_2000 - evi_delta_k_2006 superdist

/* collapse to superdist */
collapse (sum) ndvi* evi*, by(superdist)

/* transform to long so we can run a fixed effects panel regression on it */
reshape long ndvi_delta_k_ evi_delta_k_, i(superdist) j(year)

/* rename our var - get rid of trailing underscore */
rename ndvi_delta_k_ ndvi_delta
rename evi_delta_k_ evi_delta

/* winsorize */
foreach var of varlist ndvi* evi* {
  winsorize `var' 1 99, centile gen(temp_win)
  replace `var' = temp_win
  label var `var' "winsorized"
  drop temp_win
}

/* save as our ndvi backbone */
save $tmp/ndvi_for_ddp, replace


/* prep our in agricultural earnings data */
use $ddp/ddp_master_nddp_price05_long, clear

/* keep ag only */
keep if sector == "ag"

/* keep years with decent amount of obs */
drop if year == 2007 | year == 2008

/* keep only vars we need */
keep pc01* superdist year ddp 

/* merge in the ndvi data */
merge 1:1 superdist year using $tmp/ndvi_for_ddp, keepusing(ndvi_delta evi_delta) keep(match master) nogen

/* generate state_id for fixed effects */
egen state_id = group(pc01_state_id)

/* drop zeroes */
drop if ndvi_delta == 0
drop if evi_delta == 0

/* logs */
foreach y in ndvi_delta evi_delta ddp {
  gen ln_`y' = log(`y' + 1)
}

/* save as our working dataset */
save $tmp/ndvi_evi_ddp_regdata, replace


/********************************/
/* (2) Village level validation */
/********************************/

/* correlate NDVI with irrigation share and crop suitability vars */

/* use full sample of villages, not just pmgsy main sample */
use $pmgsy_data/pmgsy_working_aer, clear

/* keep vars we need */
keep *delta* evi* cropsuit* any_irr_acre_share pc01*id mainsample secc_cons_per_cap cons_pc_win_ln dist_id state_id pc01_state_name

/* create logged crop suitability */
gen cs_l_ln = log(cropsuit_rf_c_low)

/* clear out our regression data csv */
cap rm $tmp/ndvi_validation_data.csv

/* now run our regressions of interest and store them. ndvi and evi */
foreach type in ndvi evi {

  /* regress all three of our correlates to get the consistent sample */
  reg `type'_delta_2011_2013_ln  cs_l_ln any_irr_acre_share cons_pc_win_ln i.dist_id if inlist(pc01_state_name, "chhattisgarh", "gujarat", "madhya pradesh", "maharashtra", "orissa", "rajasthan"), r
  store_est_tpl using $tmp/ndvi_validation_data.csv, all coef(cs_l_ln) name(`type'_cropsuit_all)
  store_est_tpl using $tmp/ndvi_validation_data.csv, all coef(any_irr_acre_share) name(`type'_irr_all)
  store_est_tpl using $tmp/ndvi_validation_data.csv, all coef(cons_pc_win_ln) name(`type'_cons_all)
  cap drop `type'_sample
  gen `type'_sample = e(sample)

  /* first crop suit */
  reg `type'_delta_2011_2013_ln  cs_l_ln  i.dist_id if `type'_sample, r
  store_est_tpl using $tmp/ndvi_validation_data.csv, all coef(cs_l_ln) name(`type'_cropsuit)

  /* now irrigation share */
  reg `type'_delta_2011_2013_ln  any_irr_acre_share i.dist_id if `type'_sample, r
  store_est_tpl using $tmp/ndvi_validation_data.csv, all coef(any_irr_acre_share) name(`type'_irr)

  /* now consumption per capita (winsorized and logged) */
  reg `type'_delta_2011_2013_ln   cons_pc_win_ln i.dist_id if `type'_sample, r
  store_est_tpl using $tmp/ndvi_validation_data.csv, all coef(cons_pc_win_ln) name(`type'_cons)
}


/*********************************/
/* (3) District level validation */
/*********************************/

/* DISTRICT REGS */
use $tmp/ndvi_evi_ddp_regdata, clear

/* NDVI regs */
/* we will add to the existing validation datafile for our tables - $tmp/ndvi_validation_data.csv */

/* state FE */
regress ln_ndvi_delta ln_ddp i.state, robust
store_est_tpl using $tmp/ndvi_validation_data.csv, all coef(ln_ddp) name(ndvi_ddp_state) format("%4.3f")

/* state-year */
regress ln_ndvi_delta ln_ddp i.state_id##i.year, robust
store_est_tpl using $tmp/ndvi_validation_data.csv, all coef(ln_ddp) name(ndvi_ddp_state_year) format("%4.3f")

/* district */
regress ln_ndvi_delta ln_ddp i.superdist, robust
store_est_tpl using $tmp/ndvi_validation_data.csv, all coef(ln_ddp) name(ndvi_ddp_dist) format("%4.3f")

/* district, year */
regress ln_ndvi_delta ln_ddp i.superdist i.year, robust
store_est_tpl using $tmp/ndvi_validation_data.csv, all coef(ln_ddp) name(ndvi_ddp_dist_year) format("%4.3f")

/* same EVI regs */
/* we will add to the existing validation datafile for our tables - $tmp/ndvi_validation_data.csv */

/* state FE */
regress ln_evi_delta ln_ddp i.state, robust
store_est_tpl using $tmp/ndvi_validation_data.csv, all coef(ln_ddp) name(evi_ddp_state) format("%4.3f")

/* state-year */
regress ln_evi_delta ln_ddp i.state_id##i.year, robust
store_est_tpl using $tmp/ndvi_validation_data.csv, all coef(ln_ddp) name(evi_ddp_state_year) format("%4.3f")

/* district */
regress ln_evi_delta ln_ddp i.superdist, robust
store_est_tpl using $tmp/ndvi_validation_data.csv, all coef(ln_ddp) name(evi_ddp_dist) format("%4.3f")

/* district, year */
regress ln_evi_delta ln_ddp i.superdist i.year, robust
store_est_tpl using $tmp/ndvi_validation_data.csv, all coef(ln_ddp) name(evi_ddp_dist_year) format("%4.3f")

/* MAKE THE NDVI TABLE */
table_from_tpl, t($table_templates/ndvi_ag_validation_tpl.tex) r($tmp/ndvi_validation_data.csv) o($out/ndvi_evi_validation.tex) 
table_from_tpl, addstars t($table_templates/ndvi_ag_validation_tpl.tex) r($tmp/ndvi_validation_data.csv) o($out/ndvi_evi_validation_stars.tex)
