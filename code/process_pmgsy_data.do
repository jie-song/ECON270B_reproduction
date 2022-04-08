/* Processes all data from the PMGSY into usable Stata files */

/***** TABLE OF CONTENTS *****/
/* Location Codes */
/* Process CSVs into clean stata files */
/* Habitation-wise DRRP */
/* Habitation-wise Core Network */
/* Completed Roads DCR */
/* Completed Roads DVW */
/* Statewise List of Roads */
/* Road Wise Core Net */
/* Rpt DRRP */
/* Road Wise Progress */
/* State Road Completion */
/* Tender Details */
/* Agreement Details */
/* Work Award Details */
/* Quality Reports - NQMSQM */
/* National Quality Monitor Inspect Work Report */
/* Proforma CN1 */
/* CUPL */
/* CNCPL */
/* Habitation List */
/* Sanctioned Projects */
/* Habitations Benefited */
/* District Key */
/* Block Key */
/* Census Codes */
/* DISTRICTS */
/* BLOCKS */
/* VILLAGES */
/* PC01 Block Codes */
/* New Scrape 2015 */
/* Sanctioned Projects New */
/* Habitation Coverage (aka Habitation List) */
/* Progress Roadwise (New)   */
/* Completed Roads DVW (New) */
/* Physical Progress of Works */


/* prepare environment */
do $pmgsy_code/settings.do
set more off

/*******************/
/* New Scrape 2015 */
/*******************/

/* from new website omms.nic.in */
/* giving file names and prefixes the number 2 (e.g. sp2_) to differentiate from old scrape */

/******************************/
/* Sanctioned Projects New */
/******************************/

insheet using  ~/iec/misc_data/pmgsy/new_scrape/sp5.csv, comma clear

/* rename variables */
ren v3 serial
ren v4 road_name
ren v5 new
ren v6 surface_type
ren v7 length_pavement
ren v8 cost_pavement
ren v9 cost_pavement_perkm
ren v10 count_cd_works
ren v11 cost_cd_works
ren v12 cost_protection_works
ren v13 cost_other_works
ren v14 cost_lsb_state
ren v15 cost_total_state
ren v16 cost_lsb       
ren v17 cost_sanctioned
ren v18 collaboration  
ren v19 hab_name       
ren v20 hab_pop        
ren v21 hab_pop_scst

/* drop pavement cost / km - looks improperly calculated and redundant */
drop cost_pavement_perkm

/* clean road names */
clean_road_name road_name, gen(road_name_clean)

/* drop empty vars */
drop v22 v23

/* gen string variable to generate place names and year */
gen string = v1

/* generate flag that something wrong with string */
gen flag = 0
replace flag = 1 if strpos(substr(string, (strpos(string, "[") + 1), strpos(string, "]") - strpos(string, "[") - 1), "-") > 0

/* fix messed up string -- all where blocks have hyphenated name */
replace string = subinstr(string, "[", "(", 1) if flag
replace string = substr(string, 1, strpos(string, "-") - 1) + ")-(" + substr(string, strpos(string, "-") + 1, .) if flag
replace string = subinstr(string, "]", ")", 1) if flag
replace string = subinstr(string, "[", "(", 1) if flag
replace string = substr(string, 1, strpos(string, "]-[") - 1) + "-" + substr(string, strpos(string, "]-[") + 3, .) if flag
replace string = subinstr(string, "(", "[", .) if flag
replace string = subinstr(string, ")", "]", .) if flag

/* generate state name */
gen state_name = substr(string, strpos(string, "[") + 1, strpos(string, "]") - 2)

/* drop state name from string */
replace string = substr(string, strpos(string, "]") + 2, .)

/* generate district name */
gen district_name = substr(string, strpos(string, "[") + 1, strpos(string, "]") - 2)

/* drop district name from string */
replace string = substr(string, strpos(string, "]") + 2, .)

/* generate block name */
gen block_name = substr(string, strpos(string, "[") + 1, strpos(string, "]") - 2)

/* drop block name from string */
replace string = substr(string, strpos(string, "]") + 2, .)

/* generate year */
gen year_sanctioned = substr(string, strpos(string, "[") + 1, strpos(string, "]") - 2)

/* drop year from string */
replace string = substr(string, strpos(string, "]") + 2, .)

/* make year variables numeric */
foreach var of varlist year* {
  replace `var' = substr(`var', 1, strpos(`var', "-") - 1) if strpos(`var', "-") > 0
  destring `var', replace
}

/* drop bad obs */
drop if v2 == "1" | v2 == "Sr. No."
drop if real(serial) == .

/* drop useless vars */
drop string flag v1 v2 serial

