/*********************************/
/* PMGSY:                        */
/* Spillovers to nearby villages */
/*********************************/

/***** TABLE OF CONTENTS *****/
/* (1) Preamble and setup */
/* (2) Prep catchment generation in parallel */
/* (3) Write parallelizable program for catchment generation */
/* (4) Generate catchments in parallel */
/* (5) Use the spillover catchments to create new data */
/* (6) Run spillover data code in parallel */
/* (7) Clean up and assemble PMGSY spillover data */

/**************************/
/* (1) Preamble and setup */
/**************************/

/*
INSTALLING GNU PARALLEL: N.B.: this code leverages GNU parallel for
speeding up data generation. this needs to be installed on your local
machine. to do so, use the following steps in your shell:

wget https://git.savannah.gnu.org/cgit/parallel.git/plain/src/parallel
chmod 755 parallel
cp parallel sem
mv parallel sem dir-in-your-$PATH/bin/

adding to your path will vary.

APPROACH:
create dummy variables for village being within defined proximity
(either 5 or 10km) of village of interest - for all villages. So two
new dummy variables created for each village in the sample.

NOTE: Due to the maximum variable constraint in Stata (~30K), there's
some code in here the splits our central villages that define our
catchments into groups of 10K or less, then does the data creation and
compiles everything at the end. If you want it to run real fast, you
can decrease this maximum group size when `no_groups` is
instantiated. */

/* prep settings and programs */
clear all
set maxvar 30000
do $pmgsy_code/settings.do

/* read in the intermediate working data, saved before this do file is
called by paper_results */
use $tmp/pmgsy_working_aer_tmp, clear


/*********************************************/
/* (2) Prep catchment generation in parallel */
/*********************************************/

/* begin the overall timer */
timer clear 1
timer on 1
display "Overall begin time: $S_TIME"

/* restrict on catchment sample setting - various quality measures
defined in settings.do */
keep if $catch_sample

/* create the spillover sample */
gen spill_sample = 0
replace spill_sample = 1 if $spill_sample

/* get rid of the vars we don't need for this exercise */
keep pc01_state_id pc01_village_id pc01_district_id pc01_subdistrict_id latitude longitude spill_sample pc01_vd_area pc11_vd_area ec13_emp_all secc_high_inc* secc_jobs_1d_p secc_nco04_1d_Y secc_nco04_1d_Z nco2d_cultiv_share secc_cons_per_cap *andrsn mainsample t ndvi_delta_2000_2002 ndvi_delta_2011_2013 ec13_emp_share
    
/* merge in village pop numbers - created by collapsing hh_pop
variable (itself collapsed from members_clean SECC data) to the
village level. */
merge m:1 pc01_village_id pc01_state_id using $pmgsy_data/india_vill_size.dta, keepusing(secc_vill_pop)
keep if _merge == 3
drop _merge

/* sort by village, before looping over all villages to create the dummies */
sort spill_sample pc01_state_id pc01_village_id

/* create unique village identifier for villages within PMGSY sample*/
egen pmgsy_seq = seq() if spill_sample

/* Now - we need to split our data into groups with ~10,000 or fewer
of the spill_sample villages per group. first, let's determine the
number of groups we need. */

/* get the number of core villages we have - which will determine our
catchments. this number will be stored in r(max) */
sum pmgsy_seq

/* get number of groups. */
local no_groups = ceil(`r(max)' / 10000)

/* generate a grouping variable with n = `no_groups' - but only call
"cut" if there is more than one group */
if `no_groups' > 1 {
  egen group_split = cut(pmgsy_seq), group(`no_groups')
}

/* if only one group, just add a single group dummy (indexed with 0) -
identical to mainsample but helps the rest of the code run below */
else {
  gen group_split = 0 if spill_sample
}

/* write out our core catchment villages to separate temporary files;
we will then merge these back in one by one and generate our spillover
data */

/* store all of the groups in a macro */
levelsof group_split, local(grouplevels)

/* save the working data to a temporary file, so we can then split it */
save $tmp/tmp_spill, replace

