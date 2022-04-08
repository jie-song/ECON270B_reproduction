/*
This do file prepares necessary data to recreate PMGSY consumption
tables following the double-bootstrapping procedure.

hh_man_ag and edmax_3bin - both 3-bin categoricals at the household
level - require collapsing secc consumption vars to the village level
SPLIT by the three levels of each variable. 

note that household-level imputation of the secc consumption data are
required for poverty rates. 
*/

/***** TABLE OF CONTENTS *****/
/* (1) Preamble */
/* (2) Create bootstrapped IHDS consumption betas */
/* (3) Create additional household-level vars */
/* (4) prep program for collapsing hh_man_ag and edmax_3bin consumption data */
/* (5) Collapse consumption data component variables in parallel */
/* (6) Create bootstrapped hh_man_ag and edmax_3bin consumption data */
/* (7) Household-level imputations */
/* (8) Prepare for regressing */



/****************/
/* (1) Preamble */
/****************/

/* expand the maximum number of variables we can create in a dataset */
clear all
clear mata
set maxvar 30000, permanently

/* make sure we have settings up to date */
qui do $pmgsy_code/settings.do

/* create required scratch directory */
cap mkdir $tmp/bootstrap
      

/**************************************************/
/* (2) Create bootstrapped IHDS consumption betas */
/**************************************************/

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
gen house_own_owned = house_own == 1 if !mi(house_own)
gen house_own_rented = house_own == 2 if !mi(house_own)

/* generate dummy variables for each vehicle ownership type */
gen vehicle_two = vehicle == 1 if !mi(vehicle)
gen vehicle_four = vehicle == 3 if !mi(vehicle)

/* generate dummy variables for each phone ownership type */
gen phone_landline_only = phone == 1 if !mi(phone)
gen phone_mobile_only = phone == 2 if !mi(phone)
gen phone_both = phone == 3 if !mi(phone)
gen phone_none = phone == 4 if !mi(phone)

/* save the dataset */
cap mkdir $tmp/ihds
save $tmp/ihds/2011_household.dta, replace

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

/* save members to tmp */
save $tmp/ihds/2011_member.dta, replace

/* use the household dataset */
use $tmp/ihds/2011_household.dta, clear

/* drop if household ID is missing */
drop if mi(IDHH)

/* merge with member dataset */
merge 1:1 IDHH using "$tmp/ihds/2011_member.dta", keep(match) nogen 

/* generate high income variable */
gen high_inc = 0
replace high_inc = 1 if WSEARN < 5000
replace high_inc = 2 if WSEARN >= 5000 & WSEARN <= 10000
replace high_inc = 3 if WSEARN > 10000 & !mi(WSEARN)
replace high_inc = . if WSEARN == . 

/* generate dummy variables for high income */
gen high_inc_less_5000 = high_inc == 1 if !mi(high_inc)
gen high_inc_5000_10000 = high_inc == 2 if !mi(high_inc)
gen high_inc_more_10000 = high_inc == 3 if !mi(high_inc)

/* drop if COTOTAL is less than 6000 or greater than 500000 */
drop if COTOTAL < 6000 | COTOTAL > 500000

/* replace the number of room with 10 if it is greater than 10 */
replace num_room = 10 if num_room > 10

/* summarize COTOTAL to make sure that we don't have outliers */
sum COTOTAL, d

/* save the IHDS merged dataset */
save $tmp/ihds/2011_household_member_merged.dta, replace

/* Bootstrap time. start with the hh-level IHDS data in scratch */
use $tmp/ihds/2011_household_member_merged.dta, clear

/* keep the vars we need for regressing */
keep COTOTAL wall_mat_* roof_mat_* house_own_* vehicle_* phone_* high_inc_* num_room refrig land_own kisan_cc mech_farm_equip irr_equip *WT

/* remove variables that will be ommited due to collinearity if included in regression */
ds COTOTAL wall_mat_other roof_mat_other house_own_rented phone_none high_inc_less_5000 mech_farm_equip irr_equip *WT, not

/* add an observation identifier */
gen obsno = _n

/* get the number of observations - we will do a full size bootstrap
sample with replacement */
d
global bs_size = r(N)

/* save this in a temp file that we will sample from */
save $tmp/ihds_bs_tmp, replace

