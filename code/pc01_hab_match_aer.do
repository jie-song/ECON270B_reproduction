/* this file links habitation codes used in the PMGSY to pc01  */

/* load settings */
qui do $pmgsy_code/settings

/******************************/
/* Generate Files for Merging */
/******************************/

/* prepare clean loc name files for cleaning */

/* pc01 village key */
use $keys/pc01_ld_village_key.dta, clear

/* remove prefixes */
renpfix pc01_ld_ ""

/* ren block var */
ren cdblock_name block_name

/* keen only names and ids */
keep state_name district_name block_name village_name state_id district_id cdblock_id village_id

/* rename ids to have pc01 prefix */
ren (state_id district_id cdblock_id village_id) (pc01_state_id pc01_district_id pc01_block_id pc01_village_id)

/* manually clean names needing it */
do $pmgsy_code/name_clean

/* fix block names */
do $pmgsy_code/name_clean_blocks

/* drop duplicates */
duplicates drop

/* save version with codes */
save $pmgsytmp/pc01_w_ids, replace

/* save just clean states */
use $pmgsytmp/pc01_w_ids, clear
keep state_name pc01_state_id 
duplicates drop state_name, force
save $pmgsytmp/pc01_s, replace

/* save just clean dists */
use $pmgsytmp/pc01_w_ids, clear
keep state_name district_name pc01_state_id pc01_district_id 
duplicates drop state_name district_name , force
save $pmgsytmp/pc01_s_d, replace

/* save just clean blocks */
use $pmgsytmp/pc01_w_ids, clear
keep state_name district_name block_name pc01_state_id pc01_district_id pc01_block_id 
duplicates drop state_name district_name block_name , force
save $pmgsytmp/pc01_s_d_b, replace

/* save just clean villages -- this time ddrop so that there's no possibility of matching the wrong village */
use $pmgsytmp/pc01_w_ids, clear
keep state_name district_name block_name village_name pc01_state_id pc01_district_id pc01_block_id pc01_village_id 
ddrop state_name district_name block_name village_name 
save $pmgsytmp/pc01_s_d_b_v, replace

/* habitation_list2 */
use ~/iec/misc_data/pmgsy/scrape/habitation_list2, clear

/* generate merge vars */
foreach var in state_name district_name block_name village_name {
  gen `var' = hl2_`var'
}

/* keep only names and ids */
keep hl2_state_name hl2_district_name hl2_block_name hl2_village_name state_name district_name block_name village_name

/* manually clean names needing it */
do $pmgsy_code/name_clean

/* drop duplicates */
duplicates drop

/* merge in pc01 state and district id's */
merge m:1 state_name district_name using $pmgsytmp/pc01_s_d
drop if _m == 2
drop _merge

/* fix block names */
do $pmgsy_code/name_clean_blocks

/* drop any duplicated villages on clean names */
ddrop state_name district_name block_name village_name

/* drop any villages where major changes made */
masala_lev_dist village_name hl2_village_name , gen(lev_dist_v_hl2)
drop if lev_dist_v_hl2 >= 2
drop lev_dist_v_hl2

/* save clean name version */
save $pmgsytmp/hl2_nameclean_fm, replace

/* save just clean states */
use $pmgsytmp/hl2_nameclean_fm, clear
keep hl2_state_name state_name 
duplicates drop
save $pmgsytmp/hl2_s, replace

/* save just clean dists */
use $pmgsytmp/hl2_nameclean_fm, clear
keep state_name district_name hl2_state_name hl2_district_name
duplicates drop
save $pmgsytmp/hl2_s_d, replace

/* save just clean blocks */
use $pmgsytmp/hl2_nameclean_fm, clear
keep state_name district_name block_name hl2_state_name hl2_district_name hl2_block_name
duplicates drop
save $pmgsytmp/hl2_s_d_b, replace

/* save just clean villages */
use $pmgsytmp/hl2_nameclean_fm, clear
keep state_name district_name block_name village_name hl2_state_name hl2_district_name hl2_block_name hl2_village_name
duplicates drop
ddrop state_name district_name block_name village_name
save $pmgsytmp/hl2_s_d_b_v, replace


/***************/
/* Block Merge */
/***************/

/* merge blocks */
use $pmgsytmp/hl2_s_d_b, clear
keep state_name district_name block_name 
duplicates drop
merge 1:1 state_name district_name block_name using $pmgsytmp/pc01_s_d_b
order pc01_state_id state_name pc01_district_id district_name pc01_block_id block_name

/* save good matches */
preserve
keep if _m == 3
drop _m
save $pmgsytmp/block_match1, replace
restore

/* save unmatched pc01 blocks */
preserve
keep if _m == 2
drop _m
save $pmgsytmp/pc01_blocks_unmatched1, replace
restore

/* save unmatched hl2 blocks */
preserve
keep if _m == 1
drop _m pc01_state_id pc01_district_id pc01_block_id 
save $pmgsytmp/hl2_blocks_unmatched1, replace
restore

/* masala merge */
use $pmgsytmp/pc01_blocks_unmatched1, clear
masala_merge2 state_name district_name using $pmgsytmp/hl2_blocks_unmatched1, s1(block_name) outfile($pmgsytmp/block_match_masala) dist(3)
keep if _m == 3
drop _m block_name
ren block_name_using block_name
save $pmgsytmp/block_match2, replace

/* append direct and masala merges to produce block key*/
use $pmgsytmp/block_match1
gen flag_block_match = 1
append using $pmgsytmp/block_match2
replace flag_block_match = 2 if mi(flag_block_match)
label define flag_block_match 1 exact 2 masala
label values flag_block_match flag_block_match
save $pmgsytmp/block_key, replace


/*****************/
/* Village Merge */
/*****************/

/* prep hl2 by adding block ids */
use $pmgsytmp/hl2_s_d_b_v, clear
merge m:1 state_name district_name block_name using $pmgsytmp/block_key
ddrop pc01_state_id pc01_district_id pc01_block_id village_name 
drop _m
save $pmgsytmp/hl2_s_d_b_v_fm, replace

/* 1. direct matches */
use $pmgsytmp/pc01_s_d_b_v, clear
merge 1:1 state_name district_name block_name village_name using $pmgsytmp/hl2_s_d_b_v_fm
order pc01_state_id state_name pc01_district_id district_name pc01_block_id block_name pc01_village_id village_name

/* save good matches */
keep if _m == 3
drop _m
save $pmgsy/pc01_hl_village_match, replace


