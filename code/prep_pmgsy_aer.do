/* preps variables for analysis paper_results_aer_final.do */

/* load settings */
do $pmgsy_code/settings

/* get pc01 state names */
get_state_names

/* drop if missing location id's */
drop if mi(pc01_state_id) | mi(pc01_village_id)

/* rename vars for parsimony */
ren bpl_inc_source_subsistence_share bpl_inc_source_sub_share
ren secc_mech_farm_equip_share secc_mech_farm_share
ren secc_wall_mat_solid_share secc_wall_solid_share
ren secc_roof_mat_solid_share secc_roof_solid_share
ren hl2_pop_max hl2_pop

/* rename to con00 - connected in 2000 according to PMGSY - 1 means any habitation connected, 0 means none are */
ren hl2_conn2000_max con00

/**************************/
/* $shrug_data/shrug_pcec */
/**************************/

/* numeric id's for location fixed effects */
encode pc01_state_id, gen(state_id)
egen dist_id = group(pc01_state_id pc01_district_id)
egen subd_id = group(pc01_state_id pc01_district_id pc01_subdistrict_id)

/* tag districts */
egen dtag = tag(dist_id)

/* share of total workers in nonfarm firms in village */
gen ec13_emp_share = ec13_emp_all / pc11_pca_tot_work_p

/* baseline control variables */
gen tdist = pc01_vd_dist_town
gen elect = (pc01_vd_power_all == 1)
label var elect "pc01_vd_power_all == 1"
gen scst_share = (pc01_pca_p_sc + pc01_pca_p_st) / pc01_pca_tot_p
gen bus = pc01_vd_bs_fac == 1
gen comm = pc01_vd_comm_fac == 1
gen bank = pc01_vd_bank_fac
gen irr_share = pc01_vd_tot_irr / (pc01_vd_un_irr + pc01_vd_tot_irr)
gen ln_land = ln(pc01_vd_un_irr + pc01_vd_tot_irr + 1)
cap gen pc01_lit_share = 1 - (pc01_pca_p_ill / pc01_pca_tot_p)
gen primary_school = pc01_vd_p_sch > 0 if !mi(pc01_vd_p_sch)
gen med_center = pc01_vd_medi_fac
gen electric = (pc01_vd_power_supl == 1)
gen app_pr = (pc01_vd_app_pr == 1)
gen app_mr = (pc01_vd_app_mr == 1)
gen mcw = (pc01_vd_mcw_cntr > 0) if !mi(pc01_vd_mcw_cntr)
gen pc01_sc_share = pc01_pca_p_sc / pc01_pca_tot_p

/* ec13 */
foreach i in emp count {
  gen ec13_`i'_t = ec13_`i'_act1 + ec13_`i'_act2 +  ec13_`i'_act3 + ec13_`i'_act4 + ec13_`i'_act5 + ec13_`i'_act6
  gen ec13_`i'_nt = ec13_`i'_all - ec13_`i'_t
}
gen ec13_emp_ag = ec13_emp_act1 + ec13_emp_act2 + ec13_emp_act3 + ec13_emp_act4
gen ec13_emp_t_noag =   ec13_emp_act5 + ec13_emp_act6
foreach y of varlist ec13_emp_all ec13_count_all ec13_emp_t ec13_emp_nt ec13_emp_act1-ec13_emp_act23 ec13_emp_ag ec13_emp_t_noag {
  gen `y'_ln = log(`y' + 1)
}

/* pc11 */
cap gen pc11_ag_acre = pc11_vd_land_misc_trcp + pc11_vd_land_nt_swn
cap gen pc11_ag_acre_ln = log(pc11_ag_acre + 1)
gen pc11_pop_ln = log(pc11_pca_tot_p)

/* generate RD variables */

/* generate village level treatment vars */
gen     v_pop = pc01_pca_tot_p - 500 if inrange(pc01_pca_tot_p, 300, 700)
replace v_pop = pc01_pca_tot_p - 1000 if inrange(pc01_pca_tot_p, 700, 1300)
gen v_high_group = 1 if inrange(pc01_pca_tot_p, 700, 1300)
replace v_high_group = 0 if inrange(pc01_pca_tot_p, 300, 700)

