/****************/
/* Create PMGSY */
/****************/

/* this file builds up the master PMGSY dataset */

/*************/
/* I. Header */
/*************/

set more off
do $pmgsy_code/settings


/**************************/
/* II. Prep Datasets */
/**************************/

/* District key */
use $pmgsy_raw/districtkey.dta , clear
drop if mi(pc01_state_id) | mi(pmgsy_pc01_district_id)
ren pmgsy_pc01_district_id pc01_district_id
collapse (max) hill desert tribal (firstnm) pmgsy_district_name, by(pc01_state_id pc01_district_id)
save $pmgsytmp/pmgsy_districtkey_fm, replace


/********************************************************/
/* III. Collapse PMGSY Data Down to PC01 Village Dataset */
/********************************************************/

/* best we can do is on village name, since that's what we'll use to merge to pc01 */
use $pmgsy/pmgsy_2015, clear

/* generate road id */
egen road_id = group(hl2_state_name hl2_district_name hl2_block_name sp2_road_name sp2_year_sanctioned sp2_cost_sanctioned)

/* rename for consistency with old data */
ren hl2_hab_pop hl2_pop

/* tag one habitation per village */
sort hl2_state_name hl2_district_name hl2_block_name hl2_village_name hl2_pop
by hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen tag = seq()

/* generate village level vars */

/* number of pmgsy habs in village variable */
bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen hab_count = count(tag)

/* largest hab pop, pmgsy_benefited and village level services according to pmgsy */
foreach i in hl2_pop hl2_electrified hl2_bus hl2_telephone hl2_dispensary hl2_health_services hl2_school_primary hl2_school_middle hl2_school_high hl2_school_intermediate hl2_college hl2_panchayat_hq hl2_mcw_center hl2_phcs hl2_veternary_hospital hl2_telegraph_office hl2_railway {
  bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen `i'_max = max(`i')
}

/* connectivity - max and min (max is if at least one hab connected, min if at least one hab unconnected) */
foreach i in max min {
  bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen hl2_conn2000_`i' = `i'(hl2_connectivity_2000)
}

/* treatment */

/* create year of sanctioning and completion */
gen __tmp = year(dvw2_date_completion)
bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen comp_year = min(__tmp)
drop __tmp
gen __tmp = year_sanctioned
bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen sanc_year = min(__tmp)
drop __tmp

/* create date of completion for higher temporal resolution, e.g. education project */
bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen comp_date = min(dvw2_date_completion)
compress comp_date
format comp_date %td

/* create award date at higher temporal resolution, e.g. education project */
bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen award_date = min(pr2_date_award)
format award_date %td
replace award_date = . if !inrange(year(award_date), 2000, 2015)

/* number of roads built before 2005/2011 - counting only distinct habs, not multiple roads per hab */
/* also cost of roads by that year and total number of habs on the roads built */
foreach i in 2005 2010 2011 2012 2013 {
  gen __tmp = 0
  replace __tmp = 1 if comp_year < `i' & !mi(comp_year)
  /* number of roads built by year */
  bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen road_count_`i' = total(__tmp)
  /* population served by roads, by year */
  gen __tmp2 = __tmp * hl2_pop
  bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen pop_benefited_`i' = total(__tmp2)
  /* road cost by that year */
  gen __tmp3 = __tmp * dvw2_payment_total
  bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen road_cost_`i' = total(__tmp3)
  drop __tmp*
}

/* number of new roads and population served by new roads */
/* also cost of roads by that year and total number of habs on the roads built */
foreach i in 2005 2010 2011 2012 2013 {
  gen __tmp = 0
  replace __tmp = 1 if comp_year < `i' & !mi(comp_year) & sp2_new == 1
  /* number of new roads built by year */
  bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen road_count_new_`i' = total(__tmp)
  /* population served by new roads by year */
  gen __tmp2 = __tmp * hl2_pop
  bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen pop_benefited_new_`i' = total(__tmp2)
  /* road cost by that year */
  gen __tmp3 = __tmp * dvw2_payment_total
  bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen road_cost_new_`i' = total(__tmp3)
  drop __tmp*
}

/* length of road */
gen sp2_length_pavement_2012 = sp2_length_pavement
replace sp2_length_pavement_2012 = . if comp_year > 2011
bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen sp2_length_2012_min = min(sp2_length_pavement_2012)