/* loop over our groups, reading in a section of the tempfile matching
our groups one by one, then write out those subsets of data to their
own tempfiles. */
foreach group in `grouplevels' {

  /* read in our desired subset */
  use $tmp/tmp_spill if group_split == `group'

  /* write out our batches */
  save $tmp/spillover_group_`group'_input, replace
}


/*************************************************************/
/* (3) Write parallelizable program for catchment generation */
/*************************************************************/

cap prog drop gen_pmgsy_spillover_catchments
prog def gen_pmgsy_spillover_catchments
{

  /* all we need is one arg: the group */
  syntax anything

  /* rename the local for clarity */
  local group `anything'
  
  /* read in our full dataset again, from our tempfile previously saved */
  use $tmp/tmp_spill, clear

  /* get rid of all core catchment villages in original sample - we
  will then be left with only the spillover villages.  */
  drop if !mi(group_split)

  /* append, not merge, our current group into the data (group currently in loop) */
  append using $tmp/spillover_group_`group'_input

  /* get the number of sample villages we have in this group, which
  defines the number of catchments we make */
  sum pmgsy_seq

  /* extract lowest and highest in sample village sequence to macros */
  local spill_sample_min `r(min)'
  local spill_sample_max `r(max)'
  local spill_sample_count = `spill_sample_max' - `spill_sample_min'
  
  /* make a macro of group + 1 for display purposes, since group is indexed at zero */
  local disp_group = `group' + 1

  /* generate dummy vars for within 5 and 10 km of each PMGSY sample village */
  display _n "Begin creating dummies for group `disp_group'/`no_groups': $S_TIME"
  forval i = `spill_sample_min'/ `spill_sample_max' {

    /* set local for monitoring purposes */
    local count = `i' - `spill_sample_min' + 1

    /* monitor progress */
    if mod(`count', 500) == 0 {
      display "Creating dummies for within-group village no. `count'/`spill_sample_count': $S_TIME"
    }

    /* get latitude for the sample village currently in the loop */
    qui sum latitude if pmgsy_seq == `i'
    local lat `r(mean)'

    /* do the same for longitude */
    qui sum longitude if pmgsy_seq == `i'
    local long `r(mean)'

    /* generate distances */
    qui gen __dist = sqrt((latitude - `lat')^2 + (longitude - `long')^2) * 107
    qui gen byte vdist5_`i' = inrange(__dist, 0, 5) & pmgsy_seq != `i'   
    qui gen byte vdist10_`i' = inrange(__dist, 0, 10) & pmgsy_seq != `i' 
    drop __dist
  }

  /* Prepare vars for capturing totals */

  /* drop observations that aren't in any of the catchments */
  egen incatchment = rowtotal(vdist*)
  display _n "Drop if not in a catchment"
  drop if incatchment == 0 & spill_sample == 0

  /* now save the total of villages that are counted within any
  catchment to a macro - these get summed after looping over all
  groups */
  gen counter = 1
  foreach dist in 5 10 {

    /* total up the count villages in each catchment */
    egen incatch`dist'k = rowtotal(vdist`dist'*)

    /* villages within any catchment */
    qui sum counter if incatch`dist'k > 0 & spill_sample == 0
    local `group'_in_any_catch`dist'k `r(sum)'
    disp _n "Number of villages in any catchment at `dist'km level for data group `group': ``group'_in_any_catch`dist'k'"
  
    /* villages within multiple catchments */
    qui sum counter if incatch`dist'k > 1 & spill_sample == 0
    local `group'_in_mult_catch`dist'k `r(sum)'
    disp "Number of villages in mult. catchments at `dist'km level for data group `group': ``group'_in_mult_catch`dist'k'"
  }
  
  /* generate intermediary vars that sum over catchment areas. first
  initialize appropriately. they will get added to for each village in
  the catchment area */
  gen count_5k = 0
  gen count_10k = 0
  label var count_5k "number of villages with 5km catchment"
  label var count_10k "number of villages with 10km catchment"

  /* then loop over villages, replacing the variables with the correct values */
  display _n "Begin creating catchment counts for `disp_group'/`no_groups': $S_TIME"
  forval i = `spill_sample_min'/`spill_sample_max' {

    /* set local for monitoring purposes */
    local count = `i' - `spill_sample_min' + 1

    /* monitor progress */
    if mod(`count', 500) == 0 {
      display "Counts for within-group village no. `i'/`spill_sample_count': $S_TIME"
    }

    /* variable for how many villages w/i 5km bounds  */
    qui count if vdist5_`i' == 1
    qui replace count_5k = r(N) if pmgsy_seq == `i'

    /* create another var for 10km bounds */
    qui count if vdist10_`i' == 1
    qui replace count_10k = r(N) if pmgsy_seq == `i'
  }

  /* write out our data which now has catchments as well as sample
  villages, ready for data aggregation */
  note: spill_sample is a broader specification than the pmgsy mainsample var.
  compress
  save $tmp/catchments_group`group', replace  
}
end
/* *********** END program gen_pmgsy_spillover_catchments ***************************************** */


/***************************************/
/* (4) Generate catchments in parallel */
/***************************************/

/* run gnu_parallelize */
gnu_parallelize, max(10) prog(gen_pmgsy_spillover_catchments) progloc($pmgsy_code/gen_spillover_data_indexes.do) maxvar pre_comma extract_prog prep_input_file(`grouplevels') diag trace tracedepth(1)