/* create left and right hand side population variables */
gen t = v_pop >= 0 if !mi(v_pop)
gen left =  v_pop
gen right = v_pop
replace left = 0 if  v_pop > 0 & !mi(v_pop)
replace right = 0 if v_pop < 0 & !mi(v_pop)

/* create treatment variables */
gen t_high = t * v_high_group
gen t_low =  t * (1 - v_high_group)

/* generate fe var for high group interacted with district */
egen vhg_dist_id  = group(v_high_group dist_id)
egen vhg_state_id = group(v_high_group pmgsy_state_id)

/* create state-threshold dummies */
foreach state in as cg gj jh mh mp or rj up wb {
  local stateu = upper("`state'")
  gen `state'_h = (pmgsy_state_id == "`stateu'" & inrange(pc01_pca_tot_p, 701, 1300))
  gen `state'_l = (pmgsy_state_id == "`stateu'" & inrange(pc01_pca_tot_p, 300, 700))
}


/*******************************************/
/* $pmgsytmp/pmgsy2_pc01_master_village_fm */
/*******************************************/

/* continuous years of treatment and binary treatment var by year */
forval i = 2010/2013 {
  gen yt`i' = 0
  replace yt`i' = `i' - comp_year if !mi(comp_year)
  replace yt`i' = 0 if yt`i' < 0
  label var yt`i' "years of PMGSY treatment in `i'"
  gen r`i' = yt`i' > 0
  label var r`i' "PMGSY treatment status in `i'"
}

/* transform cost from lakh rupees into millions of dollars */
foreach year in 2005 2010 2011 2012 2013 {
  replace road_cost_`year' = 0 if mi(road_cost_`year')
  gen cost`year'usd = road_cost_`year' / 10 / 44.06
}


/*********************************************************************/
/* ~/iec2/secc/final/collapse/village_collapsed_master_dupsdrop */
/*********************************************************************/

/* ratio of secc population to pc11 population */
gen secc_pop_ratio = secc_tot_p / pc11_pca_tot_p

/* generate labor share vars */
gen nco2d_cultiv_share = (secc_nco04_1d_6_share*secc_jobs_1d_p + secc_nco04_2d_92_share*secc_jobs_2d_p) / (secc_jobs_1d_p - secc_nco04_1d_Y - secc_nco04_1d_Z)
gen nco2d_manlab_share = (secc_nco04_1d_9_share*secc_jobs_1d_p - secc_nco04_2d_92_share*secc_jobs_2d_p) / (secc_jobs_1d_p - secc_nco04_1d_Y - secc_nco04_1d_Z)

/* generate vars for share of hh owning amounts of land: landless, 0-2, 2-4, 4+ */
gen secc_acre_landless_share = secc_acre_bin0 / (secc_acre_bin0 + secc_acre_bin1 + secc_acre_bin2 + secc_acre_bin3 + secc_acre_bin4 + secc_acre_bin5 + secc_acre_bin6)
gen secc_acre_02_share = (secc_acre_bin1 + secc_acre_bin2) / (secc_acre_bin0 + secc_acre_bin1 + secc_acre_bin2 + secc_acre_bin3 + secc_acre_bin4 + secc_acre_bin5 + secc_acre_bin6)
gen secc_acre_24_share = secc_acre_bin3 / (secc_acre_bin0 + secc_acre_bin1 + secc_acre_bin2 + secc_acre_bin3 + secc_acre_bin4 + secc_acre_bin5 + secc_acre_bin6)
gen secc_acre_4p_share = (secc_acre_bin4 + secc_acre_bin5 + secc_acre_bin6) / (secc_acre_bin0 + secc_acre_bin1 + secc_acre_bin2 + secc_acre_bin3 + secc_acre_bin4 + secc_acre_bin5 + secc_acre_bin6)

/* irrigation */
gen any_irr_acre_share = (secc_two_crop_acre_sum + secc_other_irr_acre_sum) / (secc_two_crop_acre_sum + secc_unirr_land_acre_sum + secc_other_irr_acre_sum)
gen any_irr_acre_ln = log(secc_two_crop_acre_sum + secc_other_irr_acre_sum + 1)

