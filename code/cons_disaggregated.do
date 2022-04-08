/* Impacts of road on individual assets */

/* take each of the SECC predictor variables and plug them into the
main regression specification as an outcome. turn this into a table
too. */

/* start with the main sample working data unfrozen above */
use $pmgsy_data/pmgsy_working_aer_mainsample, clear

/* load PMGSY settings */
do $pmgsy_code/settings.do

/* remove previous iterations of the table data */
cap rm $tmp/cons_disag_data.csv

/* generate desired shares - roof first*/
gen roof_denom = secc_roof_mat1 + secc_roof_mat2 + secc_roof_mat3 + secc_roof_mat4 + secc_roof_mat5 + secc_roof_mat6 + secc_roof_mat7 + secc_roof_mat8 + secc_roof_mat9
forval roof = 1/9 {
  gen secc_roof_mat`roof'_share = secc_roof_mat`roof' / roof_denom
}

/* now wall mat */
gen wall_denom = secc_wall_mat1 + secc_wall_mat2 + secc_wall_mat3 + secc_wall_mat4 + secc_wall_mat5 + secc_wall_mat6 + secc_wall_mat7 + secc_wall_mat8 + secc_wall_mat9
forval wall = 1/9 {
  gen secc_wall_mat`wall'_share = secc_wall_mat`wall' / wall_denom
}

/* now phones */
gen phone_denom = secc_phone1 + secc_phone2 + secc_phone3 + secc_phone4
forval phone = 1/3 {
  gen secc_phone`phone'_share = secc_phone`phone' / phone_denom
}

/* house ownership */
gen house_own_denom = secc_house_own1 + secc_house_own2 + secc_house_own3
gen secc_house_own1_share = secc_house_own1 / house_own_denom

/* now high_inc */
gen high_inc_denom = secc_high_inc1 + secc_high_inc2 + secc_high_inc3
gen secc_high_inc2_share = secc_high_inc2 / high_inc_denom
gen secc_high_inc3_share = secc_high_inc3 / high_inc_denom

/* set varlist of secc variables (different names that IHDS data) */
local secc_varlist secc_land_own_share secc_kisan_cc_share secc_refrig_share secc_num_room_mean secc_roof_mat1_share  secc_roof_mat2_share  secc_roof_mat3_share  secc_roof_mat4_share  secc_roof_mat5_share  secc_roof_mat6_share secc_roof_mat7_share secc_roof_mat8_share secc_roof_mat9_share secc_wall_mat1_share secc_wall_mat2_share secc_wall_mat3_share secc_wall_mat4_share secc_wall_mat5_share secc_wall_mat6_share secc_wall_mat7_share secc_wall_mat8_share secc_wall_mat9_share secc_veh_four_share secc_veh_two_share secc_phone1_share secc_phone2_share secc_phone3_share secc_house_own1_share secc_high_inc2_share secc_high_inc3_share

/* run the main analysis spec for each of the variables defined above */
foreach var in `secc_varlist' {

  /* run reg */
  ivregress 2sls `var' (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample, vce(robust)

  /* store estimates into table */
  store_est_tpl using $tmp/cons_disag_data.csv, all coef(r2012) name(`var')
}

/* write out table from template */
table_from_tpl, t($table_templates/cons_disag_tpl.tex) r($tmp/cons_disag_data.csv) o($out/cons_disag.tex) dropstars
