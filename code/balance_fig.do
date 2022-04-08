use $pmgsy_data/pmgsy_working_aer_mainsample, clear
do $pmgsy_code/settings

local controls $controls

/* loop over all control variables */
foreach v in $balance_vars {

  cap drop yhat
  cap drop `v'_resid

  local exclude `v'
  local controls_here : list controls - exclude  

  /* get the variable label for this var */
  local title: var label `v'

  /* residualize output variable on fixed effects */
  reg `v' `controls_here' i.vhg_dist_id [aw = kernel_${kernel}_${mainband}] if mainsample, r
  predict yhat
  gen `v'_resid = `v' - yhat

  /* generate rd graph */
  rd `v'_resid v_pop if mainsample, xq(bins20) bw start(-$ik_band) end($ik_band) name(`v') msize(small) `xtitle' title("`title'", size(medsmall)) ylabel(,labsize(small)) degree(1) 

  graph export $out/baseline_balance_`v'.eps, replace
  !convert -density 400 $out/baseline_balance_`v'.eps $out/baseline_balance_`v'.jpg
  !convert $out/baseline_balance_`v'.jpg $out/baseline_balance_`v'.pdf
  
  drop yhat `v'_resid
}

/* combine graphs for balance table */
graph combine $balance_vars, rows(3) graphregion(color(white)) 
graph export $out/baseline_balance.eps, replace
!convert -density 400 $out/baseline_balance.eps $out/baseline_balance.jpg
!convert $out/baseline_balance.jpg $out/baseline_balance.pdf