/* generate variables for cultivation by landholding analysis */
gen nco_landless_cult_share = secc_nco_cult_acr_shr0
gen nco_01_cult_share = secc_nco_cult_acr_shr1
gen nco_1p_cult_share = (secc_nco_cult_acr2 + secc_nco_cult_acr3 + secc_nco_cult_acr4 + secc_nco_cult_acr5 + secc_nco_cult_acr6) / (secc_employed_acr2 + secc_employed_acr3 + secc_employed_acr4 + secc_employed_acr5 + secc_employed_acr6)
gen nco_02_cult_share = (secc_nco_cult_acr1 + secc_nco_cult_acr2) / (secc_employed_acr1 + secc_employed_acr2)
gen nco_24_cult_share = (secc_nco_cult_acr3) / (secc_employed_acr3)
gen nco_4p_cult_share = (secc_nco_cult_acr4 + secc_nco_cult_acr5 + secc_nco_cult_acr6) / (secc_employed_acr4 + secc_employed_acr5 + secc_employed_acr6)

/* jobs: aggregations of sex and age */
foreach sex in p m f {
  foreach nco in 6 9 Y {
    gen secc_nco04_1d_`nco'_`sex'_21_30_share = (secc_nco04_1d_`nco'_`sex'_21 + secc_nco04_1d_`nco'_`sex'_26) / (secc_nco04_1d_`sex'_21 + secc_nco04_1d_`sex'_26)
    gen secc_nco04_1d_`nco'_`sex'_31_40_share = (secc_nco04_1d_`nco'_`sex'_31 + secc_nco04_1d_`nco'_`sex'_36) / (secc_nco04_1d_`sex'_31 + secc_nco04_1d_`sex'_36)
    gen secc_nco04_1d_`nco'_`sex'_41_50_share = (secc_nco04_1d_`nco'_`sex'_41 + secc_nco04_1d_`nco'_`sex'_46) / (secc_nco04_1d_`sex'_41 + secc_nco04_1d_`sex'_46)
    gen secc_nco04_1d_`nco'_`sex'_51_60_share = (secc_nco04_1d_`nco'_`sex'_51 + secc_nco04_1d_`nco'_`sex'_56) / (secc_nco04_1d_`sex'_51 + secc_nco04_1d_`sex'_56)
    gen secc_nco04_1d_`nco'_`sex'_21_40_share = (secc_nco04_1d_`nco'_`sex'_21 + secc_nco04_1d_`nco'_`sex'_26 + secc_nco04_1d_`nco'_`sex'_31 + secc_nco04_1d_`nco'_`sex'_36) / (secc_nco04_1d_`sex'_21 + secc_nco04_1d_`sex'_26 + secc_nco04_1d_`sex'_31 + secc_nco04_1d_`sex'_36)
    gen secc_nco04_1d_`nco'_`sex'_41_60_share = (secc_nco04_1d_`nco'_`sex'_41 + secc_nco04_1d_`nco'_`sex'_46 + secc_nco04_1d_`nco'_`sex'_51 + secc_nco04_1d_`nco'_`sex'_56) / (secc_nco04_1d_`sex'_41 + secc_nco04_1d_`sex'_46 + secc_nco04_1d_`sex'_51 + secc_nco04_1d_`sex'_56)
    gen secc_nco04_1d_`nco'_`sex'_21_60_share = (secc_nco04_1d_`nco'_`sex'_21 + secc_nco04_1d_`nco'_`sex'_26 + secc_nco04_1d_`nco'_`sex'_31 + secc_nco04_1d_`nco'_`sex'_36 + secc_nco04_1d_`nco'_`sex'_41 + secc_nco04_1d_`nco'_`sex'_46 + secc_nco04_1d_`nco'_`sex'_51 + secc_nco04_1d_`nco'_`sex'_56) / (secc_nco04_1d_`sex'_21 + secc_nco04_1d_`sex'_26 + secc_nco04_1d_`sex'_31 + secc_nco04_1d_`sex'_36 + secc_nco04_1d_`sex'_41 + secc_nco04_1d_`sex'_46 + secc_nco04_1d_`sex'_51 + secc_nco04_1d_`sex'_56)
  }
}