/* note that we do this by hand instead of using bsample in case we
want to change the sample size for each of the bootstraps. currently
set to n=N */

/* initialize output CSV */
capture file close fh 
file open fh using $pmgsy_data/boot_params.csv, write replace 

/* write the first (header) line to the csv */
/* first get the regressors (and constant) into a macro */
local bootvars land_own kisan_cc refrig num_room wall_mat_grass wall_mat_mud wall_mat_plastic wall_mat_wood wall_mat_brick wall_mat_gi wall_mat_stone wall_mat_concrete roof_mat_grass roof_mat_tile roof_mat_slate roof_mat_plastic roof_mat_gi roof_mat_brick roof_mat_stone roof_mat_concrete house_own_owned vehicle_two vehicle_four phone_landline_only phone_mobile_only phone_both high_inc_5000_10000 high_inc_more_10000 constant
local bootvars = subinstr("`bootvars'", " ", ", ", .)
file write fh "`bootvars'" _n

/* loop over the number of boostraps we want */
forval i = 1/1000 {

  /* clear out data in memory */
  drop _all

  /* set the size of our sample */
  set obs $bs_size

  /* randomly sample (with replacement) based on our obsno variable */
  gen obsno = floor($bs_size*runiform()+1)

  /* sort by obsno */
  sort obsno
  
  /* draw bootstrap sample by merging in our previous sample backbone*/	
  merge m:1 obsno using $tmp/ihds_bs_tmp
  keep if _merge == 3
  drop obsno _merge

  /* remove variables that will be ommited due to collinearity if included in regression */
  ds COTOTAL wall_mat_other roof_mat_other house_own_rented phone_none high_inc_less_5000 mech_farm_equip irr_equip *WT, not

  /* store the varlist for regressing*/
  local varlist `r(varlist)'

  /* run regression on consumption expenditure */
  reg COTOTAL `r(varlist)'

  /* tokenize varlist in order to save the name of varialbes of interest */
  tokenize `varlist'

  /* loop from 1 to 28 since there are 28 coefficients */
  forvalue i = 1/28 {

    /* store each beta */
    local tmp = _b[``i'']
    file write fh (`tmp') ", "
  }

  /* store constant */
  local tmp = _b[_cons]
  file write fh (`tmp') _n
}

/* close the finished csv */
file close fh 


/**********************************************/
/* (3) Create additional household-level vars */
/**********************************************/

/* this takes about an hour on our servers. */

/* loop over pmgsy states */
foreach state in $pc11_pmgsy_states {

  /* read in member data */
  use ~/iec2/secc/final/dta/`state'_members_clean, clear

  /* clean to proper ranges */
  replace ed = . if !inrange(ed, 1, 8) | !inrange(sc_st, 1, 4) | age < 25
  replace age = . if age == -9998 | age == -9999
  replace sex = . if sex == -9998 | sex == -9999

  /* bring in pc01 IDs */
  merge m:1 statecode districtcode tehsilcode towncode using ~/iec2/secc/final/keys/mord_secc_pc_key, keepusing(pc01*id)
  
  /* run the collapse */
  collapse (max) edmax_3bin = ed, by(pc01_state_id pc01_district_id pc01_subdistrict_id pc01_village_id mord_hh_id_trim)

  /* create the 3-bin edmax_hh variable */
  recode edmax_3bin 1=1 2/3=2 4/8=3
  label var edmax_3bin "3-bin max HH education var"
  label define ed3bin 1 "illit" 2 "prim & below" 3 "above prim"
  label values edmax_3bin ed3bin

  /* save this var */
  save $tmp/`state'_boot_var_edmax_3bin, replace

  /* now on to hh_man_ag. read in member data */
  use ~/iec2/secc/final/dta/`state'_members_clean, clear

  /* bring in pc01 IDs */
  merge m:1 statecode districtcode tehsilcode towncode using ~/iec2/secc/final/keys/mord_secc_pc_key, keepusing(pc01*id)
  keep if _merge == 3
  drop _merge
  
  /* merge in job keys*/
  merge m:1 job using ~/iec2/secc/final/keys/`state'_job_clean_key, keepusing(nco04_1d nco04_2d) update
  drop if _merge == 2
  drop _merge
  
  /* for each household, get the member with the largest education level */
  bysort mord_hh_id_trim: egen t = max(ed)
  
  /* keep only the observations where the member is the most educated
  in the household */
  keep if ed == t
  
  /* there are households with members tied for the highest level of
  eduction. break the tie by saving the older member's info and drop
  the younger one(s). */
         
  /* 1: for each household, get the oldest member in the hh */
  bysort mord_hh_id_trim: egen a = max(age)

  /* 2: keep only the observations where the member is the most educated
  in the household */
  keep if age == a

  /* 3: if there is still a tie, randomly keep one of these members for
  classifying the household's job status. sort by households */
  sort pc01_state_id pc01_district_id pc01_subdistrict_id pc01_village_id mord_hh_id_trim

  /* keep a single member within each household */
  qui by pc01_state_id pc01_district_id pc01_subdistrict_id pc01_village_id mord_hh_id_trim: gen dup = cond(_N==1,0,_n)
  drop if dup > 1

  /* create manual labor / ag indicator, initialized as "neither" */
  gen hh_man_ag = 3

  /* replace manual labor codes */
  replace hh_man_ag = 1 if nco04_1d == "9" & nco04_2d != "92"

  /* replace ag codes */
  replace hh_man_ag = 2 if nco04_1d == "6" | nco04_2d == "92"

  /* label */
  label var hh_man_ag "Ag or non-ag manlab employment, by top ed mem in HH"
  label define manag 1 "Manlab" 2 "Ag" 3 "Neither"
  label values hh_man_ag manag

  /* merge in edmax_3bin */
  merge 1:1 pc01_state_id pc01_district_id pc01_subdistrict_id pc01_village_id mord_hh_id_trim using $tmp/`state'_boot_var_edmax_3bin
  drop _merge

  /* clean up  */
  keep pc01*id mord_hh_id_trim hh_man_ag edmax_3bin
  order pc*id, first

  /* write out */
  compress
  save $tmp/`state'_hh_spill_vars, replace
}


/*****************************************************************************/
/* (4) prep program for collapsing hh_man_ag and edmax_3bin consumption data */
/*****************************************************************************/

/* this collapses $regvars across the hh_man_ag and edmax_3bin
variables. */

/* create a program that can be parallelized across states. */
cap prog drop gen_bootstrap_data_states
prog def gen_bootstrap_data_states
{

  /* we only need state as input, as well as the variable */
  syntax anything[, var(string)]

  /* clean up the state local for readability */
  local state `anything'
  
  /* print out state we're working on, and start time */
  disp_nice "`state' - `c(current_time)'" 

  /* get pmgsy globals into memory */
  qui do $pmgsy_code/settings.do
  
  /* use secc rural household file */
  use ~/iec2/secc/final/dta/`state'_household_clean, clear

  /* merge in pc01 ids */
  cap drop pc*id
  merge m:1 statecode districtcode tehsilcode towncode using ~/iec2/secc/final/keys/mord_secc_pc_key, keepusing(pc*_id) 
  drop if _merge < 3
  drop _merge

  /* drop if no id */
  drop if mi(pc01_village_id)
  
  /* drop duplicates */
  drop if flag_duplicates
  
  /* keep the 'mainsample' from working PMGSY data */
  merge m:1 pc01_state_id pc01_village_id using $tmp/pmgsy_working_aer_tmp, keepusing(mainsample) keep(match) nogen
  keep if mainsample

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

  /* divergence here depending on whether we're splitting over
  categoricals or doing the full count */
  if !mi("`var'") {  

    /* merge in the variable required by this collapse - created above */
    merge 1:1 pc01_state_id pc01_district_id pc01_subdistrict_id pc01_village_id mord_hh_id_trim using $tmp/`state'_hh_spill_vars, keepusing(`var') keep(match)
    
    /* drop any missings of the var in question */
    drop if mi(`var')

    /* append an underscore to the var for saving */
    local underscorevar "_`var'"
  }
  
  /* for the unsplit time in the loop, save hh-level data for pov rate
  and per-capita calcs */
  save $tmp/bootstrap/`state'_hh_cons, replace
  
  /* now collapse the vars to be used for imputation down to the
  village level */
  collapse (mean) $secc_impute_vars, by(pc01_state_id pc01_village_id `var')

  /* save the village-level file with consumption expenditure in
  scratch folder */
  save $tmp/bootstrap/`state'_village_collapsed`underscorevar', replace
}
end
/* *********** END program gen_bootstrap_data_states ***************************************** */


