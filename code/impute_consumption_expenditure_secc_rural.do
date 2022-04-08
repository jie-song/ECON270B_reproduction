/********************************************/
/* Impute Consumption Expenditure into SECC */
/********************************************/

/* This do-file regresses consumption on household assets by using IHDS data, */
/* estimates the coefficient on each household asset variable, stores the     */
/* coefficients, and calculates the consumption expenditure in SECC data      */

/* Inputs: */
/* IHDS household dataset:   ~/iec1/IHDS2011/36151-0002-Data.dta */
/* IHDS member dataset:      ~/iec1/IHDS2011/36151-0001-Data.dta */
/* SECC rural data:          ~/iec2/secc/final/dta/ */

/* Output: */
/* SECC consumption data:   ~/iec2/secc/final/village_consumption_imputed_pc11 */
/* SECC consumption data:   ~/iec2/secc/final/village_consumption_imputed_pc01 */


/************/
/* Preamble */
/************/

/* store the list of states you would like to compute consumption expenditure */
global statelist andamanandnicobarislands andhrapradesh arunachalpradesh assam bihar chandigarh chhattisgarh dadraandnagarhaveli damananddiu goa gujarat haryana himachalpradesh jammukashmir jharkhand karnataka kerala lakshadweep madhyapradesh maharashtra manipur meghalaya mizoram nagaland nctofdelhi odisha puducherry punjab rajasthan sikkim tamilnadu tripura uttarakhand uttarpradesh westbengal

/* set global for output folder */
global out ~/iec/output/ryu

/* create scratch folder to store ihds temporary data */
cap mkdir $tmp/ihds

/* create a scratch folder to save rural household file with consumption expenditure */
cap mkdir $tmp/secc
cap mkdir $tmp/secc/final
cap mkdir $tmp/secc/final/dta
cap mkdir $tmp/secc/final/collapsed

/* remove csv file that stores tpl if exists */
!rm -f $tmp/secc_rural_impute.csv

  
/******************************/
/* A) Clean up IHDS variables */
/******************************/

/* 1. Clean up the household dataset */

/* use the IHDS household dataset */
use ~/iec1/IHDS2011/36151-0002-Data.dta, clear

/* drop urban observations */
drop if URBAN2011 == 1

/* drop if house ownership is office accomondation or others since these categories do not exist in SECC */
drop if CG1 == 0 | CG1 == 3 | CG1 == 4

/* generate phone variable which indicates the ownership of telephone and cellphone */
gen phone = 0
replace phone = 1 if CG16 == 1 & CG17 == 0
replace phone = 2 if CG16 == 0 & CG17 == 1
replace phone = 3 if CG16 == 1 & CG17 == 1
replace phone = 4 if CG16 == 0 & CG17 == 0
replace phone = . if CG16 == . | CG17 == .

/* generate vehicle variable which indicates the ownership of car and motor vehicle */
gen vehicle = 0
replace vehicle = 1 if CG8 == 1
replace vehicle = 3 if CG21 == 1
replace vehicle = . if CG8 == . | CG21 == .

/* generate farm equipment variable equal to 1 if household owns at least 1 tractor or thresher */
egen mech_farm_equip = rowmax(FM40E FM40F)
replace mech_farm_equip = 1 if mech_farm_equip > 1 & !mi(mech_farm_equip)
replace mech_farm_equip = . if mech_farm_equip == 0 & (mi(FM40E) | mi(FM40F))

/* generate irrigation equipment variable equal to 1 if household owns at least 1 irrigation equipment */
egen irr_equip = rowmax(FM40A FM40B FM40C FM40I FM40J)
replace irr_equip = 1 if irr_equip > 1 & !mi(irr_equip)
replace irr_equip = . if irr_equip == 0 & (mi(FM40A) | mi(FM40B) | mi(FM40C) | mi(FM40I) | mi(FM40J))

/* rename variables of interest */
ren (HQ4 HQ5 CG1 SA1 CG18 FM1 IN15E1) (wall_mat roof_mat house_own num_room refrig land_own kisan_cc)

/* generate dummy variables for each wall material */
//tab wall_mat
gen wall_mat_grass = wall_mat == 1 if !mi(wall_mat)
gen wall_mat_mud = wall_mat == 2 if !mi(wall_mat)
gen wall_mat_plastic = wall_mat == 3 if !mi(wall_mat)
gen wall_mat_wood = wall_mat == 4 if !mi(wall_mat)
gen wall_mat_brick = wall_mat == 5 if !mi(wall_mat)
gen wall_mat_gi = wall_mat == 6 if !mi(wall_mat)
gen wall_mat_stone = wall_mat == 7 if !mi(wall_mat)
gen wall_mat_concrete = wall_mat == 8 if !mi(wall_mat)
gen wall_mat_other = wall_mat == 9 if !mi(wall_mat)