foreach sex in p m f {
  gen secc_nco04_cultiv_`sex'_21_40_share = (secc_nco04_1d_6_`sex'_21 + secc_nco04_1d_6_`sex'_26 + secc_nco04_1d_6_`sex'_31 + secc_nco04_1d_6_`sex'_36 + secc_nco04_2d_92_`sex'_21 + secc_nco04_2d_92_`sex'_26 + secc_nco04_2d_92_`sex'_31 + secc_nco04_2d_92_`sex'_36) / (secc_nco04_1d_`sex'_21 + secc_nco04_1d_`sex'_26 + secc_nco04_1d_`sex'_31 + secc_nco04_1d_`sex'_36 - secc_nco04_1d_Y_`sex'_21 - secc_nco04_1d_Y_`sex'_26 - secc_nco04_1d_Y_`sex'_31 - secc_nco04_1d_Y_`sex'_36 - secc_nco04_1d_Z_`sex'_21 - secc_nco04_1d_Z_`sex'_26 - secc_nco04_1d_Z_`sex'_31 - secc_nco04_1d_Z_`sex'_36)
  gen secc_nco04_cultiv_`sex'_41_60_share = (secc_nco04_1d_6_`sex'_41 + secc_nco04_1d_6_`sex'_46 + secc_nco04_1d_6_`sex'_51 + secc_nco04_1d_6_`sex'_56 + secc_nco04_2d_92_`sex'_41 + secc_nco04_2d_92_`sex'_46 + secc_nco04_2d_92_`sex'_51 + secc_nco04_2d_92_`sex'_56) / (secc_nco04_1d_`sex'_41 + secc_nco04_1d_`sex'_46 + secc_nco04_1d_`sex'_51 + secc_nco04_1d_`sex'_56 - secc_nco04_1d_Y_`sex'_41 - secc_nco04_1d_Y_`sex'_46 - secc_nco04_1d_Y_`sex'_51 - secc_nco04_1d_Y_`sex'_56 - secc_nco04_1d_Z_`sex'_41 - secc_nco04_1d_Z_`sex'_46 - secc_nco04_1d_Z_`sex'_51 - secc_nco04_1d_Z_`sex'_56)
  gen secc_nco04_manlab_`sex'_21_40_share = (secc_nco04_1d_9_`sex'_21 + secc_nco04_1d_9_`sex'_26 + secc_nco04_1d_9_`sex'_31 + secc_nco04_1d_9_`sex'_36 - secc_nco04_2d_92_`sex'_21 - secc_nco04_2d_92_`sex'_26 - secc_nco04_2d_92_`sex'_31 - secc_nco04_2d_92_`sex'_36) / (secc_nco04_1d_`sex'_21 + secc_nco04_1d_`sex'_26 + secc_nco04_1d_`sex'_31 + secc_nco04_1d_`sex'_36 - secc_nco04_1d_Y_`sex'_21 - secc_nco04_1d_Y_`sex'_26 - secc_nco04_1d_Y_`sex'_31 - secc_nco04_1d_Y_`sex'_36 - secc_nco04_1d_Z_`sex'_21 - secc_nco04_1d_Z_`sex'_26 - secc_nco04_1d_Z_`sex'_31 - secc_nco04_1d_Z_`sex'_36)
  gen secc_nco04_manlab_`sex'_41_60_share = (secc_nco04_1d_9_`sex'_41 + secc_nco04_1d_9_`sex'_46 + secc_nco04_1d_9_`sex'_51 + secc_nco04_1d_9_`sex'_56 - secc_nco04_2d_92_`sex'_41 - secc_nco04_2d_92_`sex'_46 - secc_nco04_2d_92_`sex'_51 - secc_nco04_2d_92_`sex'_56) / (secc_nco04_1d_`sex'_41 + secc_nco04_1d_`sex'_46 + secc_nco04_1d_`sex'_51 + secc_nco04_1d_`sex'_56 - secc_nco04_1d_Y_`sex'_41 - secc_nco04_1d_Y_`sex'_46 - secc_nco04_1d_Y_`sex'_51 - secc_nco04_1d_Y_`sex'_56 - secc_nco04_1d_Z_`sex'_41 - secc_nco04_1d_Z_`sex'_46 - secc_nco04_1d_Z_`sex'_51 - secc_nco04_1d_Z_`sex'_56)
}