/*****************************************************************/
/* (5) Collapse consumption data component variables in parallel */
/*****************************************************************/

/* prepare our input file - will write to a .txt */
file open bootvars using $tmp/boot_var_in.txt , write replace

/* we need all combinations of pmgsy states
and our two variables of interest. first loop over states */
foreach state in $pc11_pmgsy_states {
  
  /* now loop over vars, including empty space for standard spec */
  foreach var in "hh_man_ag" "edmax_3bin" "" {

    /* add a line to our input file */
    file write bootvars "`state' `var'" _n
  }
}

/* close the file handle */
file close bootvars

/* parallelize data generation across states using the above program */
gnu_parallelize, max(12) prog(gen_bootstrap_data_states) in($tmp/boot_var_in.txt) progloc($pmgsy_code/bootstrap_table_data_prep.do) maxvar pre_comma options(var) extract_prog diag trace tracedepth(2)


/*********************************************************************/
/* (6) Create bootstrapped hh_man_ag and edmax_3bin consumption data */
/*********************************************************************/

/* now loop over our two categoricals that we need to split our
collapses by: no split, hh_man_ag, and edmax_3bin */
foreach var in "hh_man_ag" "edmax_3bin" "" {

  /* differentiate suffix depending on whether we're in a split */
  local underscorevar
  if !mi("`var'") {
    local underscorevar "_`var'"
  }
  
  /* append all the states to create a master file w PMGSY sample for this var */
  clear
  foreach state in $pc11_pmgsy_states {
    append using $tmp/bootstrap/`state'_village_collapsed`underscorevar'
  }

  /* note that the IHDS betas have been previously saved in
  $pmgsy_data/bootstrap/boot_params.csv - by
  pmgsy_cons_bootstrap.do, which creates the original bootstrapped
  consumption data at the village level. */

  /* read the file with the saved parameter esitimates (bootstraps) */
  capture file close bootfile
  file open bootfile using $pmgsy_data/boot_params.csv, read

  /* read the first line (header) so we're ready for the loop to follow */
  file read bootfile line

  /* loop over the saved bootstrapped parameters */
  disp "creating bootstrapped consumption - `c(current_time)'"
  forval i = 1/1000 {

    /* read the next line of boot_params.csv, save to local `line' */
    file read bootfile line
    
    /* get rid of the commas from the line in the CSV */
    local line = subinstr("`line'", ", ", " ", .)
    
    /* the last of the 29 items in the local is the constant. start with
    this as we generate our imputed consumption */
    local const `:word 29 of `line''
    
    /* generate consumption variable, starting  with constant */
    gen secc_cons`i' = `const'

    /* get our varlist that represents the IHDS betas */
    local varlist land_own kisan_cc refrig num_room wall_mat_grass wall_mat_mud wall_mat_plastic wall_mat_wood wall_mat_brick wall_mat_gi wall_mat_stone wall_mat_concrete roof_mat_grass roof_mat_tile roof_mat_slate roof_mat_plastic roof_mat_gi roof_mat_brick roof_mat_stone roof_mat_concrete house_own_owned vehicle_two vehicle_four phone_landline_only phone_mobile_only phone_both high_inc_5000_10000 high_inc_more_10000
    tokenize `varlist'
    
    /* loop from 1 to 28 - over the regression coefficients */
    forvalue j = 1/28 {

      /* update consumption variable by adding the product of the coefficient and variable value */
      local temp `:word `j' of `line''
      replace secc_cons`i'  = secc_cons`i' + `temp' * ``j''
    }
  }

  /* keep only the PC01 IDs, our categorical of interest, and all of
  our runs of imputed consumption */
  keep pc01_state_id pc01_village_id `var' secc_cons* 

  /* merge in household size, to get cons per capita */
  merge m:1 pc01_state_id pc01_village_id using $pmgsy_data/india_vill_size.dta, keepusing(secc_vill_hh_size)
  keep if _merge == 3
  drop _merge

  /* loop over our bootstraps for calculating and winsorizing pc cons */
  forval i = 1/1000 {

    /* now divide imputed cons by hh size to get cons per capita */
    gen secc_cons_pc`i' = secc_cons`i' / secc_vill_hh_size

    /* drop household-level consumption because we are going to have a
    ton of variables when we bootstrap*/
    drop secc_cons`i'

    /* generate logs, winsorized as before */
    winsorize secc_cons_pc`i' 1 99, centile gen(secc_cons_pc`i'win)
    drop secc_cons_pc`i'
    gen secc_conspc`i'winln = log(secc_cons_pc`i'win)
    drop secc_cons_pc`i'win
  }

  /* check if we need to reshape over a categorical */
  if !mi("`var'") {
    
    /* rename our cons vars so they are differentiable after reshaping wide */
    foreach x of var secc_cons* {
      rename `x' `x'_`var'
    } 
    
    /* reshape wide, so our 3 levels of our categorical have separate
    consumption vars */
    reshape wide secc_cons*, j(`var')  i(pc01_state_id pc01_village_id)
  }
  
  /* save the data */
  save $tmp/secc_cons_imputed_boot`underscorevar'.dta, replace
}