/* generate dummy variables for each roof material */
//tab roof_mat
gen roof_mat_grass = roof_mat == 1 if !mi(roof_mat)
gen roof_mat_tile = roof_mat == 2 if !mi(roof_mat)
gen roof_mat_slate = roof_mat == 3 if !mi(roof_mat)
gen roof_mat_plastic = roof_mat == 4 if !mi(roof_mat)
gen roof_mat_gi = roof_mat == 5 if !mi(roof_mat)
gen roof_mat_brick = roof_mat == 7 if !mi(roof_mat)
gen roof_mat_stone = roof_mat == 8 if !mi(roof_mat)
gen roof_mat_concrete = roof_mat == 9 if !mi(roof_mat)
gen roof_mat_other = roof_mat == 10 if !mi(roof_mat)
replace roof_mat_other = 1 if roof_mat == 6

/* generate dummy variables for eahc house ownership type */
//tab house_own
gen house_own_owned = house_own == 1 if !mi(house_own)
gen house_own_rented = house_own == 2 if !mi(house_own)

/* generate dummy variables for each vehicle ownership type */
//tab vehicle
gen vehicle_two = vehicle == 1 if !mi(vehicle)
gen vehicle_four = vehicle == 3 if !mi(vehicle)

/* generate dummy variables for each phone ownership type */
//tab phone
gen phone_landline_only = phone == 1 if !mi(phone)
gen phone_mobile_only = phone == 2 if !mi(phone)
gen phone_both = phone == 3 if !mi(phone)
gen phone_none = phone == 4 if !mi(phone)

/* save the dataset */
save $tmp/ihds/2011_household_rural.dta, replace

/* 2. Clean up the member dataset */

/* use the IHDS member dataset */
use ~/iec1/IHDS2011/36151-0001-Data.dta, clear

/* generate an indicator variable equal to 1 for all missing of earning for each household */
/* in order to avoid collapse generating 0 when all values are missing */
bys IDHH (WSEARN): gen allmissing = mi(WSEARN[1])

/* generate a variable which indicates the household population */
/* it is initially equal to 1 but will indicate the household population once the data is collapsed to the household level */
gen hh_pop = 1

/* collapse the dataset to household level by taking the max of invidivual earning */
collapse (max) WSEARN (sum) hh_pop (min) allmissing, by(IDHH)

/* replace WSEARN with missing if all values within each household are missing */
replace WSEARN = . if allmissing

/* drop the indicator variable */
drop allmissing

/* rescale WSEARN to monthly income to match SECC variable */
replace WSEARN = WSEARN / 12

/* save the dataset */
save $tmp/ihds/2011_member_rural.dta, replace

/* 3. Merge household and member datasets */

/* use the household dataset */
use $tmp/ihds/2011_household_rural.dta, clear

/* drop if household ID is missing */
drop if mi(IDHH)

/* merge with member dataset */
merge 1:1 IDHH using $tmp/ihds/2011_member_rural.dta, keep(match) nogen 

/* generate high income variable */
gen high_inc = 0
replace high_inc = 1 if WSEARN < 5000
replace high_inc = 2 if WSEARN >= 5000 & WSEARN <= 10000
replace high_inc = 3 if WSEARN > 10000
replace high_inc = . if WSEARN == . 

/* generate dummy variables for high income */
gen high_inc_less_5000 = high_inc == 1 if !mi(high_inc)
gen high_inc_5000_10000 = high_inc == 2 if !mi(high_inc)
gen high_inc_more_10000 = high_inc == 3 if !mi(high_inc)

/* drop if COTOTAL is less than 6000 or greater than 500000 */
drop if COTOTAL < 6000 | COTOTAL > 500000

/* replace the number of room with 10 if it is greater than 10 */
replace num_room = 10 if num_room > 10