/*********************************************************/
/* (5) Write program for creating new data in catchments */
/*********************************************************/

/* write a program that will run the data generation for
a single group  */
cap prog drop gen_pmgsy_spillover_data
prog def gen_pmgsy_spillover_data
{

  /* we need the number of groups */
  syntax anything

  /* clean up the group local for readability */
  local group `anything'

  /* make it quiet */
  qui {
    
    /* set our anderson indexes into a macro we can use */
    local andrsn_indexes
    foreach family in transport occupation firms agriculture consumption {
      local andrsn_indexes `andrsn_indexes' `family'_index_andrsn
    }

    /* read in our catchment data for this group */
    use $tmp/catchments_group`group', clear

    /* get the number of sample villages we have in this group, which
    defines the number of catchments we make */
    sum pmgsy_seq

    /* extract lowest and highest in sample village sequence to macros */
    local spill_sample_min `r(min)'
    local spill_sample_max `r(max)'
    local spill_sample_count = `spill_sample_max' - `spill_sample_min'
    
    /* make a macro of group + 1 for display purposes, since group is indexed at zero */
    local disp_group = `group' + 1

    /* generate cultivation indicator, by reversing how the share was created */
    gen nco2d_cultiv = nco2d_cultiv_share * (secc_jobs_1d_p - secc_nco04_1d_Y - secc_nco04_1d_Z)
    label var nco2d_cultiv "Count working in ag"

    /* generate the denominator for the eventual cultiv_share var - number
    of people working, minus Y and Z codes */
    gen nco2d_cultiv_denom = (secc_jobs_1d_p - secc_nco04_1d_Y - secc_nco04_1d_Z)
    label var nco2d_cultiv_denom "Count employed, excluding Y and Z codes"

    /* replace the area variable so that it is zero for villages without NDVI
    data - this will become our denominator for rescaling the NDVI data
    after aggregation */
    replace pc01_vd_area = . if mi(ndvi_delta_2000_2002) | mi(ndvi_delta_2011_2013)

    /* rename ndvi vars, otherwise they're too long */
    rename ndvi_delta_2000_2002 ndvi_delta_base
    rename ndvi_delta_2011_2013 ndvi_delta_end
    
    /* multiply ndvi by village area - this will be divided by catchment
    area at the end */
    foreach period in base end {

      /* multiply ndvi by village area - this will be divided by catchment
      area at the end */
      gen ndvi_delta_`period'_spill = ndvi_delta_`period' * pc01_vd_area

      /* save the original var label, which will be applied to the final
      ndvi vars */
      local `period'_ndvilab : variable label ndvi_delta_`period'
    }
    
    /* multiply per-capita consumption by the village population. this
    gets rescaled back to per-capita after aggregating */
    gen secc_cons_tot = secc_cons_per_cap * secc_vill_pop

    /* same thing with our indexes */
    foreach index in `andrsn_indexes' {
      replace `index' = `index' * secc_vill_pop
    }
    
    /* for the firms index, we want to constrict on good quality ec13
    data. so remove bad villages */
    replace firms_index_andrsn = . if !inrange(ec13_emp_share, 0, 1)
    
    /* create the number with incomes above/below 5k, backing out from other vars */
    gen inc_5k_plus = secc_high_inc2 + secc_high_inc3
    label var inc_5k_plus "Count above 5k income"
    gen inc_denom = secc_high_inc1 + secc_high_inc2 + secc_high_inc3
    label var inc_denom "Sum of high_inc 1-3 - denom for inc5k+ var"

    /* Aggregate outcomes to catchment level. set the variables we
    want to aggregate by catchment */
    local varlist ec13_emp_all nco2d_cultiv nco2d_cultiv_denom inc_5k_plus inc_denom pc01_vd_area ndvi_delta_base_spill ndvi_delta_end_spill secc_cons_tot secc_vill_pop secc_nco04_1d_Y secc_nco04_1d_Z secc_jobs_1d_p `andrsn_indexes'
     
    /* loop over these vars */
    noi display _n "Begin aggregating outcomes for group `disp_group': $S_TIME"
    foreach y in `varlist' {
      
      /* print current var to screen, for monitoring */
      noi display _n "Begin working on: `y'.  Start time: $S_TIME"

      /* loop over distances of interest (5km, 10km) */
      foreach dist in 5 10 {

        /* generate spillover variables and label them */
        qui gen `y'_v`dist' = .
        label var `y'_v`dist' "`y' in villages within `dist' km"

        /* cycle over all pmgsy spill_sample villages in this group*/
        noi display "Aggregating `y' for `dist'km catchment no. 1/`spill_sample_count': $S_TIME"
        forval i = `spill_sample_min'/`spill_sample_max' {

          /* set local for monitoring purposes */
          local count = `i' - `spill_sample_min' + 1

          /* monitor progress */
          if mod(`count', 500) == 0 {
            noi display "Aggregating `y' for `dist'km catchment no. `count'/`spill_sample_count': $S_TIME"
          }
          
          /* generate temp vars for outcome of interest and sum over them */
          qui gen __`y'_v = `y' * vdist`dist'_`i'
          qui egen __`y'_v`dist' = total(__`y'_v)

          /* replace outcome var for specific pmgsy sample village */
          qui replace `y'_v`dist' = __`y'_v`dist' if pmgsy_seq == `i'

          /* drop temp vars */
          drop __`y'_v __`y'_v`dist'
        }
      }
      noi display "Finished working on: `y' in group `disp_group'.  End time: $S_TIME"
    }

    /* Re-create the non-additivity of previously modded vars */
    noi display _n "Begin reformatting outcomes for group `disp_group': $S_TIME"
    foreach dist in 5 10 {
      
      /* generate log of total employment count in catchment */
      gen ec13_emp_all_`dist'k_ln = log(ec13_emp_all_v`dist' + 1)
      label var ec13_emp_all_`dist'k_ln "log of ec13 w/i `dist' km"

      /* generate village-level average of employment count in catchment */
      gen ec13_emp_all_vill_`dist'k = ec13_emp_all_v`dist' / incatch`dist'k
      label var ec13_emp_all_vill_`dist'k "ec13_emp per village w/i `dist' km"

      /* generate LOG of village-level average of employment count in catchment */
      gen ec13_emp_all_vill_`dist'k_ln = log(ec13_emp_all_vill_`dist'k + 1)
      label var ec13_emp_all_vill_`dist'k_ln "log of ec13_emp per village w/i `dist' km"
      
      /* rescale consumption back to per-capita */
      gen cons_pc_`dist'k = secc_cons_tot_v`dist' / secc_vill_pop_v`dist'

      /* winsorize and take the log of consumption var */
      winsorize cons_pc_`dist'k 1 99, centile gen(cons_pc_win_`dist'k)
      gen cons_pc_win_`dist'k_ln = log(cons_pc_win_`dist'k + 1)
      label var cons_pc_win_`dist'k_ln "log winsorized per capita consumption"
      
      /* rescale our indexes */
      foreach index in `andrsn_indexes' {
        gen `index'_`dist'k = `index'_v`dist' / secc_vill_pop_v`dist'
        label var `index'_`dist'k "`index' within `dist'km catch., pop. weighted"
      }
      
      foreach period in base end {

        /* re-scale the NDVI metric - currently summed across catchment;
        needs to be divided by total catchment area with NDVI data*/
        replace ndvi_delta_`period'_spill_v`dist' = ndvi_delta_`period'_spill_v`dist' / pc01_vd_area_v`dist'

        /* log-transform the ndvi delta metric */
        gen ndvi_delta_`period'_spill_`dist'k_ln = log(ndvi_delta_`period'_spill_v`dist')
        label var ndvi_delta_`period'_spill_`dist'k_ln `"log ``period'_ndvilab' - w/i `dist'km"'
      }

      /* generate share of catchment w/ over 5K income */
      gen inc_5k_plus_`dist'k_share = (inc_5k_plus_v`dist' / (inc_5k_plus_v`dist' + inc_denom_v`dist'))
      label var inc_5k_plus_`dist'k_share "share of income > 5k in `dist' km catchment"
      
      /* generate share of catchment working in ag */
      gen nco2d_cultiv_`dist'k_share = (nco2d_cultiv_v`dist' / nco2d_cultiv_denom_v`dist')
      label var nco2d_cultiv_`dist'k_share "share working in ag in `dist' km catchment"

      /* generate share of catchment with Y and Z nco04 codes */
     foreach job in Y Z {
       gen secc_nco04_1d_`job'_share_`dist'k = secc_nco04_1d_`job'_v`dist' / secc_jobs_1d_p_v`dist'
       label var secc_nco04_1d_`job'_share_`dist'k "Unemployment within `dist' km: noc04 1d code `job' / secc_jobs_1d_p"
     }
    }
     
    /* keep only the catchment reference villages (sample villages), which
    now have the catchment-level data assigned to them as well (for 10km
    and 5km radii) */
    keep if spill_sample

    /* remove the catchment dummies, spill_sample, etc. keep
    mainsample and t as we will use them for rescaling the anderson
    indexes. */
    drop vdist* spill_sample latitude longitude

    /* write out our single-group output data, to a temporary file. */
    save $tmp/spillover_`group'_out, replace
  }
}
end
/* *********** END program gen_pmgsy_spillover_data ***************************************** */