/* generate ratios of population to reference group */
foreach i in p m f {

  /* generate 1_10 */
  gen secc_age_1_10_`i' = secc_age_1_5_`i' + secc_age_6_10_`i'

  /* generate 6_15 */
  gen secc_age_6_15_`i' = secc_age_6_10_`i' + secc_age_11_15_`i'

  /* generate 16_25 */
  gen secc_age_16_25_`i' = secc_age_16_20_`i' + secc_age_21_25_`i'

  /* generate 16_35 */
  gen secc_age_16_35_`i' = secc_age_16_20_`i' + secc_age_21_25_`i' + secc_age_26_30_`i' + secc_age_31_35_`i'

  /* generate 21_40 */
  gen secc_age_21_40_`i' = secc_age_21_25_`i' + secc_age_26_30_`i' + secc_age_31_35_`i' + secc_age_36_40_`i'

  /* generate ref group pop: 41 - 60 */
  gen secc_age_41_60_`i' = secc_age_41_45_`i' + secc_age_46_50_`i' + secc_age_51_55_`i' + secc_age_56_60_`i'

  foreach j in 1_10 6_15 16_25 16_35 21_40 {

    /* generate ratios */
    gen secc_age_ratio_`j'_`i' = secc_age_`j'_`i' / secc_age_41_60_`i'

  }

}

/* generate age and gender counts and shares for population pyramid */
foreach gender in p m f {
  foreach i in 11 21 31 41 51 {
    local j = `i' + 5
    local k = `i' + 4
    local l = `i' + 9
    gen secc_age_`i'_`l'_`gender' = secc_age_`i'_`k'_`gender' + secc_age_`j'_`l'_`gender'
  }
}
foreach i in 1 11 21 31 41 51 {
  local l = `i' + 9
  gen secc_male_share_`i'_`l' = secc_age_`i'_`l'_m / secc_age_`i'_`l'_p
  gen secc_age_share_`i'_`l' = secc_age_`i'_`l'_p / secc_sexage_p
}


/********************************************************************/
/* ~/iec2/secc/final/collapse/village_consumption_imputed_pc01 */
/********************************************************************/

/* winsorize consumption */
winsorize secc_cons_per_cap 1 99, centile gen(cons_pc_win)
gen cons_pc_win_ln = log(cons_pc_win)

/***********************************************/
/* $pmgsy_data/pc11_poly_nl_wide_pc01 */
/***********************************************/

/* log night light variables */
forval i = 2000/2013 {
  gen ln_light`i' = log(total_light`i' + 1)
  gen light_bin`i' = ln_light`i' > 0 if !mi(ln_light`i')
}
egen total_light2011_2013 = rowmean(total_light2011 total_light2012 total_light2013)
egen total_light2000_2002 = rowmean(total_light2000 total_light2001 total_light2002)
foreach i in 2011_2013 2000_2002 {
  gen ln_light`i' = log(total_light`i' + 1)
}

/*******************/
/* $ndvi/ndvi_pc01 */
/* $ndvi/evi_pc01  */
/*******************/