/* encode collaboration */
foreach var in surface_type collaboration {
  encode `var', gen(__tmp)
  drop `var'
  ren __tmp `var'
}

/* fix new var */
make_binary new, one("new connectivity") zero("upgradation") label(new_upgrade)

/* destring and compress */
destring, replace ignore(",")
compress

/* save sanctioned projects working file */
duplicates drop
renpfix "" sp2_
order sp2_state_name sp2_district_name sp2_block_name
save $pmgsy_raw/sanctioned_projects2, replace
/* N = 261,131 */


/*********************************************/
/* Habitation Coverage (aka Habitation List) */
/*********************************************/

/* use data from both scrapes to get all possible observations */
insheet using  ~/iec/misc_data/pmgsy/new_scrape/hc.csv, comma clear
save $tmp/hc, replace
insheet using  ~/iec/misc_data/pmgsy/new_scrape/hc2.csv, comma clear
append using $tmp/hc

/* drop duplicates */
duplicates drop 

/* rename variables */
ren v2 serial
ren v3 state_name
ren v4 district_name
ren v5 block_name
ren v6 village_name
ren v7 hab_name
ren v8 mla_constituency      
ren v9 ls_constituency      
ren v10 hab_pop
ren v11 hab_pop_scst
ren v12 connectivity_2000
ren v13 scheme
ren v14 school_primary
ren v15 school_middle
ren v16 school_high
ren v17 school_intermediate
ren v18 college
ren v19 health_services
ren v20 dispensary
ren v21 mcw_center
ren v22 phcs
ren v23 veternary_hospital
ren v24 telegraph_office
ren v25 telephone_connection
ren v26 bus
ren v27 railway
ren v28 electrified
ren v29 panchayat_hq
ren v30 tourist_place

/* drop bad obs */
drop if real(serial) == .
drop if real(district_name) != .

/* drop useless vars */
drop v1 serial
cap drop v3*
cap drop v4*
cap drop v5*
  
/* make variables binary */

/* yes/no */ 
make_binary school_primary school_middle school_high school_intermediate college health_services dispensary mcw_center phcs veternary_hospital telegraph_office telephone_connection bus railway electrified panchayat_hq tourist_place, one("yes") zero("no") label(yesno)

/* connected/unconnected */
make_binary connectivity_2000, one("connected") zero("unconnected") label(connected)

/* encode scheme */
encode scheme, gen(__tmp)
drop scheme
ren __tmp scheme

/* destring and compress */
destring, replace ignore(",")
compress

/* save sanctioned projects working file */
duplicates drop
renpfix "" hl2_
save $pmgsy_raw/habitation_list2, replace
/* N=1,115,386 */


/*****************************/
/* Progress Roadwise (New)   */
/*****************************/

/* roadwise progress of works */
insheet using  ~/iec/misc_data/pmgsy/new_scrape/rwpw.csv, comma clear

/* rename variables */
ren v2   serial
ren v3   district_name
ren v4   block_name
ren v5   package
ren v6   year_sanctioned
ren v7   road_name
ren v8   cost_sanctioned
ren v9   cost_state
ren v10  date_award
ren v11  date_completion_stipulated
ren v12  date_completion_actual
ren v13  completion_status

/* drop bad obs */
drop if real(serial) == .

/* clean package */
clean_package package

/* clean road names */
clean_road_name road_name, gen(road_name_clean)

/* Drop obs where we got only block data */
drop if strpos(year_sanctioned, "-") == 0

/* make year variables numeric */
foreach var of varlist year* {
  replace `var' = substr(`var', 1, strpos(`var', "-") - 1) if strpos(`var', "-") > 0
  destring `var', replace
}

/* generate state name */
gen state_name = substr(v1, strpos(v1, "[") + 1, strpos(v1, "]") - 2)

/* clean comp status */
replace completion_status = "" if completion_status == "-"
ren completion_status __tmp
encode __tmp, gen(completion_status)
drop __tmp

/* make dates date format */
foreach i of varlist date* {
  gen __tmp = date(`i', "DMY")
  drop `i'
  ren __tmp `i'
  format `i' %td
}

/* drop empty / useless vars */
drop v14 - v18 serial v1

/* destring and compress */
destring, replace ignore(",")
compress

/* drop bad obs: year == 1950, no data in them */
drop if year_sanc == 1950

/* save */
order state_name district_name block_name 
duplicates drop
renpfix "" pr2_
save $pmgsy_raw/progress_roadwise2, replace


/*****************************/
/* Completed Roads DVW (New) */
/*****************************/

/* Completed Roads with Value of Work Done */

/* create data for two districts where there was a server error */
/* Roads Completed has same data, so hand downloaded */
cd ~/iec/misc_data/pmgsy/new_scrape/roads_completed/
cap rm roads_completed_appended.dta
local files : dir . files "*.csv"
foreach file in `files' {

  /* insheet csv */
  insheet using "`file'", comma clear

  /* rename variables */
  gen state_name = lower(trim(substr(v3, (strpos(v3, "State: ") + 7), (strpos(v3, "District: ") - strpos(v3, "State: ") - 7))))
  replace state_name = state_name[_n - 1] if mi(state_name)
  ren v4   serial
  ren v5   district_name
  replace district_name = lower(trim(district_name))
  ren v6   block_name
  ren v7   package
  ren v8   year_sanctioned
  ren v9   road_name
  drop v10 v11
  ren v12  cost_sanctioned
  ren v13  cost_state
  ren v14  payment_total
  ren v15  date_completion
  drop v16-v19
  drop v1-v3

  /* drop bad obs */
  drop if real(serial) == .

  /* save */
  compress
  cap append using roads_completed_appended.dta
  save roads_completed_appended.dta, replace
}

/* use data from both scrapes to get all possible observations */
insheet using  ~/iec/misc_data/pmgsy/new_scrape/crvw.csv, comma clear
save $tmp/crvw, replace
insheet using  ~/iec/misc_data/pmgsy/new_scrape/crvw2.csv, comma clear
append using $tmp/crvw

/* drop duplicates */
duplicates drop 

/* rename vars */
ren v2   serial
ren v3   block_name
ren v4   package
ren v5   road_name
ren v6   year_sanctioned
ren v7   cost_sanctioned
ren v8   cost_state
ren v9   value_work
ren v10  payment_total
ren v11  date_completion

/* drop if mi(date_comletion) */
drop if mi(date_completion) | real(date_completion) == 0

/* generate state and district names */

/* generate state name */
gen state_name = substr(v1, strpos(v1, "[") + 1, strpos(v1, "]") - 2)

/* drop state name from v1 */
replace v1 = substr(v1, strpos(v1, "]") + 2, .)

/* generate district name */
gen district_name = substr(v1, strpos(v1, "[") + 1, strpos(v1, "]") - 2)

/* drop v1 */
drop v1

/* bring in data from hand download of Roads Completed (processed above) */
append using ~/iec/misc_data/pmgsy/new_scrape/roads_completed/roads_completed_appended.dta 

/* make year variables numeric */
foreach var of varlist year* {
  replace `var' = substr(`var', 1, strpos(`var', "-") - 1) if strpos(`var', "-") > 0
  destring `var', replace
}