/* combine our datasets thus far. start with hh_man_ag and merge edmax 3bin */
use $tmp/secc_cons_imputed_boot_hh_man_ag.dta
merge 1:1 pc01_state_id pc01_village_id using $tmp/secc_cons_imputed_boot_edmax_3bin.dta
keep if _merge == 3
drop _merge

/* write out our bootstrapped consumption dataset for our categoricals */
save $pmgsy_data/cons_bootstrap_in_cats, replace

/* move the full non-reshaped cons boostraps to $pgmsyworking */
!cp $tmp/secc_cons_imputed_boot.dta $pmgsy_data/


/***********************************/
/* (7) Household-level imputations */
/***********************************/

/* append our state-level hh-level cons files into a single master */
clear
foreach state in $pc11_pmgsy_states {
  append using $tmp/bootstrap/`state'_hh_cons
}

/* read the file with the saved parameter esitimates (bootstraps) */
capture file close bootfile
file open bootfile using $pmgsy_data/boot_params.csv, read

/* read the first line (header) so we're ready for the loop to follow */
file read bootfile line

/* loop over the saved bootstrapped parameters */
disp "creating bootstrapped consumption - `c(current_time)'"
forval i = 1/1000 {

  /* read the next line of boot_params.csv, save to local `line' */
  file read bootfile line
  
  /* get rid of the commas from the line in the CSV */
  local line = subinstr("`line'", ", ", " ", .)
  
  /* the last of the 29 items in the local is the constant. start with
  this as we generate our imputed consumption */
  local const `:word 29 of `line''
  
  /* generate consumption variable, starting  with constant */
  gen secc_cons`i' = `const'

  /* get our varlist that represents the IHDS betas, in order */
  local varlist land_own kisan_cc refrig num_room wall_mat_grass wall_mat_mud wall_mat_plastic wall_mat_wood wall_mat_brick wall_mat_gi wall_mat_stone wall_mat_concrete roof_mat_grass roof_mat_tile roof_mat_slate roof_mat_plastic roof_mat_gi roof_mat_brick roof_mat_stone roof_mat_concrete house_own_owned vehicle_two vehicle_four phone_landline_only phone_mobile_only phone_both high_inc_5000_10000 high_inc_more_10000
  tokenize `varlist'
  
  /* loop from 1 to 28 - over the regression coefficients */
  forvalue j = 1/28 {

    /* update consumption variable by adding the product of the coefficient and variable value */
    local temp `:word `j' of `line''
    replace secc_cons`i'  = secc_cons`i' + `temp' * ``j''
  }
}

