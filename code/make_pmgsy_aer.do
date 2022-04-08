/* RUNS ALL FILES NECESSARY FOR PMGSY ANALYSIS */

/* load settings */
do $pmgsy_code/settings

/* prep various datasets */
do $pmgsy_code/gen_night_lights_wide
do $pmgsy_code/gen_pc11_crops
//do $pmgsy_code/create_secc_vill_pop
//do $pmgsy_code/impute_consumption_expenditure_secc_rural

/* process parsed pmgsy data into stata files */
do $pmgsy_code/process_pmgsy_data

/* match of habitations to pc01 villages */
do $pmgsy_code/pc01_hab_match_aer

/* merge all pmgsy data together */
do $pmgsy_code/merge_new_scrape

/* create pmgsy analysis dataset */
do $pmgsy_code/create_pmgsy_aer

/* results for paper */
do $pmgsy_code/paper_results_aer_final
