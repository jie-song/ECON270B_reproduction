/* merges all of the newly scraped PMGSY data processed by process_data.do */

/* prepare environment */
do $pmgsy_code/settings

/********************/
/* Merge Road Files */
/********************/

/* set master road merge var list */
global roadmerge state_name district_name block_name road_name_clean year_sanctioned cost_sanctioned

/* prep road files */
/* all files merge to sp2, first on full var set, then without year_sanctioned */
/* using files: comp_roads_DVW2, physical_progress2, progress_roadwise2  */
merge_cycle, master_pref(sp2) using_pref(dvw2) path1($pmgsy_raw) path2($pmgsytmp) master(sanctioned_projects2) using(comp_roads_DVW2)   list1($roadmerge) list2(state_name district_name block_name road_name_clean cost_sanctioned)
merge_cycle, master_pref(sp2) using_pref(pp2) path1($pmgsy_raw) path2($pmgsytmp) master(sanctioned_projects2) using(physical_progress2) list1($roadmerge) list2(state_name district_name block_name road_name_clean cost_sanctioned)
merge_cycle, master_pref(sp2) using_pref(pr2) path1($pmgsy_raw) path2($pmgsytmp) master(sanctioned_projects2) using(progress_roadwise2) list1($roadmerge) list2(state_name district_name block_name road_name_clean cost_sanctioned)

/* merge to create master road file */
use $pmgsytmp/sanctioned_projects2_comp_roads_DVW2_merge, clear
merge 1:1 $roadmerge using $pmgsytmp/sanctioned_projects2_physical_progress2_merge, nogen
merge 1:1 $roadmerge using $pmgsytmp/sanctioned_projects2_progress_roadwise2_merge, nogen

/* drop hab vars from road file */
drop *_hab_*

/* drop useless merge vars */
drop _m_*
  
/* save */
save $pmgsytmp/road2_merge, replace
/* N = 141k, very good given 143k unique vars on $roadmerge in sp2 */

  
/*******************/
/* Merge Hab Files */
/*******************/

/* set master hab merge var list */
global habmerge  state_name district_name block_name hab_name hab_pop hab_pop_scst

/* all files merge to hl2, first on full var set */
/* using files: sanctioned_projects2, physical_progress2  */
merge_cycle, master_pref(hl2) using_pref(sp2) path1($pmgsy_raw) path2($pmgsytmp) master(habitation_list2) using(sanctioned_projects2) list1($habmerge) list2(state_name district_name hab_name hab_pop hab_pop_scst)
merge_cycle, master_pref(hl2) using_pref(pp2) path1($pmgsy_raw) path2($pmgsytmp) master(habitation_list2) using(physical_progress2)   list1($habmerge) list2(state_name district_name hab_name hab_pop hab_pop_scst)

/* merge to create master road file */
use $pmgsytmp/habitation_list2_sanctioned_projects2_merge, clear
merge 1:1 $habmerge using $pmgsytmp/habitation_list2_physical_progress2_merge, nogen

/* rename matchround vars to not conflict with those in road data */
ren matchround_sp2 matchround_sp2_hab
ren matchround_pp2 matchround_pp2_hab

/* drop useless merge vars */
drop _m_*
  
/* save */
save $pmgsytmp/hab2_merge, replace


/******************************/
/* Combine Hab and Road Files */
/******************************/

/* start with master hab list file */
use $pmgsy_raw/habitation_list2, clear

/* merge in hl2-sp2 match */
merge 1:1 hl2* using $pmgsytmp/hab2_merge, gen(_m_sp2)

/* merge in roads */
merge m:1 sp2_state_name sp2_district_name sp2_block_name sp2_road_name_clean sp2_year_sanctioned sp2_cost_sanctioned using $pmgsytmp/road2_merge, gen(_m_road2)

/* save dataset */
compress
save $pmgsytmp/pmgsy2_master, replace


/****************************************************/
/* Save More Efficient File for Merge to Other Data */
/****************************************************/

use $pmgsytmp/pmgsy2_master, clear

/* drop roads that didn't match any habitations */
drop if mi(hl2_village_name)

/* drop merge vars */
drop state_name district_name block_name hab_name hab_pop hab_pop_scst road_name_clean

/* drop sp2 names that are same as hl2 */
foreach pref in sp2 pp2 {
  foreach var in state_name district_name block_name hab_name {
    cap drop `pref'_`var'
  }
}

/* drop most pp2_ data, redundant with sp2_ */
/* keep pp2_package */
drop pp2_year_sanctioned pp2_road_name pp2_new pp2_length_pavement pp2_cost_pavement pp2_count_cd_works pp2_cost_cd_works pp2_cost_lsb pp2_cost_lsb_state pp2_cost_protection_works pp2_cost_other_works pp2_status pp2_length_completed pp2_expenditure_till_date pp2_cost_sanctioned pp2_hab_pop pp2_hab_pop_scst pp2_road_name_clean pp2_surface_type

/* drop other strings */
drop pr2_*name* pr2_package dvw2_*name* dvw2_package

/* drop sp2_road_name_clean - we have the road name, and we're not merging to anything else */
drop sp2_road_name_clean

/* drop constituencies - not using here */
drop hl2*constituency

/* save */
save $pmgsy/pmgsy_2015, replace