/* loop over all the variables in the regression */
foreach var in high_inc_5000_10000 high_inc_more_10000 land_own kisan_cc refrig num_room wall_mat_grass wall_mat_mud wall_mat_plastic wall_mat_wood wall_mat_brick wall_mat_gi wall_mat_stone wall_mat_concrete roof_mat_grass roof_mat_tile roof_mat_slate roof_mat_plastic roof_mat_gi roof_mat_brick roof_mat_stone roof_mat_concrete house_own_owned vehicle_two vehicle_four phone_landline_only phone_mobile_only phone_both {

  /* summarize each variable and write the output into csv file */
  sum `var' [w=WT]
  store_val_tpl using $tmp/secc_rural_impute.csv, name(ihds_hh_rural_`var') value(`r(mean)') format(%5.4f)
}

/* store state id's into local macro */
levelsof STATEID, local(states)

/* loop over all the states in IHDS */
foreach state in `states' {

  /* store state name into local macro */
  if "`state'" == "1" local name jammukashmir
  if "`state'" == "2" local name himachalpradesh
  if "`state'" == "3" local name punjab
  if "`state'" == "4" local name chandigarh
  if "`state'" == "5" local name uttarakhand
  if "`state'" == "6" local name haryana
  if "`state'" == "7" local name nctofdelhi
  if "`state'" == "8" local name rajasthan
  if "`state'" == "9" local name uttarpradesh
  if "`state'" == "10" local name bihar
  if "`state'" == "11" local name sikkim
  if "`state'" == "12" local name arunachalpradesh
  if "`state'" == "13" local name nagaland
  if "`state'" == "14" local name manipur
  if "`state'" == "15" local name mizoram
  if "`state'" == "16" local name tripura
  if "`state'" == "17" local name meghalaya
  if "`state'" == "18" local name assam
  if "`state'" == "19" local name westbengal
  if "`state'" == "20" local name jharkhand
  if "`state'" == "21" local name odisha
  if "`state'" == "22" local name chhattisgarh
  if "`state'" == "23" local name madhyapradesh
  if "`state'" == "24" local name gujarat
  if "`state'" == "26" local name dadranagarhaveli
  if "`state'" == "27" local name maharashtra
  if "`state'" == "28" local name andhrapradesh
  if "`state'" == "29" local name karnataka
  if "`state'" == "30" local name goa
  if "`state'" == "32" local name kerala
  if "`state'" == "33" local name tamilnadu
  if "`state'" == "34" local name puducherry
  
  /* summarize the consumption for each state and write the output into csv file */
  sum COTOTAL if STATEID == `state'
  store_val_tpl using $tmp/secc_rural_impute.csv, name(ihds_hh_rural_`name'_con) value(`r(mean)') format(%10.2f)

  /* summarize the consumption per capital for each state and write the output into csv file */
  sum COPC if STATEID == `state'
  store_val_tpl using $tmp/secc_rural_impute.csv, name(ihds_hh_rural_`name'_conpc) value(`r(mean)') format(%10.2f)

  /* summarize the household population for each state and write the output into csv file */
  sum hh_pop if STATEID == `state'
  store_val_tpl using $tmp/secc_rural_impute.csv, name(ihds_hh_rural_`name'_hh_pop) value(`r(mean)') format(%10.2f)
}

/* save the IHDS merged dataset */
save $tmp/ihds/2011_household_member_rural.dta, replace


/*********************/
/* B) Run regression */
/*********************/

/* use the IHDS merged dataset */
use $tmp/ihds/2011_household_member_rural.dta, clear

/* keep necessary variables for regression */
keep *ID COTOTAL wall_mat_* roof_mat_* house_own_* vehicle_* phone_* high_inc_* num_room refrig land_own kisan_cc mech_farm_equip irr_equip hh_pop *WT

/* store the varlist */
local varlist land_own kisan_cc refrig num_room wall_mat_grass wall_mat_mud wall_mat_plastic wall_mat_wood wall_mat_brick wall_mat_gi wall_mat_stone wall_mat_concrete roof_mat_grass roof_mat_tile roof_mat_slate roof_mat_plastic roof_mat_gi roof_mat_brick roof_mat_stone roof_mat_concrete house_own_owned vehicle_two vehicle_four phone_landline_only phone_mobile_only phone_both high_inc_5000_10000 high_inc_more_10000

/* loop over all variables stored above */
foreach var in `varlist' {

  /* store label name and replace label */
  local label = subinstr("`var'", "_", "\_", .)
  label var `var' "`label'"
}

/* run regression on consumption expenditure */
reg COTOTAL `varlist' [pweight = WT], robust

/* tokenize varlist in order to save the name of varialbes of interest */
tokenize `varlist'