/* keep only the PC01 IDs and all of our runs of imputed secc
consumption */
keep secc_cons* pc01_state_id pc01_village_id mord_hh_id_trim

/* merge in household size, to get cons per capita at the hh level */
merge m:1 pc01_state_id pc01_village_id using $pmgsy_data/india_vill_size.dta, keepusing(secc_vill_hh_size)
keep if _merge == 3
drop _merge

/* now divide imputed cons by hh size to get cons per capita */
forval i = 1/1000 {
  if mod(`i', 10) == 0 {
    disp _n "working on `i'"
  }
  gen secc_cons_pc`i' = secc_cons`i' / secc_vill_hh_size

  /* drop household-level consumption because we are going to have a
  ton of variables when we bootstrap*/
  drop secc_cons`i'
}

/* save working dataset */
save $pmgsy_data/hh_imputed_cons_pc, replace

/* create the poverty rate data */

/* use per-capita consumption (household level) */
use $pmgsy_data/hh_imputed_cons_pc, clear

/* generate indicator variable for household below poverty line
defined by Tendulkar, which is defined as 27 rupees per cap per day */
forval i = 1/1000 {
  gen secc_pov_rate_tend`i' = 0
  replace secc_pov_rate_tend`i' = 1 if (secc_cons_pc`i' / 365) < 27
  replace secc_pov_rate_tend`i' = . if mi(secc_cons_pc`i')
  label var secc_pov_rate_tend`i' "village poverty rate (tend) for bs `i'"
}

