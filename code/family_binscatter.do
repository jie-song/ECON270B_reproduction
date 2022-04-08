use $pmgsy_data/pmgsy_working_aer_mainsample, clear
do $pmgsy_code/settings

/* binscatters of indices */
foreach family in Transport Occupation Agriculture Consumption Firms {

  /* tweak ytitles a bit */
  if "`family'" == "Occupation" {
    local ytitle_index "Ag occupation index"
  }
  else if "`family'" == "Agriculture" {
    local ytitle_index "Ag production index"
  }
  else  {
    local ytitle_index "`family' index"
  }
  
  local fam = lower("`family'")
  cap drop yhat
  cap drop resid
  reg `fam'_index_andrsn $controls i.vhg_dist_id if mainsample
  predict yhat
  gen resid = `fam'_index_andrsn - yhat

  /* set binsize of 3 */
  local binsize 3
  local bins = 84 / `binsize'

  /* generate binscatters */
  rd resid v_pop if mainsample, xq(bins20) bw xtitle(Normalized population) ytitle(`ytitle_index') msize(small) ylabel(,labsize(small)) degree(1) start(-84) end(84) 
  graph save $out/bin_`fam'_controls, replace
  graph export $out/bin_`fam'_controls.eps, replace
  !epstopdf    $out/bin_`fam'_controls.eps
  graphout bin_`fam'_controls
  
}

/* combine index graphs */
graph combine $out/bin_transport_controls.gph $out/bin_occupation_controls.gph $out/bin_firms_controls.gph $out/bin_agriculture_controls.gph $out/bin_consumption_controls.gph , ycommon xcommon graphregion(color(white))
graph export $out/bin_family_indices_controls.eps, replace
!epstopdf $out/bin_family_indices_controls.eps