/* new road vs upgrade */
bys hl2_state_name hl2_district_name hl2_block_name hl2_village_name: egen road_new = max(sp2_new)
label var road_new "Source var sp2_new, 1 new, 0 upgrade"

/* keep only tagged habs -- effectively collapsing */
keep if tag == 1

/* Keep the right variables */
keep hl2_state_name hl2_district_name hl2_block_name hl2_village_name road_new comp_year comp_date award_date sanc_year hab_count *max *min *2005 *2010 *2011 *2012 *2013 road_id

/* merge in pc01 id's */
merge 1:1  hl2_state_name hl2_district_name hl2_block_name hl2_village_name using $pmgsy/pc01_hl_village_match, gen(_m_pc01_hl2)

/* drop if sanc_year > comp_year (bad data) */
drop if sanc_year > comp_year

/* save */
compress
save $pmgsytmp/pmgsy2_pc01_master_village, replace

/* save for merge */
use $pmgsytmp/pmgsy2_pc01_master_village, clear
drop if _m_pc01_hl2 == 1
save $pmgsytmp/pmgsy2_pc01_master_village_fm, replace


/************************************************/
/* IV. Merge Everything Together at PC01 Level */
/************************************************/

/* start with shrug panel */
use $shrug_data/shrug_pcec, clear

/* run settings */
do $pmgsy_code/settings

/* merge in pc01 id's */
merge 1:m shrid using $shrug_keys/shrug_pc01r_key, gen(_m_shrid01) keep(match) keepusing(pc01_*_id)
drop if _m_shrid01 < 3

/* drop duplicates on shrid */
ddrop shrid

/* merge in pc11 id's */
merge 1:m shrid using $shrug_keys/shrug_pc11r_key, gen(_m_shrid11) keep(match) keepusing(pc11_*_id)
drop if _m_shrid11 < 3

/* drop any duplicate villages on shrids or on pc11 id's */
ddrop shrid
ddrop pc01_state_id pc01_village_id
ddrop pc11_state_id pc11_village_id

/* keep only variables used in analysis*/
keep pc01*id shrid pc11_pca_tot_work_p pc11_pca_tot_p pc01_pca_tot_p pc91_pca_tot_p pc01_vd_dist_town pc01_vd_power_all pc01_pca_p_sc pc01_pca_p_st pc01_pca_tot_p pc01_vd_bs_fac pc01_vd_comm_fac pc01_vd_bank_fac pc01_vd_tot_irr pc01_vd_un_irr pc01_vd_tot_irr pc01_pca_p_ill  pc01_vd_p_sch  pc01_vd_medi_fac pc01_vd_power_supl  pc01_vd_app_pr pc01_vd_app_mr pc01_vd_mcw_cntr pc01_vd_area pc01_pca_p_sc pc11_vd_land_misc_trcp pc11_vd_land_nt_swn pc11_vd_bus_gov pc11_vd_bus_priv pc11_vd_taxi pc11_vd_vans pc11_vd_auto pc11_vd_area

/* merge in ec13 collapse */
merge 1:1 pc01_state_id pc01_village_id using $ec_collapsed/ec13_collapse_village_pc01, gen(_m_ec13) keep(match master) keepusing(ec13_emp_all ec13_count_all ec13_emp_act* ec13_count_act1 ec13_count_act2 ec13_count_act3 ec13_count_act4 ec13_count_act5 ec13_count_act6)

/* merge in bpl02 controls */
merge 1:1 pc01_state_id pc01_village_id using $bpl/bpl_fam_village, gen(_m_bpl_fam) keep(match master) keepusing(bpl_landed_share bpl_inc_source_subsistence_share bpl_inc_250plus)

/* merge in pmgsy data */
merge 1:1 pc01_state_id pc01_village_id using $pmgsytmp/pmgsy2_pc01_master_village_fm, gen(_m_pmgsy) keep(match master) keepusing(hl2_pop_max comp_year hl2_conn2000_max road_cost_2005 road_cost_2010 road_cost_2011 road_cost_2012 road_cost_2013)

