use $pmgsy_data/pmgsy_working_aer_mainsample, clear
do $pmgsy_code/settings

/* delete old estimates */
cap rm $tmp/pop_age_gender_data.csv

/* Panel A: population */
ivregress 2sls pc11_pca_tot_p (r2011 = t) left right $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample, vce(robust)
store_est_tpl using $tmp/pop_age_gender_data.csv, all coef(r2011) name(lev)
sum pc11_pca_tot_p if e(sample) & t == 0
store_val_tpl using $tmp/pop_age_gender_data.csv, name("lev_mean") value(`r(mean)') format("%5.2f")

ivregress 2sls pc11_pop_ln   (r2011 = t) left right $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample, vce(robust)
store_est_tpl using $tmp/pop_age_gender_data.csv, all coef(r2011) name(log)
sum pc11_pop_ln if e(sample) & t == 0
store_val_tpl using $tmp/pop_age_gender_data.csv, name("log_mean") value(`r(mean)') format("%5.2f")

/* Panels B and C: age shares and male shares */
foreach gender in age male {
  foreach agegroup in 11_20 21_30 31_40 41_50 51_60 {
    ivregress 2sls secc_`gender'_share_`agegroup'  (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_tri_$mainband] if mainsample, vce(robust)
    store_est_tpl using $tmp/pop_age_gender_data.csv, all coef(r2012) name(`agegroup'`gender')
    sum secc_`gender'_share_`agegroup' if e(sample) & t == 0
    store_val_tpl using $tmp/pop_age_gender_data.csv, name("`agegroup'`gender'_mean") value(`r(mean)') format("%5.2f")
  }
}

/* generate table */
table_from_tpl, t($table_templates/pop_age_gender_tpl.tex) r($tmp/pop_age_gender_data.csv) o($out/pop_age_gender.tex) dropstars