/* collapse to village level to get the poverty rate for each
bootstrap */
collapse_save_labels
collapse (mean) secc_pov*, by(pc01_state_id pc01_village_id)
collapse_apply_labels

/* write out our data */
save $pmgsy_data/hh_imputed_pov_tend, replace

/* create consumption percentiles 5(5)95 */
cap mkdir $pmgsy_data/percentiles
forval i = 5(5)95 {

  /* read in the master hh-level consumption data */
  disp "working on percentile: `i' - `c(current_time)'"
  use $pmgsy_data/hh_imputed_cons_pc, clear

  /* collapse consumption percentile to the village level */
  collapse (p`i') secc_cons*, by(pc01_village_id pc01_state_id)

  /* add variable name suffix so we know what percentile we're dealing with */
  rename secc_cons_pc* secc_cons_pc*_p`i'
  
  /* create logs and drop levels */
  forval j = 1/1000 {

    gen secc_cons_pc`j'_p`i'_ln = log(secc_cons_pc`j'_p`i')
    label var secc_cons_pc`j'_p`i'_ln "log of per capita cons for percentile `i' and bootstrap `j'"
    drop secc_cons_pc`j'_p`i'
  }
  
  /* write out a dataset with this single percentile in it. can't
  combine them all - we would have 100,000 variables */
  save $pmgsy_data/percentiles/secc_cons_imputed_p`i', replace
}

/* merge together the percentile data subset that we care about for
the PMGSY paper tables */
clear
use $pmgsy_data/percentiles/secc_cons_imputed_p10
foreach i in 25 50 75 90 {
  merge 1:1 pc01_state_id pc01_village_id using $pmgsy_data/percentiles/secc_cons_imputed_p`i'
  keep if _merge == 3
  drop _merge
}

/* save this data file for future use */
save $pmgsy_data/secc_cons_pctiles, replace


/******************************/
/* (8) Prepare for regressing */
/******************************/

/* read in the clean data */
use $tmp/pmgsy_working_aer_tmp, clear

/* keep the vars we will use */
keep $controls left right t r2012 vhg_dist_id mainsample pc01*id kernel_tri_ik

/* merge in the basic log-winsorized consumption bootstraps */
merge 1:1 pc01_state_id pc01_village_id using $pmgsy_data/secc_cons_imputed_boot
keep if _merge == 3
drop _merge

/* merge in the bootstrapped consumption data for our two categoricals
hh_man_ag and edmax_3bin */
merge 1:1 pc01_state_id pc01_village_id using $pmgsy_data/cons_bootstrap_in_cats
keep if _merge == 3
drop _merge

/* merge in our poverty rate data (1,000 vars)*/
merge 1:1 pc01_state_id pc01_village_id using $pmgsy_data/hh_imputed_pov_tend
keep if _merge == 3
drop _merge

/* read in percentiles data for this application (5,000 vars) */
/* note that we can't read in all of the percentiles, as they're 99,000 vars
deep (99 pctiles * 1000 straps) */
merge 1:1 pc01_state_id pc01_village_id using $pmgsy_data/secc_cons_pctiles
keep if _merge == 3
drop _merge

/* save this intermediary dataset - this will be used for creating the
tables while bootstrapping over village sample */
save $pmgsy_data/cons_boot_in, replace