/*******************************************/
/* (6) Run spillover data code in parallel */
/*******************************************/

/* run gnu_parallelize */
gnu_parallelize, max(12) prog(gen_pmgsy_spillover_data) progloc($pmgsy_code/gen_spillover_data_indexes.do) maxvar pre_comma extract_prog prep_input_file(`grouplevels') diag 



/**************************************************/
/* (7) Clean up and assemble PMGSY spillover data */
/**************************************************/

/* loop over our grouped output files, and compile them */
clear
foreach group in `grouplevels' {

  /* combine the output data for all the groups */
  append using $tmp/spillover_`group'_out
}

/* rescale our anderson indexes to mean 0 sd 1 - for pmgsy mainsample
and t = 1 (untreated control) */
foreach family in transport occupation firms agriculture consumption {

  /* loop over distances as well */
  foreach dist in 5 10 {
    
    /* capture mean and sd of each index for the subsample of interest */
    qui sum `family'_index_andrsn_`dist'k if mainsample == 1 & t == 0, d

    /* rescale */
    replace `family'_index_andrsn_`dist'k = (`family'_index_andrsn_`dist'k - `r(mean)') / `r(sd)'

    /* relabel */
    local label : variable label `family'_index_andrsn_`dist'k
    label var `family'_index_andrsn_`dist'k "`label': rescaled"
  }
}

/* add a couple variables */
gen unemp_5k = secc_nco04_1d_Y_share_5k
gen unclass_5k = secc_nco04_1d_Z_share_5k

/* get rid of mainsample and t */
drop mainsample t

/* write out to spillover data folder */
compress
save $pmgsy_data/pmgsy_spillover_outcomes, replace
