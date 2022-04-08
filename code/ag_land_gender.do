use $pmgsy_data/pmgsy_working_aer_mainsample, clear
do $pmgsy_code/settings

/* Panel A: Landholdings */
foreach i in landless 02 24 4p {
  qui ivregress 2sls nco_`i'_cult_share (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_${kernel}_${mainband}] if mainsample, vce(robust)
  store_est_tpl using $tmp/ag_land_gender_data.csv, all coef(r2012) name(acre`i')
  sum nco_`i'_cult_share if e(sample) & t == 0
  store_val_tpl using $tmp/ag_land_gender_data.csv, name("acre`i'_mean") value(`r(mean)') format("%5.3f")
}

/* Panel B: Age/gender */
foreach gender in p m f {
  foreach agegroup in 21_40 41_60 {
    ivregress 2sls secc_nco04_cultiv_`gender'_`agegroup'_share (r2012 = t) left right $controls i.vhg_dist_id [aw = kernel_${kernel}_${mainband}] if mainsample, vce(robust)
    store_est_tpl using $tmp/ag_land_gender_data.csv, all coef(r2012) name(`gender'`agegroup')
    sum secc_nco04_cultiv_`gender'_`agegroup'_share if e(sample) & t == 0
    store_val_tpl using $tmp/ag_land_gender_data.csv, name("`gender'`agegroup'_mean") value(`r(mean)') format("%5.3f")
  }
}

table_from_tpl, t($table_templates/ag_land_gender_tpl.tex) r($tmp/ag_land_gender_data.csv) o($out/ag_land_gender.tex) dropstars