/* store the number of variables */
local nv: word count `varlist' 

/* loop from 1 to 28 since there are 28 coefficients */
forvalue i = 1/`nv' {

  /* store each beta */
  local beta`i' = _b[``i'']
}

/* store constant */
local constant = _b[_cons]


/*********************************************************/
/* C) Collapse SECC rural member file to household level */
/*********************************************************/

/* loop over the states in which you would like to compute consumption expenditure */
foreach state in $statelist {

  /* print out file name */
  disp_nice "`state'"
  
  /* use secc rural members file */
  use ~/iec2/secc/final/dta/`state'_members_clean, clear

  /* drop if no id */
  drop if mi(pc11_village_id)
  
  /* replace missing age with 40 */
  /* these individuals exist for sure, thus not drop from the dataset */
  replace age = 40 if age < 0

  /* generate household population variable initially equal to 1 */
  /* it will indicate the household population once the data is collapsed to the household level  */
  gen hh_pop = 1
  
  /* generate scaled household population variable */
  /* since the adequate consumption levels for children */
  /* and for additional adults after the first two adults */
  /* are different from that for the first two adults */
  gen hh_pop_scaled = 1
  replace hh_pop_scaled = .75 if age < 15
  bys pc11_state_id pc11_village_id mord_hh_id_trim: egen seq = seq() if age >= 15 
  replace hh_pop_scaled = .85 if seq > 2 & !mi(seq)
  
  /* collapse rural members file down to household level */
  /* in order to calculate each household population */
  /* and sum up the scaled household population */
  collapse (sum) hh_pop hh_pop_scaled, by(pc11_state_id pc11_village_id mord_hh_id_trim)

  /* save the member file collapsed down to household level in scratch folder */
  compress
  save $tmp/secc/final/collapsed/`state'_members_clean, replace
}

/************************************************/
/* D) Generate consumption expenditure for SECC */
/************************************************/