/* merge in secc data */
merge 1:1 pc01_state_id pc01_village_id using ~/iec2/secc/final/collapse/village_collapsed_master_dupsdrop, gen(_m_secc) keep(match master) keepusing(secc_solid_house_share secc_tot_p secc_jobs* secc_acre_bin0 secc_acre_bin1 secc_acre_bin2 secc_acre_bin3 secc_acre_bin4 secc_acre_bin5 secc_acre_bin6 secc_two_crop_acre_sum secc_unirr_land_acre_sum secc_other_irr_acre_sum secc_nco_cult_acr_shr0 secc_nco_cult_acr_shr1 secc_nco_cult_acr1 secc_nco_cult_acr2 secc_nco_cult_acr3 secc_nco_cult_acr4 secc_nco_cult_acr5 secc_nco_cult_acr6 secc_employed_acr1 secc_employed_acr2 secc_employed_acr3 secc_employed_acr4 secc_employed_acr5 secc_employed_acr6 secc_sexage_p secc_mech_farm_equip_share secc_wall_mat_solid_share secc_roof_mat_solid_share secc_irr_equip_share secc_land_own_share secc_inc_5k_plus_share secc_inc_cultiv_share secc_inc_manlab_share secc_roof_mat* secc_wall_mat* secc_phone* secc_house_own* secc_high_inc* secc_kisan_cc_share secc_refrig_share secc_num_room_mean secc_veh_any_share secc_veh_four_share secc_veh_two_share $nco04_1d_vars $nco04_2d_vars $secc_age_vars)
merge 1:1 pc01_state_id pc01_village_id using ~/iec2/secc/final/collapse/village_consumption_imputed_pc01, gen(_m_cons) keep(match master) keepusing(secc_asset_index secc_cons_per_cap)

/* merge in crop suitability */
merge 1:1 pc01_state_id pc01_village_id using $fao/village_cropsuit, gen(_m_cropsuit) keep(match master) keepusing(cropsuit_rf_c_low)

/* merge in ag commodities */
merge 1:1 shrid using $pmgsy_data/pc11_crops_shrid, gen(_m_ag_comm) keep(match master) keepusing(any_noncalorie any_noncerpul any_perish)

/* merge in night lights */
merge 1:1 pc01_state_id pc01_village_id using $pmgsy_data/pc11_poly_nl_wide_pc01, gen(_m_lights) keep(match master) keepusing(total_light20*)

/* merge in ndvi and evi */
merge 1:1 pc01_state_id pc01_village_id using $ndvi/ndvi_pc01, gen(_m_ndvi) keep(match master) keepusing(*_delta_* *_cumul_* *_max_*)
merge 1:1 pc01_state_id pc01_village_id using $ndvi/evi_pc01, nogen keep(match master) keepusing(*_delta_* *_cumul_* *_max_*)

/* merge in pc11 housing data */
merge 1:1 pc01_state_id pc01_village_id using $pc11/pc11_hpca_village_pc01, gen(_m_pc11hl) keep(match master) keepusing(pc11r_hl_latrine_oth_open pc11r_hl_latrine_inprem pc11r_hl_latrine_pit_svi pc11r_hl_latrine_pit_sop)

/* merge in pmgsy_state_ids for all villages */
merge m:1 pc01_state_id using $pmgsy_raw/statekey, update nogen keep(match)

/* merge in coordinates */
merge 1:1 pc01_state_id pc01_village_id using ~/iec/pc01/geo/village_coords_clean, update nogen keep(match master)

/* save temporary file pre-prep */
save $tmp/pmgsy_working_aer_tmp_preprep, replace

/* generate variables for analysis */
do $pmgsy_code/prep_pmgsy_aer

/* save temporary file */
save $tmp/pmgsy_working_aer_tmp, replace

/* gen spillover data - uncomment to run. N.B. this dofile runs on
$tmp/pmgsy_working_aer_tmp.dta */
do $pmgsy_code/gen_spillover_data_indexes.do

/* reload working file */
use $tmp/pmgsy_working_aer_tmp, clear

/* merge in spillover data */
merge 1:1 pc01_state_id pc01_village_id using $pmgsy_data/pmgsy_spillover_outcomes, gen(_m_spill) keep(match master) keepusing(*andrsn_5k unemp_5k unclass_5k)

/* keep only villages matched to pmgsy data */
keep if _m_pmgsy == 3

/* save merged file */
save $pmgsy_data/pmgsy_working_aer, replace

/* save smaller dataset with only RD sample */
keep if mainsample
save $pmgsy_data/pmgsy_working_aer_mainsample, replace

/* prep bootstrap data */
do $pmgsy_code/bootstrap_table_data_prep