/* ag productivity: ndvi/evi */
foreach y in max delta cumul {
  foreach vi in ndvi evi {
    egen `vi'_`y'_2011_2013 = rowmean(`vi'_`y'_2011 `vi'_`y'_2012 `vi'_`y'_2013)
    gen `vi'_`y'_2011_2013_ln = log(`vi'_`y'_2011_2013)
    egen `vi'_`y'_2000_2002 = rowmean(`vi'_`y'_2000 `vi'_`y'_2001 `vi'_`y'_2002)
    gen `vi'_`y'_2000_2002_ln = log(`vi'_`y'_2000_2002)
    foreach i in 2000 2001 2002 2003 2012 2013 2014 {
      cap gen `vi'_`y'_`i'_ln = log(`vi'_`y'_`i')
    }
  }
}

/*********************************/
/* generate rdd sample variables */
/*********************************/

/* calculate optimal bandwidths, IK and CCT, storing calculated bandwidths in globals */
global ik = 84
global cct = 78

/* generate bandwidth vars */
foreach band in $rdbands {
  cap drop rd_band_`band'
  gen rd_band_`band' = inrange(pc01_pca_tot_p, (500-`band'), (500+`band')) | inrange(pc01_pca_tot_p, (1000-`band'), (1000+`band')) if !mi(pc01_pca_tot_p)
}

/* generate optimal bandwidth vars */
gen rd_band_ik = inrange(pc01_pca_tot_p, (500-$ik), (500+$ik)) | inrange(pc01_pca_tot_p, (1000-$ik), (1000+$ik)) if !mi(pc01_pca_tot_p)
gen rd_band_cct = inrange(pc01_pca_tot_p, (500-$cct), (500+$cct)) | inrange(pc01_pca_tot_p, (1000-$cct), (1000+$cct)) if !mi(pc01_pca_tot_p)

/* generate kernels to be used with different bandwidths */
foreach band in $rdbands {
  gen kernel_tri_`band' = (((`band' + 1) - abs(v_pop)) / (`band' + 1)) * (abs(v_pop) < (`band' + 1))
  cap drop kernel_rec_`band'
  gen kernel_rec_`band' = 1
}
gen kernel_tri_ik = (($ik - abs(v_pop)) / $ik) * (abs(v_pop) < $ik)
gen kernel_rec_ik = 1

/* set main analysis sample */
quireg nco2d_cultiv_share t left right $controls i.vhg_dist_id [aw = kernel_${kernel}_ik] if $states & $noroad & $nobad & rd_band_ik & _m_pmgsy == 3
gen mainsample = e(sample)

/* rescale asset index for main sample */
sum secc_asset_index if mainsample, d
gen secc_asset_index_norm = (secc_asset_index - `r(mean)')/`r(sd)'
label var secc_asset_index_norm "SECC Rural mean household asset index mean 0 SD 1"

/* generate proper bins for binscatters */
gen_rd_bins v_pop, n(20) gen("bins20") cut(0) if(`" "keep if mainsample" "')


/******************/
/* family indexes */
/******************/

/* create reverse treatment dummy, where 1 = non-treated. this will be
fed into the index creation program so non-treated villages are used
as the normalizing standard deviation */
gen controldummy = 0 
replace controldummy = 1 if t == 0 & mainsample

/* change the working directory to be sure that we
have access to the gweightave fuction, which is in
$pmgsy_code/aer/_gweightave2.ado */
cd $pmgsy_code/aer

/* generate indices for main sample. NOTE - the egen function
weightave2 function comes from _gweightave2.ado - the .ado file will
be read into stata when it's in the working directory of the do file
that calls it. however - it is better practice to put it in your
personal ado path - which is ~/ado/personal. this function was sent
from Bilal Siddiqi to Sam Asher, based on Anderson (2008): Multiple
Inference and Gender Differences in the Effects of Early Intervention:
A Reevaluation of the Abecedarian, Perry Preschool, and Early Training
Projects. NB - discovered a problem with using if statements to
subsample - it breaks the index generation entirely. Careful!! */
foreach family in transport occupation firms agriculture consumption {

  if "`family'" == "firms" {

    /* we do a preserve-restore here because the if statement breaks
    the egen-weightave2 */
    cap drop `family'_index_andrsn
    preserve
    keep if $nobad_firms
    qui egen `family'_index_andrsn = weightave2(${`family'_vars}), normby(controldummy)
    label var `family'_index_andrsn "anderson adjusted index for `family' family of vars"

    /* keep our new index, and merge it back in to our preserved dataset */
    keep pc01_state_id pc01_village_id `family'_index_andrsn 
    save  $tmp/andrsn_firms, replace
    restore
    merge 1:1 pc01_state_id pc01_village_id using $tmp/andrsn_firms, nogen
  }

  else {
    cap drop `family'_index_andrsn
    qui egen `family'_index_andrsn = weightave2(${`family'_vars}), normby(controldummy)
    label var `family'_index_andrsn "anderson adjusted index for `family' family of vars"
  }
}

/*******************/
/* label variables */
/*******************/

get_var_labels
qui do $pmgsy_code/label_vars




