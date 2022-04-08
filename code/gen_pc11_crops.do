/* load settings */
do $pmgsy_code/settings

/* this do file processes pre-existing agricultural data. */
use $pc11_ag/pc11_vd_ag_comm_key.dta, clear

/* drop if missing all 3 */
drop if mi(crop1) & mi(crop2) & mi(crop3)

/* outcome vars */
gen any_noncalorie  = inlist(cat1, "non-foodgrain", "spices") | inlist(cat2, "non-foodgrain", "spices") | inlist(cat3, "non-foodgrain", "spices")
gen any_perish  = inlist(sub_cat1, "fruitvegetable", "meatdairy") | inlist(sub_cat2, "fruitvegetable", "meatdairy") | inlist(sub_cat3, "fruitvegetable", "meatdairy")
gen any_noncerpul  = inlist(cat1, "non-foodgrain", "spices", "foodgrain") | inlist(cat2, "non-foodgrain", "spices", "foodgrain") | inlist(cat3, "non-foodgrain", "spices", "foodgrain")

/* merge in pc01 ids (this is unique on pc11 ids) */
merge 1:1 pc11_state_id pc11_district_id pc11_subdistrict_id pc11_village_id using $shrug_keys/shrug_pc11r_key, nogen keep(match)

/* keep only relevant vars */
keep shrid only* any* num_crop 

/* drop duplicates on village id's */
ddrop shrid

/* save */
save $pmgsy_data/pc11_crops_shrid, replace