/* loop over secc rural household file */
foreach state in $statelist {

  /* print out file name */
  disp_nice "`state'"

  /* use secc rural household file */
  use ~/iec2/secc/final/dta/`state'_household_clean, clear

  /* merge in household members number */
  merge m:1 pc11_state_id pc11_village_id mord_hh_id_trim using $tmp/secc/final/collapsed/`state'_members_clean
  keep if _merge == 3
  drop _merge

  /* drop top one percent household size */
  sum hh_pop, d
  drop if hh_pop > `r(p99)'

  /* loop over land_own, kisan_cc, refrig, and num_room variable */
  foreach x in land_own kisan_cc refrig num_room wall_mat roof_mat house_own vehicle phone high_inc {
    
    /* replace num_room with missing if it's missing or bad translation */  
    replace `x' = . if `x' == -9999 | `x' == -9998
  }

  /* generate dummy variables for each wall materials */
  gen wall_mat_grass = wall_mat == 1 if !mi(wall_mat)
  gen wall_mat_mud = wall_mat == 3 if !mi(wall_mat)
  gen wall_mat_plastic = wall_mat == 2 if !mi(wall_mat)
  gen wall_mat_wood = wall_mat == 4 if !mi(wall_mat)
  gen wall_mat_brick = wall_mat == 8 if !mi(wall_mat)
  gen wall_mat_gi = wall_mat == 7 if !mi(wall_mat)
  gen wall_mat_stone = wall_mat == 5 if !mi(wall_mat)
  replace wall_mat_stone = 1 if wall_mat == 6
  gen wall_mat_concrete = wall_mat == 9 if !mi(wall_mat)

  /* generate dummy variables for each roof material */
  gen roof_mat_grass = roof_mat == 1 if !mi(roof_mat)
  gen roof_mat_tile = roof_mat == 3 if !mi(roof_mat)
  replace roof_mat_tile = 1 if roof_mat == 4
  gen roof_mat_slate = roof_mat == 7 if !mi(roof_mat)
  gen roof_mat_plastic = roof_mat == 2 if !mi(roof_mat)
  gen roof_mat_gi = roof_mat == 8 if !mi(roof_mat)
  gen roof_mat_brick = roof_mat == 5 if !mi(roof_mat)
  gen roof_mat_stone = roof_mat == 6 if !mi(roof_mat)
  gen roof_mat_concrete = roof_mat == 9 if !mi(roof_mat)

  /* generate dummy variables for each house ownership type */
  gen house_own_owned = house_own == 1 if !mi(house_own)

  /* generate dummy variables for each vehicle ownership type */
  gen vehicle_two = vehicle == 1 if !mi(vehicle)
  gen vehicle_four = vehicle == 3 if !mi(vehicle)

  /* generate dummy variables for each phone ownership type */
  gen phone_landline_only = phone == 1 if !mi(phone)
  gen phone_mobile_only = phone == 2 if !mi(phone)
  gen phone_both = phone == 3 if !mi(phone)

  /* generate dummy variables for high income */
  gen high_inc_5000_10000 = high_inc == 2 if !mi(high_inc)
  gen high_inc_more_10000 = high_inc == 3 if !mi(high_inc)

  /* generate consumption variable, starting  with constant */
  gen secc_cons = `constant'
  
  /* loop from 1 to 28 */
  forvalue i = 1/`nv' {

    /* update consumption variable by adding the product of the coefficient and variable value */
    replace secc_cons  = secc_cons + `beta`i'' * ``i''
  }

  /* drop if consumption is missing */
  drop if mi(secc_cons)

  /* examine consumption to make sure it is reasonable */
  sum secc_cons
  store_val_tpl using $tmp/secc_rural_impute.csv, name(secc_hh_rural_`state'_con) value(`r(mean)') format(%10.2f)

  /* compute the mean per capita consumption for each household */
  gen secc_cons_pc = secc_cons / hh_pop

  /* summarize the consumption per capita and write the output into csv file */
  sum secc_cons_pc
  store_val_tpl using $tmp/secc_rural_impute.csv, name(secc_hh_rural_`state'_conpc) value(`r(mean)') format(%10.2f)  
  
  /* calculate asset index */
  factor land_own kisan_cc refrig wall_mat_grass wall_mat_mud wall_mat_plastic wall_mat_wood wall_mat_brick wall_mat_gi wall_mat_stone wall_mat_concrete roof_mat_grass roof_mat_tile roof_mat_slate roof_mat_plastic roof_mat_gi roof_mat_brick roof_mat_stone roof_mat_concrete house_own_owned vehicle_two vehicle_four phone_landline_only phone_mobile_only phone_both high_inc_5000_10000 high_inc_more_10000
  predict index

  /* summarize the household population and write the output into csv file */
  sum hh_pop
  store_val_tpl using $tmp/secc_rural_impute.csv, name(secc_hh_rural_`state'_hh_pop) value(`r(mean)') format(%10.2f)

  /* save the household file with consumption expenditure in scratch folder */
  compress
  save $tmp/secc/final/dta/`state'_consumption, replace
}


/****************************/
/* E) Compute poverty rates */
/****************************/

/* create a directory for saving hh-level consumption */
cap mkdir $tmp/hh_rural_cons_tmp

/* loop over the states in which you would like to compute consumption expenditure */
foreach state in $statelist {

  /* print out state name */
  disp_nice "`state'"

  /* use secc rural household file */
  use $tmp/secc/final/dta/`state'_consumption, clear

  /* drop duplicate households */
  drop if flag_duplicates == 1

  /* drop duplicates on trimmed household ids */
  ddrop pc11_state_id pc11_village_id mord_hh_id_trim 
  
  /* generate an indicator variable for household below poverty line */
  /* which is defined as 31 rupees per capita per day */
  gen secc_pov_rate = 0
  replace secc_pov_rate = 1 if (secc_cons / (365 * hh_pop)) < 31
  replace secc_pov_rate = . if mi(secc_cons)

  /* also generate an indicator variable for household below poverty line defined by Tendulkar */
  /* which is defined as 27 rupees per capita per day */
  gen secc_pov_rate_tend = 0
  replace secc_pov_rate_tend = 1 if (secc_cons / (365 * hh_pop)) < 27
  replace secc_pov_rate_tend = . if mi(secc_cons)

  /* create per-capita consumption vars */
  gen secc_cons_per_cap = secc_cons / hh_pop

  /* consupmtion scaled for children and additional adults after the
  first two adults */
  gen secc_cons_per_cap_scaled = secc_cons / hh_pop_scaled

  /* now save the household-level consumption data to scratch - we
  will zip this up and put it in a permanent folder for use as needed */
  save $tmp/hh_rural_cons_tmp/`state'_hh_consumption, replace

  /* drop the consumption vars so they don't get in the way of
  regeneration post-collapse */
  drop secc_cons_per_cap secc_cons_per_cap_scaled
  
  /* sort by household consumption within each village */
  gsort pc11_state_id pc11_village_id -secc_cons

  /* loop over from 1 to 99 */
  forvalue i = 1/99 {
    
    /* generate variables that indicate every percentiles of household consumption in each village */
    bys pc11_state_id pc11_village_id: egen secc_cons_per_hh_p`i' = pctile(secc_cons), p(`i')
  }

  /* sort by per capita consumption within each village */
  gsort pc11_state_id pc11_village_id -secc_cons_pc

  /* loop over from 1 to 99 */
  forvalue i = 1/99 {
    
    /* generate variables that indicate every percentiles of per capita consumption in each village */
    bys pc11_state_id pc11_village_id: egen secc_cons_per_cap_p`i' = pctile(secc_cons_pc), p(`i')
  }
  
  /* generate a variable which indicates the number of households in each village */
  /* it is initially equal to 1 but will indicate the number of households after the data is collapsed the village level */
  gen secc_hh = 1

  /* generate an indicator variable equal to 1 for all missing of consumption for each village */
  /* in order to avoid collapse generating 0 when all values are missing */
  bys pc11_state_id pc11_village_id (secc_cons): gen allmissing = mi(secc_cons[1])
  
  /* collapse rural household file to village level */
  /* in order to calculate the total village consumption, village population, */
  /* scaled village population, and the share of households below the poverty line in each village */
  collapse (sum) secc_hh secc_pop=hh_pop secc_pop_scaled=hh_pop_scaled secc_cons (mean) secc_pov_rate secc_pov_rate_tend hh_size=hh_pop secc_asset_index=index land_own kisan_cc refrig num_room wall_mat_* roof_mat_* house_own_* vehicle_* phone_* high_inc_* (firstnm) secc_cons_*_p* (min) allmissing, by(pc11_state_id pc11_village_id)

  /* replace consumption with missing if all values for consumption in the village are missing */
  replace secc_cons = . if allmissing

  /* drop an indicator variable for all missing */
  drop allmissing
  
  /* calculate the mean household consumption */
  gen secc_cons_per_hh = secc_cons / secc_hh

  /* calculate the mean per capita consumption */
  gen secc_cons_per_cap = secc_cons / secc_pop

  /* calculate the mean per capita consumption */
  /* scaled for children and additional adults after the first two adults */
  gen secc_cons_per_cap_scaled = secc_cons / secc_pop_scaled

  /* summarize the poverty rate and wriet the output into csv file */
  replace secc_pov_rate = secc_pov_rate * 100
  sum secc_pov_rate
  store_val_tpl using $tmp/secc_rural_impute.csv, name(secc_village_rural_`state'_pov) value(`r(mean)') format(%10.2f)

  /* summarize the Tendulkar poverty rate and wriet the output into csv file */
  replace secc_pov_rate_tend = secc_pov_rate_tend * 100
  sum secc_pov_rate_tend
  store_val_tpl using $tmp/secc_rural_impute.csv, name(secc_village_rural_`state'_pov_tend) value(`r(mean)') format(%10.2f)
  
  /* save the household file collapsed down to the village level */
  compress
  save $tmp/secc/final/collapsed/`state'_consumption, replace
}
  
/* zip up the hh-level consumption and save it */
!tar czfv ~/iec1/working/consumption/hh_rural_cons.tar.gz $tmp/hh_rural_cons_tmp/
  

/****************************************************/
/* F) Append the state files into master India file */
/****************************************************/

/* start with an empty dataset and append all files by state */
clear
save $tmp/secc/final/india_consumption, replace emptyok 

/* loop over the states in which the user wants to compute consumption expenditure */
foreach state in $statelist {

  /* append collapsed secc rural household files across states */
  use $tmp/secc/final/collapsed/`state'_consumption, clear 
  append using $tmp/secc/final/india_consumption
  save $tmp/secc/final/india_consumption, replace 
}

/* loop over all the variables in the regression */
foreach var in `varlist' {

  /* summarize each variable and write  */
  sum `var'
  store_val_tpl using $tmp/secc_rural_impute.csv, name(secc_village_rural_`var') value(`r(mean)') format(%5.4f)
}



/****************************************************************************/
/* NOTE: CONVERSION OF $2 PPP TO RUPEES                                     */
/* GDP per capita (current US$) of India in 2012: 1,446.985                 */
/* GDP per capita (PPP) of India in 2012: 4,916.486                         */
/* Exchange rate between Indian rupee and US dollar in 2012: 53.427         */
/* Thus, $2 PPP is equal to 2 * 1,446.985 / 4,916.486 * 53.427 = 31 rupees  */
/****************************************************************************/



