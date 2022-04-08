/* use the IHDS merged dataset (generated by impute_consumption_expenditure_secc_rural.do) */
use $tmp/ihds/2011_household_member_rural.dta, clear
do $pmgsy_code/settings

/* keep necessary variables for regression */
keep *ID COTOTAL wall_mat_* roof_mat_* house_own_* vehicle_* phone_* high_inc_* num_room refrig land_own kisan_cc mech_farm_equip irr_equip *WT

/* store the varlist */
local varlist land_own kisan_cc refrig num_room wall_mat_grass wall_mat_mud wall_mat_plastic wall_mat_wood wall_mat_brick wall_mat_gi wall_mat_stone wall_mat_concrete roof_mat_grass roof_mat_tile roof_mat_slate roof_mat_plastic roof_mat_gi roof_mat_brick roof_mat_stone roof_mat_concrete house_own_owned vehicle_two vehicle_four phone_landline_only phone_mobile_only phone_both high_inc_5000_10000 high_inc_more_10000

/* run regression on consumption expenditure */
reg COTOTAL `varlist' [pweight = WT], robust

/* p-values need to be extracted from the results matrix */
matrix def p_mat = r(table)

/* remove previous iterations of the table data */
cap rm $tmp/ihds_coef_data.csv

/* loop over the number of vars in the varlist - this way we can
better extract p values from the results matrix, as indexing by
variable name was not working across all variables. */
local num_vars : word count `varlist'
forval i = 1/`num_vars' {

  /* get the varname */
  local var : word `i' of `varlist'
  
  /* extract the p value */
  local p = p_mat[4,`i']

  /* store each beta */
  local beta = _b[`var']
  local se = _se[`var']
  
  /* write out to csv */
  store_val_tpl using $tmp/ihds_coef_data.csv, name("`var'_beta") value(`beta') format("%12.0f")
  store_val_tpl using $tmp/ihds_coef_data.csv, name("`var'_se") value(`se') format("%12.0f")
  store_val_tpl using $tmp/ihds_coef_data.csv, name("`var'_p") value(`p')
}

/* store constant */
local constant = _b[_cons]
local constant_se = _se[_cons]
store_val_tpl using $tmp/ihds_coef_data.csv, name("cons_beta") value(`constant') format("%12.0f")
store_val_tpl using $tmp/ihds_coef_data.csv, name("cons_se") value(`constant_se') format("%12.0f")
local cons_p = p_mat[4,29]
store_val_tpl using $tmp/ihds_coef_data.csv, name("cons_p") value(`cons_p')

/* store N and r2*/
store_val_tpl using $tmp/ihds_coef_data.csv, name("r2") value(`e(r2)') format("%5.3f")
count
store_val_tpl using $tmp/ihds_coef_data.csv, name("n") value(`r(N)') format("%12.0f")

/* create the output table */
table_from_tpl, t($table_templates/cons_table_ihds_tpl.tex) r($tmp/ihds_coef_data.csv) o($out/ihds_impute_coefs.tex) dropstars