/* clean package */
clean_package package

/* process date */
foreach i of varlist date_completion {
  gen __tmp = date(`i', "MY")
  drop `i'
  ren __tmp `i'
  format `i' %td
}

/* drop bad lines */
drop if real(serial) == .
drop if mi(year_sanctioned)
drop serial

/* clean road names */
clean_road_name road_name, gen(road_name_clean)

/* destring, rename, save */
destring, replace ignore(",")
order state_name district_name block_name
compress 
duplicates drop
renpfix "" dvw2_
save $pmgsy_raw/comp_roads_DVW2, replace
/* N = 107,843 */


/******************************/
/* Physical Progress of Works */
/******************************/

/* identical to sanctioned projects except includes year in the table, so making all var names the same */
/* other diffs: no collab var in pp2 */

insheet using  ~/iec/misc_data/pmgsy/new_scrape/ppw.csv, comma clear

/* rename variables */
ren v3 serial
ren v4 district_name 
ren v5 block_name 
ren v6 package
ren v7 year_sanctioned
ren v8 road_name
ren v9 new
ren v10 surface_type
ren v11 length_pavement
ren v12 cost_pavement
ren v13 count_cd_works
ren v14 cost_cd_works
ren v15 cost_lsb       
ren v16 cost_lsb_state
ren v17 cost_protection_works
ren v18 cost_other_works
ren v19 status
ren v20 length_completed
ren v21 expenditure_till_date
ren v22 cost_sanctioned
ren v23 hab_name
ren v24 hab_pop
ren v25 hab_pop_scst

/* drop bad obs */
drop if real(serial) == .

/* clean road names */
clean_road_name road_name, gen(road_name_clean)

/* generate state name */
gen state_name = substr(v1, strpos(v1, "[") + 1, strpos(v1, "]") - 2)

/* make year variables numeric */
foreach var of varlist year* {
  replace `var' = substr(`var', 1, strpos(`var', "-") - 1) if strpos(`var', "-") > 0
  destring `var', replace
}

/* drop useless vars */
drop v1 v2 serial

/* encode vars */
foreach var in surface_type status {
  encode `var', gen(__tmp)
  drop `var'
  ren __tmp `var'
}

/* make new binary */
make_binary new, one("new") zero("upgradation") label(new_upgrade)

/* destring and compress */
destring, replace ignore(",")
compress

/* save working file */
duplicates drop
renpfix "" pp2_
order pp2_state_name pp2_district_name pp2_block_name
save $pmgsy_raw/physical_progress2, replace
/* N = 240,008 */



