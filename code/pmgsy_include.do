/* This do file includes programs used in the build for "Rural Roads
and Local Economic Development" by Sam Asher and Paul Novosad */

/***** TABLE OF CONTENTS *****/
  /* program ddrop : drop any observations that are duplicated - not to be confused with "duplicates drop" */
  /* program rd : produce a nice RD graph, using polynomial (quartic default) for fits */
  /* program quireg : display a name, beta coefficient and p value from a regression in one line */
  /* program name_clean : standardize format of indian place names before merging */
  /* program winsorize: replace variables outside of a range(min,max) with min,max */
  /* program get_var_labels : Labels all variables from a source file */
  /* program disp_nice : Insert a nice title in stata window */
  /* program drop_prefix : Insert description here */
  /* program lf : Better version of lf */
  /* program make_binary: make a numeric binary variable out of string data */
  /* program binscatter_rd : Produce binscatter graphs that absorb variables on the Y axis only */
  /* program tag : Fast way to run egen tag(), using first letter of var for tag */
  /* program dtag : shortcut duplicates tag */
  /* program pyreg : runs a python stata loop */
  /* program graphout : Export graph to public_html/png to be viewable as png */
  /* program appendmodels : append stored estimates for making tables */
  /* program append_to_file : Append a passed in string to a file */
  /* program append_est_to_file : Appends a regression estimate to a csv file       */
  /* program collapse_save_labels: Save var labels before collapse */
  /* program collapse_apply_labels: Apply saved var labels after collapse */
  /* program gen_rd_bins : Insert description here */
  /* program call_matlab : Call matlab with a command, return value to stata */
  /* program gnu_parallelize : put together the parallelization of a section of code in bash */
  /* program extract_collapse_prog - assists gnu_parallelize */
  /* program prep_gnu_parallel_input_file - assists gnu_parallelize */
  /* clean_package: get rid of junk in package codes */
  /* clean_road_name: lowercase, trim and - <-> TO for road names */
  /* parse_filename: regex-based file name parser */
  /* clean_hab_name: minor trimming of habitation */
  /* merge_sub_table: merge on $tmp/subtable */
  /* program rd_pmgsy_old : More general rd graph function */
  /* program rd_pmgsy : More general rd graph function */
  /* program lincom_write : write est and stars */
  /* program probit_test : see prog comments for usage */
  /* program merge_cycle : exact merge over a series of different variable lists */
  /* program get_state_names : merge in statenames using ids */
  /* program masala_merge2 : Fuzzy match using masalafied levenshtein  */
  /* program masala_review : Reviews masala_merge results and calls masala_process  */
  /* program masala_process : Rejoins the initial files in a masala_merge           */
  /* program flag_duplicates : Insert description here */
  /* program masala_lev_dist : Calculate levenshtein distance between two vars */
  /* program capdrop : Drop a bunch of variables without errors if they don't exist */
  /* program cons_boot : primary consumption bootstrap program */
  /* program store_est_tpl__boot : consumption bootstrap tables  */
  /* program dc_density : McCrary test */


/* suppress output when reading in programs and macros */
qui {

  /* now for resuable code. programs: */
  
  /*********************************************************************************************************/
  /* program ddrop : drop any observations that are duplicated - not to be confused with "duplicates drop" */
  /*********************************************************************************************************/
  cap prog drop ddrop
  cap prog def ddrop
  {
    syntax varlist(min=1) [if]
  
    /* `0' contains the `if', so don't need to do anything special here */
    duplicates tag `0', gen(ddrop_dups)
    drop if ddrop_dups > 0 & !mi(ddrop_dups) 
    drop ddrop_dups
  }
  end
  /* *********** END program ddrop ***************************************** */

  /*************************************************************************************/
  /* program rd : produce a nice RD graph, using polynomial (quartic default) for fits */
  /*************************************************************************************/
  global rd_start -250
  global rd_end 250
  cap prog drop rd
  prog def rd
  {
    syntax varlist(min=2 max=2) [aweight pweight] [if], [degree(real 4) name(string) Bins(real 100) Start(real -9999) End(real -9999) MSize(string) YLabel(string) NODRAW bw xtitle(passthru) title(passthru) ytitle(passthru) xlabel(passthru) xline(passthru) absorb(string) control(string) xq(varname) cluster(passthru) nofit]

    tokenize `varlist'
    local xvar `2'

    preserve

    // Create convenient weight local
    if ("`weight'"!="") local wt [`weight'`exp']

    /* set start/end to global defaults (from include) if unspecified */
    if `start' == -9999 & `end' == -9999 {
      local start $rd_start
      local end   $rd_end
    }

    if "`msize'" == "" {
      local msize small
    }

    if "`ylabel'" == "" {
      local ylabel ""
    }
    else {
      local ylabel "ylabel(`ylabel') "
    }

    if "`name'" == "" {
      local name `1'_rd
    }

    /* set colors */
    if mi("`bw'") {
      local color_b "red"
      local color_se "blue"
    }
    else {
      local color_b "black"
      local color_se "gs8"
    }

    if "`se'" == "nose" {
      local color_se "white"
    }

    capdrop pos_rank neg_rank xvar_index xvar_group_mean rd_bin_mean rd_tag mm2 mm3 mm4 l_hat r_hat l_se l_up l_down r_se r_up r_down total_weight rd_resid
    qui {
      /* restrict sample to specified range */
      if !mi("`if'") {
        keep `if'
      }
      keep if inrange(`xvar', `start', `end')

      /* get residuals of yvar on absorbed variables */
      if !mi("`absorb'")  | !mi("`control'") {
        if !mi("`absorb'") {
          areg `1' `wt' `control' `if', absorb(`absorb')
        }
        else {
          reg `1' `wt' `control' `if'
        }
        predict rd_resid, resid
        local 1 rd_resid
      }

      /* GOAL: cut into `bins' equally sized groups, with no groups crossing zero, to create the data points in the graph */
      if mi("`xq'") {

        /* count the number of observations with margin and dependent var, to know how to cut into 100 */
        count if !mi(`xvar') & !mi(`1')
        local group_size = floor(`r(N)' / `bins')

        /* create ranked list of margins on + and - side of zero */
        egen pos_rank = rank(`xvar') if `xvar' > 0 & !mi(`xvar'), unique
        egen neg_rank = rank(-`xvar') if `xvar' < 0 & !mi(`xvar'), unique

        /* hack: multiply bins by two so this works */
        local bins = `bins' * 2

        /* index `bins' margin groups of size `group_size' */
        /* note this conservatively creates too many groups since 0 may not lie in the middle of the distribution */
        gen xvar_index = .
        forval i = 0/`bins' {
          local cut_start = `i' * `group_size'
          local cut_end = (`i' + 1) * `group_size'

          replace xvar_index = (`i' + 1) if inrange(pos_rank, `cut_start', `cut_end')
          replace xvar_index = -(`i' + 1) if inrange(neg_rank, `cut_start', `cut_end')
        }
      }
      /* on the other hand, if xq was specified, just use xq for bins */
      else {
        gen xvar_index = `xq'
      }

      /* generate mean value in each margin group */
      bys xvar_index: egen xvar_group_mean = mean(`xvar') if !mi(xvar_index)

      /* generate value of depvar in each X variable group */
      if mi("`weight'") {
        bys xvar_index: egen rd_bin_mean = mean(`1')
      }
      else {
        bys xvar_index: egen total_weight = total(wt)
        bys xvar_index: egen rd_bin_mean = total(wt * `1')
        replace rd_bin_mean = rd_bin_mean / total_weight
      }

      /* generate a tag to plot one observation per bin */
      egen rd_tag = tag(xvar_index)

      /* run polynomial regression for each side of plot */
      gen mm2 = `xvar' ^ 2
      gen mm3 = `xvar' ^ 3
      gen mm4 = `xvar' ^ 4

      /* set covariates according to degree specified */
      if "`degree'" == "4" {
        local mpoly mm2 mm3 mm4
      }
      if "`degree'" == "3" {
        local mpoly mm2 mm3
      }
      if "`degree'" == "2" {
        local mpoly mm2
      }
      if "`degree'" == "1" {
        local mpoly
      }

      reg `1' `xvar' `mpoly' `wt' if `xvar' < 0, `cluster'
      predict l_hat
      predict l_se, stdp
      gen l_up = l_hat + 1.65 * l_se
      gen l_down = l_hat - 1.65 * l_se

      reg `1' `xvar' `mpoly' `wt' if `xvar' > 0, `cluster'
      predict r_hat
      predict r_se, stdp
      gen r_up = r_hat + 1.65 * r_se
      gen r_down = r_hat - 1.65 * r_se
    }

    if "`fit'" == "nofit" {
      local color_b white
      local color_se white
    }

    /* fit polynomial to the full data, but draw the points at the mean of each bin */
    sort `xvar'
    twoway ///
      (line r_hat  `xvar' if inrange(`xvar', 0, `end') & !mi(`1'), color(`color_b') msize(vtiny)) ///
      (line l_hat  `xvar' if inrange(`xvar', `start', 0) & !mi(`1'), color(`color_b') msize(vtiny)) ///
      (line l_up   `xvar' if inrange(`xvar', `start', 0) & !mi(`1'), color(`color_se') msize(vtiny)) ///
      (line l_down `xvar' if inrange(`xvar', `start', 0) & !mi(`1'), color(`color_se') msize(vtiny)) ///
      (line r_up   `xvar' if inrange(`xvar', 0, `end') & !mi(`1'), color(`color_se') msize(vtiny)) ///
      (line r_down `xvar' if inrange(`xvar', 0, `end') & !mi(`1'), color(`color_se') msize(vtiny)) ///
      (scatter rd_bin_mean xvar_group_mean if rd_tag == 1 & inrange(`xvar', `start', `end'), xline(0, lcolor(black)) msize(`msize') color(black)),  `ylabel'  name(`name', replace) legend(off) `title' `xline' `xlabel' `ytitle' `xtitle' `nodraw' graphregion(color(white))
    restore
  }
  end
  /* *********** END program rd ***************************************** */


  /***********************************************************************************************/
  /* program quireg : display a name, beta coefficient and p value from a regression in one line */
  /***********************************************************************************************/
  cap prog drop quireg
  prog def quireg, rclass
  {
    syntax varlist(fv ts) [pweight aweight] [if], [cluster(varlist) title(string) vce(passthru) noconstant s(real 40) absorb(varlist) disponly]
    tokenize `varlist'
    local depvar = "`1'"
    local xvar = subinstr("`2'", ",", "", .)

    if "`cluster'" != "" {
      local cluster_string = "cluster(`cluster')"
    }

    if mi("`disponly'") {
      if mi("`absorb'") {
        cap qui reg `varlist' [`weight' `exp'] `if',  `cluster_string' `vce' `constant'
        if _rc == 1 {
          di "User pressed break."
        }
        else if _rc {
          display "`title': Reg failed"
          exit
        }
      }
      else {
        cap qui areg `varlist' [`weight' `exp'] `if',  `cluster_string' `vce' absorb(`absorb') `constant'
        if _rc == 1 {
          di "User pressed break."
        }
        else if _rc {
          display "`title': Reg failed"
          exit
        }
      }
    }
    local n = `e(N)'
    local b = _b[`xvar']
    local se = _se[`xvar']

    quietly test `xvar' = 0
    local star = ""
    if r(p) < 0.10 {
      local star = "*"
    }
    if r(p) < 0.05 {
      local star = "**"
    }
    if r(p) < 0.01 {
      local star = "***"
    }
    di %`s's "`title' `xvar': " %10.5f `b' " (" %10.5f `se' ")  (p=" %5.2f r(p) ") (n=" %6.0f `n' ")`star'"
    return local b = `b'
    return local se = `se'
    return local n = `n'
    return local p = r(p)
  }
  end


  /********************************************************************************/
  /* program name_clean : standardize format of indian place names before merging */
  /********************************************************************************/
  capture program drop name_clean
  program def name_clean
  {
    syntax varname, [dropparens GENerate(name) replace]
    tokenize `varlist'
    local name = "`1'"

    if mi("`generate'") & mi("`replace'") {
        display as error "name_clean: generate or replace must be specified"
        exit 1
    }

    /* if no generate specified, make replacements to same variable */
    if mi("`generate'") {
      local name = "`1'"
    }

    /* if generate specified, copy the variable and then slowly change it */
    else {
      gen `generate' = `1'
      local name = "`generate'"
    }

    /* lowercase, trim, trim sequential spaces */
    replace `name' = trim(itrim(lower(`name')))

    /* parentheses should be spaced as follows: "word1 (word2)" */
    /* [ regex correctly treats second parenthesis with everything else in case it is missing ] */
    replace `name' = regexs(1) + " (" + regexs(2) if regexm(`name', "(.*[a-z])\( *(.*)")

    /* drop spaces before close parenthesis */
    replace `name' = subinstr(`name', " )", ")", .)

    /* name_clean removes ALL special characters including parentheses but leaves dashes only for -[0-9]*/
    /* parentheses are removed at the very end to facilitate dropparens and numbers changes */

    /* convert punctuation to spaces */
    /* we don't use regex here because we would need to loop to get all replacements made */
    replace `name' = subinstr(`name',"*"," ",.)
    replace `name' = subinstr(`name',"#"," ",.)
    replace `name' = subinstr(`name',"@"," ",.)
    replace `name' = subinstr(`name',"$"," ",.)
    replace `name' = subinstr(`name',"&"," ",.)
    replace `name' = subinstr(`name', "-", " ", .)
    replace `name' = subinstr(`name', ".", " ", .)
    replace `name' = subinstr(`name', "_", " ", .)
    replace `name' = subinstr(`name', "'", " ", .)
    replace `name' = subinstr(`name', ",", " ", .)
    replace `name' = subinstr(`name', ":", " ", .)
    replace `name' = subinstr(`name', ";", " ", .)
    replace `name' = subinstr(`name', "*", " ", .)
    replace `name' = subinstr(`name', "|", " ", .)
    replace `name' = subinstr(`name', "?", " ", .)
    replace `name' = subinstr(`name', "/", " ", .)
    replace `name' = subinstr(`name', "\", " ", .)
    replace `name' = subinstr(`name', `"""', " ", .)
  * `"""' this line to correct emacs syntax highlighting '

    /* replace square and curly brackets with parentheses */
    replace `name' = subinstr(`name',"{","(",.)
    replace `name' = subinstr(`name',"}",")",.)
    replace `name' = subinstr(`name',"[","(",.)
    replace `name' = subinstr(`name',"]",")",.)

    /* trim once now and again at the end */
    replace `name' = trim(itrim(`name'))

    /* punctuation has been removed, so roman numerals must be separated by spaces */

    /* to be replaced, roman numerals must be preceded by ward, pt, part, no or " " */

    /* roman numerals to digits when they appear at the end of a string */
    /* require a space in front of the ones that could be ambiguous (e.g. town ending in 'noi') */
    replace `name' = regexr(`name', "(ward ?| pt ?| part ?| no ?| )i$", "1")
    replace `name' = regexr(`name', "(ward ?| pt ?| part ?| no ?| )ii$", "2")
    replace `name' = regexr(`name', "(ward ?| pt ?| part ?| no ?| )iii$", "3")
    replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )iv$", "4")
    replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )iiii$", "4")
    replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?)v$", "5")
    replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )iiiii$", "5")
    replace `name' = regexr(`name', "(ward ?|pt ?|part ?| no ?| )vi$", "6")
    replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )vii$", "7")
    replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )viii$", "8")
    replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )ix$", "9")
    replace `name' = regexr(`name', "(ward ?|pt ?|part ?| no ?| )x$", "10")
    replace `name' = regexr(`name', "(ward ?|pt ?|part ?|no ?| )xi$", "11")

    /* replace roman numerals in parentheses */
    replace `name' = subinstr(`name', "(i)",     "1", .)
    replace `name' = subinstr(`name', "(ii)",    "2", .)
    replace `name' = subinstr(`name', "(iii)",   "3", .)
    replace `name' = subinstr(`name', "(iv)",    "4", .)
    replace `name' = subinstr(`name', "(iiii)",  "4", .)
    replace `name' = subinstr(`name', "(v)",     "5", .)
    replace `name' = subinstr(`name', "(iiiii)", "5", .)

    /* prefix any digits with a dash */
    replace `name' = regexr(`name', "([0-9])", "-" + regexs(1)) if regexm(`name', "([0-9])")

    /* but change numbers that are part of names to be written out */
    replace `name' = subinstr(`name', "-24", "twenty four", .)

    /* don't leave a space before a dash [the only dashes left were inserted by the # steps above] */
    replace `name' = subinstr(`name', " -", "-", .)

    /* standardize trailing instances of part/pt to " part" */
    replace `name' = regexr(`name', " pt$", " part")
    replace `name' = regexr(`name', " \(pt\)$", " part")
    replace `name' = regexr(`name', " \(part\)$", " part")

    /* drop the word "village" and "vill" */
    replace `name' = regexr(`name', " vill(age)?", "")

    /* take important words out of parentheses */
    replace `name' = subinstr(`name', "(urban)", "urban", .)
    replace `name' = subinstr(`name', "(rural)", "rural", .)
    replace `name' = subinstr(`name', "(east)", "east", .)
    replace `name' = subinstr(`name', "(west)", "west", .)
    replace `name' = subinstr(`name', "(north)", "north", .)
    replace `name' = subinstr(`name', "(south)", "south", .)

    /* drop anything in parentheses?  do it twice in case of multiple parentheses. */
    /* NOTE: this may result in excess matches. */
    if "`dropparens'" == "dropparens" {
      replace `name' = regexr(`name', "\([^)]*\)", "")
      replace `name' = regexr(`name', "\([^)]*\)", "")
      replace `name' = regexr(`name', "\([^)]*\)", "")
      replace `name' = regexr(`name', "\([^)]*\)", "")
    }

    /* after making all changes that rely on parentheses, remove parenthese characters */
    /* since names with parens are already formatted word1 (word2) replace as "" */
    replace `name' = subinstr(`name',"(","",.)
    replace `name' = subinstr(`name',")"," ",.)

    /* trim again */
    replace `name' = trim(itrim(`name'))
  }
  end
  /* *********** END program name_clean ***************************************** */
  

  /*********************************************************************************/
  /* program winsorize: replace variables outside of a range(min,max) with min,max */
  /*********************************************************************************/
  cap prog drop winsorize
  prog def winsorize
  {
    syntax anything,  [REPLace GENerate(name) centile]

    tokenize "`anything'"

    /* require generate or replace [sum of existence must equal 1] */
    if (!mi("`generate'") + !mi("`replace'") != 1) {
      display as error "winsorize: generate or replace must be specified, not both"
      exit 1
    }

    if ("`1'" == "" | "`2'" == "" | "`3'" == "" | "`4'" != "") {
      di "syntax: winsorize varname [minvalue] [maxvalue], [replace generate] [centile]"
      exit
    }
    if !mi("`replace'") {
      local generate = "`1'"
    }
    tempvar x
    gen `x' = `1'

    /* reset bounds to centiles if requested */
    if !mi("`centile'") {

      centile `x', c(`2')
      local 2 `r(c_1)'

      centile `x', c(`3')
      local 3 `r(c_1)'
    }

    di "replace `generate' = `2' if `1' < `2'  "
    replace `x' = `2' if `x' < `2'
    di "replace `generate' = `3' if `1' > `3' & !mi(`1')"
    replace `x' = `3' if `x' > `3' & !mi(`x')

    if !mi("`replace'") {
      replace `1' = `x'
    }
    else {
      generate `generate' = `x'
    }
  }
  end
  /* *********** END program winsorize ***************************************** */


  /********************************************************************/
  /* program get_var_labels : Labels all variables from a source file */
  /********************************************************************/
  cap prog drop get_var_labels
  prog def get_var_labels
  {
    cap label var pc01_state_id "2001 PC State Id"
    cap label var pc01_pca_tot_p "Total population"
    cap label var pc91_pca_tot_p "PC91 Population"
    cap label var pc01_vd_dist_town "distance to nearest town"
    cap label var pc01_pca_p_sc "Scheduled Castes"
    cap label var pc01_pca_p_st "Scheduled tribes"
    cap label var pc01_pca_p_ill "Illiterates"
    cap label var pc01_vd_p_sch "number of primary schools in village"
    cap label var pc01_vd_power_supl "village has electricity"
    cap label var pc01_vd_app_pr "village accessible by paved road"
    cap label var pc01_vd_app_mr "village accessible by dirt road"
    cap label var bpl_landed_share "Share of households with land"
    cap label var bpl_inc_source_subsistence_share "Share of HH with subsistence agriculture as primary income source"
    cap label var bpl_inc_250plus "Share of households earning 250 Rs per month or above"
    cap label var comp_year "year pmgsy road completed"
    cap label var r2012 "Dummy variable indicating PMGSY road treatment in year 2012 or earlier"
    cap label var secc_ent_own_share "Share of HH owning a business (aka enterprise)"
    cap label var secc_refrig_share  "Share of HH owning a refrigerator"
    cap label var secc_land_own_share "Share of HH owning land"
    cap label var secc_mech_farm_share "Share of HH owning mechanized farm equipment (tractor, etc)"
    cap label var secc_irr_equip_share "Share of HH owning irrigation equipment"
    cap label var secc_kisan_cc_share "Share of HH owning a kisan credit card with >50k Rs credit limit"
    cap label var secc_veh_two_share "Share of households owning a motorized two wheel vehicle"
    cap label var secc_veh_three_share "Share of households owning a motorized three wheel vehicle"
    cap label var secc_veh_four_share "Share of households owning a motorized four wheel vehicle"
    cap label var secc_veh_boat_share  "Share of households owning a boat"
    cap label var secc_veh_any_share  "Share of households owning a any motorized vehicle"
    cap label var secc_wall_solid_share "Share of HH with house with solid walls"
    cap label var secc_roof_solid_share "Share of HH with house with solid roof"
    cap label var secc_inc_5k_plus_share "Share of households with a member earning at least 5k Rs per month"
    cap label var secc_inc_10k_plus_share "Share of households with a member earning at least 10k Rs per month"
    cap label var secc_inc_cultiv_share "Share of households reporting cultivation as the primary source of income"
    cap label var secc_inc_manlab_share "Share of households reporting manual labor as the primary source of income"
    cap label var secc_inc_domest_share "Share of households reporting domestic work as the primary source of income"
    cap label var secc_phone_share "Share of HH owing a phone"
    cap label var t               "Dummy for over population cutoff determining priority for PMGSY road"
    cap label var left            "2001 Pop - cutoff * 1(Pop left of cutoff)"
    cap label var right           "2001 Pop - cutoff * 1(Pop right of cutoff)"
    cap label var pc01_sc_share   "2001 share of pop scheduled caste"
    cap label var con00 "Paved road in 2000 according to PMGSY"
    cap label var app_pr "Paved road in 2001 according to census"
    cap label var v_high_group "inrange(2001 pop, 700, 1300)"
    cap label var pc01_ill_share "Share of people illiterate (2001 Census)"
    cap label var agrate_p01     "Share of workers in agriculture (2001 Census)"
    cap label var road_new "village got a new road at some point under PMGSY"
    cap label var pc01_vd_edu_fac "village has a school"
    cap label var pc01_vd_m_sch "number of middle schools in village"
    cap label var pc01_vd_app_fp "village accessible by footpath"
    cap label var award_year "year pmgsy road awarded"
    cap label var sanc_year "year pmgsy road sanctioned"
    cap label var state_name "(firstnm) state_name"
    cap label var pmgsy_state_id "(firstnm) pmgsy_state_id"
    cap label var pc01_ill_share "share of ppl in village illiterate"
    cap label var litrate_p01 "share literate"
    cap label var irr_share "share land irrigated"
    cap label var litrate_p11 "literacy rate in 2011 (everyone)"
    cap label var litrate_m11 "literacy rate in 2011 (men)"
    cap label var litrate_f11 "literacy rate in 2011 (women)"
    cap label var pc01_pca_tot_m "total male pouplation"
    cap label var pc01_pca_tot_f "total female population"
    cap label var pc01_pca_sc "total scheduled caste population"
  }
  end
  /* *********** END program get_var_labels ***************************************** */


  /***********************************************************/
  /* program disp_nice : Insert a nice title in stata window */
  /***********************************************************/
  cap prog drop disp_nice
  prog def disp_nice
  {
    di _n "+--------------------------------------------------------------------------------------" _n `"| `1'"' _n  "+--------------------------------------------------------------------------------------"
  }
  end
  /* *********** END program disp_nice ***************************************** */


  /*************************************************/
  /* program drop_prefix : Insert description here */
  /*************************************************/
  cap prog drop drop_prefix
  prog def drop_prefix
  {
    syntax, [EXCept(varlist)]
    local x ""

    foreach i of varlist _all {
      local x `x' `i'
      continue, break
    }

    local prefix = substr("`x'", 1, strpos("`x'", "_"))

    /* do it var by var instead of using renpfix so can pass exception parameters */
    local line = `"renpfix `prefix' """'
    di `"`line'"'
    `line'

    /* rename exception list */
    if "`except'" != "" {
      foreach var in `except' {
        local newvar = substr("`var'", strpos("`var'", "_") + 1 ,.)
        ren `newvar' `prefix'`newvar'
      }
    }

  }
  end
  /* *********** END program drop_prefix ***************************************** */
  

  /*************************************/
  /* program lf : Better version of lf */
  /*************************************/
  cap prog drop lf
  prog def lf
  {
    syntax anything
    d *`1'*, f
  }
  end
  /* *********** END program lf ***************************************** */


  /**************************************************************************/
  /* program make_binary: make a numeric binary variable out of string data */
  /**************************************************************************/
  cap prog drop make_binary
  prog def make_binary
  {
    syntax varlist, one(string) zero(string) [label(string)]

    /* cycle over varlist, replacing strings with 1s and 0s */
    foreach var in `varlist' {
      replace `var' = trim(lower(`var'))
      assert inlist(`var', "`one'", "`zero'", "")
      replace `var' = "1" if `var' == "`one'"
      replace `var' = "0" if `var' == "`zero'"
    }

    /* destring variables */
    destring `varlist', replace

    /* create value label */
    if !mi("`label'") {
      label define `label' 1 "`one'" 0 "`zero'", modify
      label values `varlist' `label'
    }

  }
  end
  /* *********** END program make_binary ***************************************** */


  /**********************************************************************************************/
  /* program binscatter_rd : Produce binscatter graphs that absorb variables on the Y axis only */
  /**********************************************************************************************/
  cap prog drop binscatter_rd
  prog def binscatter_rd
  {
    syntax varlist [aweight pweight] [if], [RD(passthru) NQuantiles(passthru) XQ(passthru) SAVEGRAPH(passthru) REPLACE LINETYPE(passthru) ABSORB(string) XLINE(passthru) XTITLE(passthru) YTITLE(passthru) BY(passthru)]
    cap drop yhat
    cap drop resid

    tokenize `varlist'

    // Create convenient weight local
    if ("`weight'"!="") local wt [`weight'`exp']

    reg `1' `absorb' `wt' `if'
    predict yhat
    gen resid = `1' - yhat

    local cmd "binscatter resid `2' `wt' `if', `rd' `xq' `savegraph' `replace' `linetype' `nquantiles' `xline' `xtitle' `ytitle' `by'"
    di `"RUNNING: `cmd'"'
    `cmd'
  }
  end
  /* *********** END program binscatter_rd ***************************************** */


  /*******************************************************************************/
  /* program tag : Fast way to run egen tag(), using first letter of var for tag */
  /*******************************************************************************/
  cap prog drop tag
  prog def tag
  {
    syntax anything [if]

    tokenize "`anything'"

    local x = ""
    while !mi("`1'") {

      if regexm("`1'", "pc[0-9][0-9][ru]?_") {
        local x = "`x'" + substr("`1'", strpos("`1'", "_") + 1, 1)
      }
      else {
        local x = "`x'" + substr("`1'", 1, 1)
      }
      mac shift
    }

    display `"RUNNING: egen `x'tag = tag(`anything') `if'"'
    egen `x'tag = tag(`anything') `if'
  }
  end
  /* *********** END program tag ***************************************** */


  /******************************************/
  /* program dtag : shortcut duplicates tag */
  /******************************************/
  cap prog drop dtag
  prog def dtag
  {
    syntax varlist [if]
    duplicates tag `varlist' `if', gen(dup)
    sort `varlist'
    tab dup
  }
  end
  /* *********** END program dtag ***************************************** */


  /********************************************/
  /* program pyreg : runs a python stata loop */
  /********************************************/
  cap prog drop pyreg
  prog def pyreg
  {
    syntax, xml(string) html(string)
    di c(current_time)
    di `"shell python ~/iecmerge/include/reg_search.py -o ~/public_html/`html'.html -d $tmp/`html'.do -c $tmp/`html'.csv -x `xml'.xml"'
    shell python ~/iecmerge/include/reg_search.py -o ~/public_html/`html'.html -d $tmp/`html'.do -c $tmp/`html'.csv -x `xml'.xml

    disp_nice "Running regressions"
    do $tmp/`html'.do
    di c(current_time)
  }
  end
  /* *********** END program pyreg ***************************************** */


  /****************************************************************************/
  /* program graphout : Export graph to public_html/png to be viewable as png */
  /****************************************************************************/
  cap prog drop graphout
  prog def graphout
  {
    syntax anything, [default large pdf out pdfout(string) QUIet]

    /* default to large */
    local large large

    /* strip space from anything */
    local anything = subinstr(`"`anything'"', " ", "", .)

    /* break if $out not defined */
    if mi("$out") /* & !mi("`out'") */ {
      disp as error "graphout FAILED: global \$out must be defined if 'out' is specified."
      exit 123
    }

    /* always start with an eps file to $tmp */
    qui {
      graph export `"$tmp/`anything'.eps"', replace

      /* if "pdf" or "out" is specified, send it to $out as well */
      if "`pdf'" == "pdf" | "`out'" == "out" {
        graph export `"$out/`anything'.eps"', replace
      }

      /* if pdf is requested, convert the eps to pdf */
      if "`pdf'" == "pdf" {
        noi di "Converting EPS to PDF..."
        shell epstopdf $out/`anything'.eps

        /* if pdfout() was specified, move this pdf file to the requested destination */
        if !mi("`pdfout'") {
          shell mv $out/`anything'.pdf `pdfout'
        }
      }

      /* if set to png format */
      if !mi("$graphout_png") | !mi("$pn_png") {

        /* create a png and move to public_html/png */
        /* resize larger for viewing by default, do not change resolution if noresize specified */
        if "`default'" == "default" {
          noi di "Default specified, keeping default image resolution."
          shell convert $tmp/`anything'.eps $tmp/`anything'.png
        }
        else if "`large'" == "large" {
          shell convert -size 960x960 -resize 960x960 -density 300 $tmp/`anything'.eps $tmp/`anything'.png
        }
        else {
          shell convert -size 640x640 -resize 640x640 $tmp/`anything'.eps $tmp/`anything'.png
        }

        /* move png to html folder */
        if mi("$pn_png") {
            copy $tmp/`anything'.png ~/public_html/png/`anything'.png, replace
            if mi("`quiet'") {
              shell echo "View graph at http://caligari.dartmouth.edu/~\$USER/png/`anything'.png"
            }
        }
        else {
            copy $tmp/`anything'.png ~/tmp/png/`anything'.png, replace
            if mi("`quiet'") {
              shell echo "View graph at file:///Users/`c(username)'/tmp/png/`anything'.png"
            }
        }
        erase $tmp/`anything'.png
      }
    }
  }
  end
  /* *********** END program graphout ***************************************** */


  /********************************************************************/
  /* program appendmodels : append stored estimates for making tables */
  /********************************************************************/
  /* version 1.0.0  14aug2007  Ben Jann*/
  cap prog drop appendmodels
  prog def appendmodels, eclass
  {
    /* using first equation of model version 8 */
    syntax namelist
    tempname b V tmp
    foreach name of local namelist {
      qui est restore `name'
      mat `tmp' = e(b)
      local eq1: coleq `tmp'
      gettoken eq1 : eq1
      mat `tmp' = `tmp'[1,"`eq1':"]
      local cons = colnumb(`tmp',"_cons")
      if `cons'<. & `cons'>1 {
        mat `tmp' = `tmp'[1,1..`cons'-1]
      }
      mat `b' = nullmat(`b') , `tmp'
      mat `tmp' = e(V)
      mat `tmp' = `tmp'["`eq1':","`eq1':"]
      if `cons'<. & `cons'>1 {
        mat `tmp' = `tmp'[1..`cons'-1,1..`cons'-1]
      }
      capt confirm matrix `V'
      if _rc {
        mat `V' = `tmp'
      }
      else {
        mat `V' = ( `V' , J(rowsof(`V'),colsof(`tmp'),0) ) \ ( J(rowsof(`tmp'),colsof(`V'),0) , `tmp' )
      }
    }

    local names: colfullnames `b'
    mat coln `V' = `names'
    mat rown `V' = `names'
    eret post `b' `V'
    eret local cmd "whatever"
  }
  end
  /* *********** END program appendmodels *****************************************/


  /****************************************************************/
  /* program append_to_file : Append a passed in string to a file */
  /****************************************************************/
  cap prog drop append_to_file
  prog def append_to_file
  {
    syntax using/, String(string) [format(string) erase]

    cap file close fh

    if !mi("`erase'") cap erase `using'

    file open fh using `using', write append
    file write fh  `"`string'"'  _n
    file close fh
  }
  end
  /* *********** END program append_to_file ***************************************** */


  /**********************************************************************************/
  /* program append_est_to_file : Appends a regression estimate to a csv file       */
  /**********************************************************************************/
  cap prog drop append_est_to_file
  prog def append_est_to_file
  {
    syntax using/, b(string) Suffix(string)

    /* get number of observations */
    qui count if e(sample)
    local n = r(N)

    /* get b and se from estimate */
    local beta = _b["`b'"]
    local se   = _se["`b'"]

    /* get p value */
    qui test `b' = 0
    local p = `r(p)'
    if "`p'" == "." {
      local p = 1
      local beta = 0
      local se = 0
    }
    append_to_file using `using', s("`beta',`se',`p',`n',`suffix'")
  }
  end
  /* *********** END program append_est_to_file ***************************************** */


  /*****************************************************************/
  /* program collapse_save_labels: Save var labels before collapse */
  /*****************************************************************/

  /* save var labels before collapse, saving varname if no label */
  cap prog drop collapse_save_labels
  prog def collapse_save_labels
  {
    foreach v of var * {
      local l`v' : variable label `v'
      global l`v'__ `"`l`v''"'
      if `"`l`v''"' == "" {
        global l`v'__ "`v'"
      }
    }
  }
  end
  /* **** END program collapse_save_labels *********************** */

  
  /************************************************************************/
  /* program collapse_apply_labels: Apply saved var labels after collapse */
  /************************************************************************/

  /* apply retained variable labels after collapse */
  cap prog drop collapse_apply_labels
  prog def collapse_apply_labels
  {
    foreach v of var * {
      label var `v' "${l`v'__}"
      macro drop l`v'__
    }
  }
  end
  /* **** END program collapse_apply_labels ***************************** */


  /*************************************************/
  /* program gen_rd_bins : Insert description here */
  /*************************************************/
  cap prog drop gen_rd_bins
  prog def gen_rd_bins
  {
    /* N is number of bins, gen is the new variable name, cut breaks
    bins into two sections (e.g. positive and negative). e.g. cut(0)
    will proportionally split desired bins into positive and negative,
    with 0 inclusive in positive bins. */
    syntax varlist(min=1 max=1), gen(string) [n(real 20) Cut(integer -999999999999) if(string)]

    cap drop rd_tmp_id
    
    /* if there is an `if' statement, we need a preserve/restore, and to
    execute the condition. */
    if !mi(`"`if'"') {
      gen rd_tmp_id = _n
      preserve
      foreach cond in `if' {
        `cond'
      }
    }

    /* get our xvar into a more legible macro */
    local xvar `varlist'

    /* create empty index var */
    cap drop `gen'
    gen `gen' = .

    /* calculate the proportionate number of bins above/below `cut',
    which defaults to -99999999999 - a value which just about guarantees
    all obs will be in the `above' split - so will divide into bins
    normally. */

    /* count below cut */
    count if !mi(`xvar')  & `xvar' < `cut'
    local below_count = `r(N)'

    /* count above cut, inclusive */
    count if !mi(`xvar') & `xvar' >= `cut'
    local above_count = `r(N)'

    /* number of below-cut groups, then above */
    local below_num_bins = floor((`below_count'/_N) * `n')
    local above_num_bins = `n' - `below_num_bins'

    /* number of obs in each group */
    local below_num_obs = floor(`below_count'/`below_num_bins')
    local above_num_obs = floor(`above_count'/`above_num_bins')

    /* rank our obs above and below cut */
    cap drop below_rank above_rank
    egen below_rank = rank(-`xvar') if `xvar' < `cut' & !mi(`xvar'), unique
    egen above_rank = rank(`xvar') if `xvar' >= `cut' & !mi(`xvar'), unique

    /* split into groups above/below cut */
    foreach side in above below {

      /* set a multiplier - negative bins will be < `cut', positive
      will be above */
      if "`side'" == "below" {
        local multiplier = -1
      }
      else if "`side'" == "above" {
        local multiplier = 1
      }

      /* loop over the number of bins either above or below, to
      reclassify our index */
      forval i = 1/``side'_num_bins' {

        /* get start and end of this specific bin (obs count) */
        local cut_start = (`i' - 1) * ``side'_num_obs'
        local cut_end = `i' * ``side'_num_obs'

        /* replace our bin categorical with the right group */
        replace `gen' = `multiplier' * (`i') if inrange(`side'_rank, `cut_start', `cut_end')
      }
    }

    /* now the restore and merge, if we have a subset condition */
    if !mi(`"`if'"') {

      /* save our new data */
      save $tmp/rd_bins_tmp, replace

      /* get our original data back, and merge in new index */
      restore
      merge 1:1 rd_tmp_id using $tmp/rd_bins_tmp, keepusing(`gen') nogen
      drop rd_tmp_id

      /* remove our temporary file */
      rm $tmp/rd_bins_tmp.dta
    }
  }
  end
  /* *********** END program gen_rd_bins ***************************************** */


  /***************************************************************************/
  /* program call_matlab : Call matlab with a command, return value to stata */
  /***************************************************************************/
  cap prog drop call_matlab
  prog def call_matlab, rclass
  {

    /* sample call: call_matlab, p("point_poly_match('x', 'y', 'z');") */
    syntax, Params(string) [success ret0]
  
    /* if ret0 passed in, success is implicit */
    if !mi("`ret0'") {
      local success "success"
    }
    
    /* prepare success file and add it to the matlab call */
    if !mi("`success'") {
      tempfile success_file
  
      /* find the last ')' in the call */
      local index = strlen("`params'") - strpos(reverse("`params'"), ")")
  
      /* insert success_file parameter right before last paren */
      local params = substr("`params'", 1, `index') + ", '`success_file''" + substr("`params'", `index' + 1, .)
    }
  
    /* make matlab call */
    di `"MATLAB CALL: matlab -nosplash -nodesktop -r "`params'; exit;"  "'
    shell matlab -nosplash -nodesktop -r "`params'; exit;"
  
    /* read return value if passed in */
    if !mi("`success'") {
      file open fh using "`success_file'", read
      file read fh line
      return local success = `line'
      file close fh
  
      /*  crash if matlab doesn't return zero  */
      if !mi("`ret0'") & "`line'" != "0" {
        display as error "ERROR: Matlab returned non-zero value."
        exit 123
      }
    }
  
    else {
      return local success = 0
    }
  }
  end
  /* *********** END program call_matlab ***************************************** */


  /*******************************************************************************************/
  /* program gnu_parallelize : put together the parallelization of a section of code in bash */
  /*******************************************************************************************/

  /* this program writes a few temp files and calls GNU parallel to run
  a program in parallel. assumes your program takes a `group' and a
  `directory' option. */

  /* a hypothetical example call of this would be:
  gnu_parallelize, max_cores(5) program(gen_data.do) input_txt($tmp/par_info.txt) progloc($tmp) options(group state) maxvar pre_comma diag */
  cap prog drop gnu_parallelize
  prog def gnu_parallelize
  {

    /* progloc is required if the program isn't in the default stata path. */
    syntax , MAX_jobs(real) PROGram(string) [INput_txt(string) options(string) progloc(string) pre_comma rmtxt maxvar DIAGnostics trace tracedepth(real 2) manual_input static_options(string) extract_prog prep_input_file(string)]

    /* create a random number that will serve as our job ID for this random task */
    !shuf -i 1-10000 -n 1 >> $tmp/randnum.txt

    /* read that random number into a stata macro */
    file open myfile using "$tmp/randnum.txt", read
    file read myfile line
    local randnum "`line'"
    file close myfile

    /* remove the temp file */
    rm $tmp/randnum.txt

    /* display our temporary do file location */
    if !mi("`diagnostics'") {
      disp_nice "Writing log and temp dofile to: $tmp/parallelizing_dofile_`randnum'.[do,log]"
    }

    /* initialize a temporary dofile that will run the data generation for
    a single group */
    file open group_dofile using "$tmp/parallelizing_dofile_`randnum'.do", write replace

    /* if we want a more diagnostic log, set trace on */
    if !mi("`trace'") {
    file write group_dofile "set trace on" _n
      file write group_dofile "set tracedepth `tracedepth'" _n
    }

    /* fill out the temp dofile. if we want to prepare the inputs
    (groups) into a text file, do so */
    if !mi("`prep_input_file'") {
      prep_gnu_parallel_input_file $tmp/gnu_parallel_input_file_`randnum'.txt, in(`prep_input_file')
      local input_txt $tmp/gnu_parallel_input_file_`randnum'.txt
    }

    /* if we want to expand maximum number of vars, do so */
    if !mi("`maxvar'") {
      file write group_dofile "clear all" _n
      file write group_dofile "clear mata" _n
      file write group_dofile "set maxvar 30000" _n
      file write group_dofile "qui do ~/iecmerge/include/include.do" _n
    }

    /* load in the program if necessary. */
    if !mi("`progloc'") {

      /* if we want the program to be extracted from a larger do-file,
      then do so */
      if !mi("`extract_prog'") {

        /* use program in include.do to extract program to temp, saving
        in $tmp/tmp_prog_extracted.do */
        extract_collapse_prog `program', progloc("`progloc'") randnum("`randnum'")
        if !mi("`diagnostics'") {
          file write group_dofile "do $tmp/tmp_prog_extracted_`randnum'.do" _n
        }
        else {
          file write group_dofile "qui do $tmp/tmp_prog_extracted_`randnum'.do" _n
        }
      }

      /* if no extraction needed, then use the program location */
      else if mi("`extract_prog'")  {
        if !mi("`diagnostics'") {
          file write group_dofile "do `progloc'" _n
        }
        else {
          file write group_dofile "qui do `progloc'" _n
        }
      }
    }

    /* show our input values (from "options") from the unix shell, if
    diagnostics are turned on. with manual override this won't do
    anything, so no harm done. */  
    if !mi("`diagnostics'") {

      /* if we have no input before the option comma, options start at 1 */
      local option_index 1
        if !mi("`pre_comma'") {
          /* if so, start at 2 */
          local option_index 2
          file write group_dofile "disp "
          file write group_dofile `"`=char(34)'"'
          file write group_dofile "\`1"
          file write group_dofile "'"
          file write group_dofile `"`=char(34)'"' _n
        }
      foreach option in `options' {
        file write group_dofile "disp "
        file write group_dofile `"`=char(34)'"'
        file write group_dofile " \``option_index'"
        file write group_dofile "'"
        file write group_dofile `"`=char(34)'"' _n
        local option_index = `option_index' + 1
      }
    }

    /* check if a manual override has been specified. if so, we need to
    get the complete program call lines in from our manual_override
    .txt, and call them one by one. */
    if !mi("`manual_input'") {

      /* step 1: count the number of program calls we need to make. */
      file open txtlines using `input_txt', read
      local num_lines = 1
      file read txtlines line
      while r(eof)==0 {
        file read txtlines line
        /* check if there's an empty line (somtimes happens at the end -
        assumes no missing lines in the middle*/
        if !mi("`line'") {
          local num_lines = `num_lines' + 1
        }
      }
      file close txtlines
      
      /* step 2: write a sequence, one number per line, of 1:count in a
      separate text file */
      file open index_seq using $tmp/index_sequence_`randnum'.txt, write replace
      forval line = 1/`num_lines' {
        file write index_seq "`line'" _n
      }
      file close index_seq
      
      /* step 3: change `input_txt' to this sequence, so gnu_parallelize
      will read our 1:count .txt file line by line, and save our old
      input file to pass to the program call */
      local manual_inputs `input_txt'
      local input_txt $tmp/index_sequence_`randnum'.txt
      
      /* step 4: tell our temporary do file to read the manual_override
      program call using a specific index line */
      file write group_dofile "file open manual_lines using `manual_inputs', read" _n
      file write group_dofile "local index_counter = 1" _n
      file write group_dofile "file read manual_lines line" _n
      file write group_dofile "while r(eof)==0 {" _n
      file write group_dofile "if `index_counter"
      file write group_dofile "' == 1"
      file write group_dofile " {" _n
      file write group_dofile "local program_command `line"
      file write group_dofile "'" _n
      file write group_dofile "}" _n
      file write group_dofile "file read manual_lines line" _n
      file write group_dofile "local index_counter = `index_counter"
      file write group_dofile "' + 1" _n
      file write group_dofile "}" _n
      file write group_dofile "file close manual_lines" _n

      /* step 5: execute this manual program call  */
      file write group_dofile "`program_command"
      file write group_dofile "'" _n
      file close group_dofile
      
      /* step 6: put the command to remove this temporary index text file into a local */
      local remove_manual_index "rm `input_txt'"
    }

    /* if we don't have manual override, we need to assemble the program
    call using shell variables from our input .txt file */
    if mi("`manual_input'") {
      
      /* having a first pre-comma (varlist or otherwise) shifts all the
      variables coming in from cat - so need two loops here */
      file write group_dofile "`program' "
      if !mi("`pre_comma'") {

        /* all following options will be passed from the shell in
        sequence, as they are read from the text file. if there is a
        pre-comma argument, that will take the position `1' and the other
        options will start at `2' */
        local option_index 2

        /* write out any arguments before the options, which will be
        couched in the bash var `1' */
        file write group_dofile "\`1"
        file write group_dofile "'"
      }

      /* if no initial vars, start at 1 */
      else {
        local option_index 1
      }

      /* if there are options, add the comma. */
      if !mi("`options'") {
        file write group_dofile ","
      }

      /* now deal with the options */
      foreach option in `options' {

        /* write the option name */
        file write group_dofile " `option'("

        /* write the option variable index number */
        file write group_dofile "\``option_index'"
        file write group_dofile"'"
        file write group_dofile ")"

        /* bump up the index for the next loop through */
        local option_index = `option_index' + 1
      }

      /* if there are additional static options across all lines, add those here */
      file write group_dofile " `static_options'"
      
      /* now finish the program call line and close the script. */
      file write group_dofile _n
      file close group_dofile
    }
    
    /* save working directory, then change to scratch */
    local workdir `c(pwd)'
    cd $tmp

    /* use the script we just wrote - in parallel! */
    !cat `input_txt' | parallel --gnu --progress --eta --delay 2.5 -j `max_jobs' "stata -e do parallelizing_dofile_`randnum' {}"

    /* remove our text file, if specified */
    if !mi("`rmtxt'") {
      rm `input_txt'
    }

    /* remove log and dofile, if specified */
    if mi("`diagnostics'") {
      rm parallelizing_dofile_`randnum'.do
    }

    /* change back to working directory */
    cd `workdir'
  }
  end
  /* *********** END program gnu_parallelize ***************************************** */
  

  /***********************************************************/
  /* program extract_collapse_prog - assists gnu_parallelize */
  /***********************************************************/
  cap prog drop extract_collapse_prog
  prog def extract_collapse_prog
  {

    /* only need the program name (anything) and the location (string) */
    syntax anything, progloc(string) randnum(string)

    qui {

      /* step 1 - get the line number in the do file that corresponds with
      the start of the program. save to a temp file - not sure if there is
      another way to get stdout into a stata macro */
      !grep -n "cap prog drop `anything'" `progloc' | sed 's/^\([0-9]\+\):.*$/\1/'  | tee $tmp/linenums_`randnum'.txt

      /* step 2 - same for the end of the program. add a new line to the file */
      !grep -n "END program `anything'" `progloc' | sed 's/^\([0-9]\+\):.*$/\1/' >> $tmp/linenums_`randnum'.txt

      /* get the line nums into macros */
      file open lines_file using $tmp/linenums_`randnum'.txt, read
      file read lines_file line
      local first_line `line'
      file read lines_file line
      local last_line `line'
      local last_line_plus_1 = `last_line' + 1
      file close lines_file

      /* step 4 - extract the section of the do file between those line
      nums and save to $tmp/tmp_prog_extracted.do */
      !sed -n '`first_line',`last_line'p;`last_line_plus_1'q' `progloc' > $tmp/tmp_prog_extracted_`randnum'.do

      /* remove the temp file */
      !rm $tmp/linenums_`randnum'.txt
    }
  }
  end
  /* *********** END program extract_collapse_prog ***************************************** */


  /******************************************************************/
  /* program prep_gnu_parallel_input_file - assists gnu_parallelize */
  /******************************************************************/
  cap prog drop prep_gnu_parallel_input_file
  prog def prep_gnu_parallel_input_file
  {

    /* we just need the output file name, and the list to be split into separate lines */
    syntax anything, in(string)

    /* open the output file for writing to */
    file open output_file using `anything', write replace

    /* tokenize the input var */
    tokenize `in'

    /* loop over all the individual inputs and write to a new line */
    while "`*'" != "" {
      file write output_file "`1'" _n
      macro shift
    }

    /* close the file handle */
    file close output_file

    /* print an output message */
    disp _n "input file for gnu_parallelize written to `anything'"
  }
  end
  /* *********** END program prep_gnu_parallel_input_file ***************************************** */


  /***************************************************/
  /* clean_package: get rid of junk in package codes */
  /***************************************************/
  cap prog drop clean_package
  prog def clean_package
  {
    syntax varlist(min=1 max=1)
    tokenize `varlist'
    replace `1' = upper(subinstr(`1', "-", "", .))
    replace `1' = upper(subinstr(`1', " ", "", .))
    replace `1' = upper(subinstr(`1', "(", "", .))
    replace `1' = upper(subinstr(`1', ")", "", .))
    replace `1' = upper(subinstr(`1', "/", "", .))
  }
  end
  /* *********** END program clean_package ***************************************** */


  /****************************************************************/
  /* clean_road_name: lowercase, trim and - <-> TO for road names */
  /****************************************************************/
  cap prog drop clean_road_name
  prog def clean_road_name
  {
    syntax varlist(min=1 max=1), Generate(name)
    tokenize `varlist'

    gen `generate' = `1'
    
    replace `generate' = subinstr(`generate', " - ", " to ", .)
    replace `generate' = subinstr(`generate', " ", "", .)
    replace `generate' = subinstr(`generate', "_", "", .)
    replace `generate' = trim(lower(`generate'))
    replace `generate' = subinstr(`generate', ".", "", .)
    replace `generate' = "" if `generate' == "-"
  }
  end
  /* *********** END program clean_road_name ***************************************** */


  /************************************************/
  /* parse_filename: regex-based file name parser */
  /************************************************/
  cap prog drop parse_filename
  prog def parse_filename
  {
    syntax varlist(min=1 max=1), Filename(name) State(name) District(name) [SUBdistrict(name)]
    tokenize `varlist'

    gen `filename' = regexs(1) if regexm(`1', "^([A-z0-9]+)([A-Z][A-Z])_([0-9]+)(_([A-z0-9_.()-]+))?\.html")
    
    gen `state' = regexs(2) if regexm(`1', "^([A-z0-9]+)([A-Z][A-Z])_([0-9]+)(_([A-z0-9_.()-]+))?\.html")
    
    gen `district' = regexs(3) if regexm(`1', "^([A-z0-9]+)([A-Z][A-Z])_([0-9]+)(_([A-z0-9_.()-]+))?\.html")
    
    if "`subdistrict'" != "" {
      gen `subdistrict' = regexs(5)  if regexm(`1', "^([A-z0-9]+)([A-Z][A-Z])_([0-9]+)(_([A-z0-9_.()-]+))?\.html")
    }
  }
  end
  /* *********** END program clean_road_name ***************************************** */


  /************************************************/
  /* clean_hab_name: minor trimming of habitation */
  /************************************************/
  cap prog drop clean_hab_name
  prog def clean_hab_name
  {
    syntax varlist(min=1 max=1)
    tokenize `varlist'
    
    replace `1' = subinstr(`1', " ", "", .)
    replace `1' = trim(lower(`1'))
  }
  end
  /* *********** END program clean_hab_name ***************************************** */


  /*******************************************/
  /* merge_sub_table: merge on $tmp/subtable */
  /*******************************************/
  cap prog drop merge_sub_table
  prog def merge_sub_table
  {
    syntax varlist(min=1 max=1)
    tokenize `varlist'

    /* replace dashes with missing */
    replace `1' = "" if `1' == "-"
    ren `1' unique_id

    /* replace missing observations with unique strings so can use 1:m merge */
    gen row_number = _n
    replace unique_id = "__SUBTABLE__" + string(row_number) if mi(unique_id)
    
    merge 1:m unique_id using $tmp/subtables

    /* drop subtable entries that match a different column in the master sheet */
    drop if _merge == 2
    drop _merge
    
    /* clean up */
    replace unique_id = "" if strpos(unique_id, "__SUBTABLE__")
    ren unique_id `1'
    drop row_number
  }
  end
  /* *********** END program merge_sub_table ***************************************** */


  /*********************************************************/
  /* program rd_pmgsy_old : More general rd graph function */
  /*********************************************************/
  cap prog drop rd_pmgsy_old
  prog def rd_pmgsy_old
  {
    syntax varlist(min=1 max=1), Xvar(varname) [name(string) title(string) BIns(real 100) MSize(string) YLabel(string) NODRAW NOLINES SLOW]

    /* 3 way rd graph, hard coding x-variables as r04, r13 and r13b which is r13, without r04 values */
    tokenize `varlist'
    local yvar `1'

    if "`msize'" == "" {
      local msize tiny
    }

    if "`ylabel'" == "" {
      local ylabel ""
    }
    else {
      local ylabel "ylabel(`ylabel') "
    }
    
    if "`name'" == "" {
      local name `yvar'_rd
    }

    foreach i in rank x_index bin_r13_mean bin_r04_mean bin_13b_mean bin_*mean rd_tag {
      cap drop `i'
    }

    /* GOAL: cut into `bins' equally sized groups. some groups will
             cross boundaries, just to keep this simple. */
    /* count the number of observations with margin and dependent var, to know how to cut into 100 */
    count
    local group_size = floor(`r(N)' / `bins')

    egen rank = rank(`xvar'), unique

    /* create indexes for N (# of bins) xvar groups of size `group_size' */
    gen x_index = .
    
    forval i = 1/`bins' {
      local cut_start = `i' * `group_size'
      local cut_end = (`i' + 1) * `group_size'

      qui replace x_index = `i' if inrange(rank, `cut_start', `cut_end')
    }

    /* generate mean x and values in each bin */
    bys x_index: egen bin_xmean = mean(`xvar')
    foreach i in r04 r13 r13b {
      bys x_index: egen bin_`i'_mean = mean(`i')
    }
    
    /* generate a tag to plot one observation per bin */
    egen rd_tag = tag(x_index)

    /* get the axis labels */
    local ytitle: var label `yvar'
    local xtitle: var label `xvar'
    
    /* fit polynomial regression to the full data, but draw the points at the mean of each bin */
    sort `xvar'
    
    /* lowess version */
    if "`nolines'" == "" {
      twoway ///
        (lowess r04 `xvar' if inrange(`xvar', 0, 250),    color(black) msymbol(i) xline(250, lwidth(vthin)) xline(500, lwidth(vthin)) xline(1000, lwidth(vthin)) ) ///
        (lowess r04 `xvar'      if inrange(`xvar', 250, 500),  color(black) msymbol(i) ) ///
        (lowess r04 `xvar'     if inrange(`xvar', 500, 1000), color(black) msymbol(i) ) ///
        (lowess r04 `xvar'     if inrange(`xvar', 1000, 2000), color(black) msymbol(i) ) ///
        (lowess r13 `xvar' if inrange(`xvar', 0, 250),    color(red) msymbol(i) ) ///
        (lowess r13 `xvar'      if inrange(`xvar', 250, 500),  color(red) msymbol(i) ) ///
        (lowess r13 `xvar'     if inrange(`xvar', 500, 1000), color(red) msymbol(i) ) ///
        (lowess r13 `xvar'     if inrange(`xvar', 1000, 2000), color(red) msymbol(i) ) ///
        (lowess r13b `xvar' if inrange(`xvar', 0, 250),    color(green) msymbol(i) ) ///
        (lowess r13b `xvar'      if inrange(`xvar', 250, 500),  color(green) msymbol(i) ) ///
        (lowess r13b `xvar'     if inrange(`xvar', 500, 1000), color(green) msymbol(i) ) ///
        (lowess r13b `xvar'     if inrange(`xvar', 1000, 2000), color(green) msymbol(i) ), ///
          `ylabel'  name(`name', replace)  `nodraw' title("`title' ") legend(order(1 "r04" 5 "r13" 9 "r13-r04"))
    }
    /* points version */
    else {
      twoway (scatter bin_r04_mean bin_xmean if rd_tag == 1 , color(black) xline(250, lwidth(vthin)) xline(500, lwidth(vthin)) xline(1000, lwidth(vthin)) msize(`msize') ) ///
        (scatter bin_r13_mean bin_xmean if rd_tag == 1 , color(red) xline(250, lwidth(vthin)) xline(500, lwidth(vthin)) xline(1000, lwidth(vthin)) msize(`msize') ) ///
          (scatter bin_r13b_mean bin_xmean if rd_tag == 1 , color(green) xline(250, lwidth(vthin)) xline(500, lwidth(vthin)) xline(1000, lwidth(vthin)) msize(`msize') ), ///
        `ylabel'  name(`name', replace) legend() xtitle("`xtitle'") ytitle("`ytitle'") `nodraw' title("`title' ")
    }    

  }
  end
  /* *********** END program rd_pmgsy_old ***************************************** */


  /*****************************************************/
  /* program rd_pmgsy : More general rd graph function */
  /*****************************************************/
  cap prog drop rd_pmgsy
  prog def rd_pmgsy
  {
    syntax varlist(min=1 max=1) [if/], Xvar(varname) [name(string) title(string) BIns(real 100) MSize(string) YLabel(string) NODRAW NOLINES SLOW BINSIZE(real 0) EXPORT(string)] 

    tokenize `varlist'
    local yvar `1'

    if "`if'" != "" {
      preserve
      keep if `if'
    }
    
    if "`msize'" == "" {
      local msize tiny
    }

    if "`ylabel'" == "" {
      local ylabel ""
    }
    else {
      local ylabel "ylabel(`ylabel') "
    }
    
    if "`name'" == "" {
      local name `yvar'_rd
    }

    foreach i in rank x_index bin_*mean rd_tag {
      cap drop `i'
    }

    /* if binsize parameter passed in, use bins of specified size beginning at zero */
    if `binsize' != 0 {
      egen x_index = cut(`xvar'), at(0(`binsize')2000), 
    }
    /* GOAL: cut into `bins' equally sized groups. some groups will
             cross boundaries, just to keep this simple. */
    /* count the number of observations with margin and dependent var, to know how to cut into 100 */
    else {
      count
      local group_size = floor(`r(N)' / `bins')
      
      egen rank = rank(`xvar'), unique
      
      /* create indexes for N (# of bins) xvar groups of size `group_size' */
      gen x_index = .
      
      forval i = 1/`bins' {
        local cut_start = `i' * `group_size'
        local cut_end = (`i' + 1) * `group_size'
        
        qui replace x_index = `i' if inrange(rank, `cut_start', `cut_end')
      }
    }
    
    /* generate mean x and values in each bin */
    bys x_index: egen bin_xmean = mean(`xvar')

    /* generate mean y value in each bin */
    bys x_index: egen bin_`yvar'_mean = mean(`yvar')
    // foreach i in `xvar' {
    //   bys x_index: egen bin_`i'_mean = mean(`i')
    // }
    
    /* generate a tag to plot one observation per bin */
    egen rd_tag = tag(x_index)

    /* get the axis labels */
    local ytitle: var label `yvar'
    local xtitle: var label `xvar'
    
    /* fit polynomial regression to the full data, but draw the points at the mean of each bin */
    sort `xvar'

    /* lowess version */
    if "`nolines'" == "" {
      twoway ///
        (lowess `yvar' `xvar' if inrange(`xvar', 0, 250),    color(black) msymbol(i) xline(250, lwidth(vthin)) xline(500, lwidth(vthin)) xline(1000, lwidth(vthin)) ) ///
        (lowess `yvar' `xvar' if inrange(`xvar', 250, 500),  color(black) msymbol(i) ) ///
        (lowess `yvar' `xvar' if inrange(`xvar', 500, 1000), color(black) msymbol(i) ) ///
        (lowess `yvar' `xvar' if inrange(`xvar', 1000, 2000), color(black) msymbol(i) ), ///
          `ylabel'  name(`name', replace)  `nodraw' title("`title' ") legend(off)
    }
    /* points version */
    else {
      twoway (scatter bin_`yvar'_mean bin_xmean if rd_tag == 1, ///
              color(black) xline(250, lwidth(vthin)) xline(500, lwidth(vthin)) ///
              xline(1000, lwidth(vthin)) msize(`msize') ), ///
              `ylabel'  name(`name', replace) legend() xtitle("`xtitle'") ///
              ytitle("`ytitle'") `nodraw' title("`title' "), ///
              if `xvar' < 2000
    }

    if !mi("`export'") {

      graph export "`export'.eps", replace
      shell epstopdf `export'.eps
      erase `export'.eps
    }
    if "`if'" != "" {
      restore
    }

  }
  end
  /* *********** END program rd_pmgsy ***************************************** */


  /**********************************************/
  /* program lincom_write : write est and stars */
  /**********************************************/
  cap prog drop lincom_write
  prog def lincom_write
  {
    syntax, pop(string) measure(string) state(string) [n(real 0)]
    local e = r(estimate)
    local t = r(estimate) / r(se)
    local star = ""
    if `t' > 2.3 {
      local star = "***"
    }
    else if `t' > 1.96 {
      local star = "**"
    }
    else if `t' > 1.65 {
      local star = "*"
    }

    di %3s "`state'" %5s "`pop'" %3s "`measure'" %8.3f `e' " (" %4.2f `t' %5s ")`star'" "[`n']"

  }
  end
  /* *********** END program lincom_write ***************************************** */


  /*****************************************************/
  /* program probit_test : see prog comments for usage */
  /*****************************************************/
  cap prog drop probit_test
  prog def probit_test
  {

    /* for easy syntax, pass parameters in globals */
    //  $sample, $fe, $controls, $inrange, $pop_controls, $rank, $yvar
    // weight restricted to zero for probit
    // switchvar(varname) needs to be zero/one, or omitted for full sample probit
    // verbose shows full 1st stage and 2nd stage results
      syntax, [switchvar(varname) verbose]
    
    if mi("`verbose'") {
      local qui qui
    }

    /* verify globals are set */
    foreach i in sample fe controls inrange pop_controls rank yvar {
      if mi("$`i'") {
        di as error "probit_test FAIL: NEED TO SET `i' GLOBAL VARIABLE"
        exit 111
      }
    }
    
    if !mi("`switchvar'") {
      
      /* heterogeneity test here */
      /* run first stage separately for each reg. could argue for a joint first stage as well */
      /* SWITCHVAR == 0 */
      foreach switch in 0 1 {
        `qui' di "probit vr05 $rank base_y $controls $pop_controls $fe if `switchvar' == `switch' & vtag & dr05count & !bad98 & !bad05 & !bad_pop & sample_$sample & $inrange, vce(robust)"
        `qui' probit vr05 $rank base_y $controls $pop_controls $fe if `switchvar' == `switch' & vtag & dr05count & !bad98 & !bad05 & !bad_pop & sample_$sample & $inrange, vce(robust)
        qui test $rank = 0
        di "PROBIT FIRST STAGE (`switchvar' == `switch', untransformed b, se, p): " %7.3f _b[$rank] %7.2f _se[$rank] %5.2f `r(p)'
        
        /* probit second stage  */

        /* set vr05 to predict variable to keep estout consistent */
        tempvar old_vr05
        ren vr05 `old_vr05' 
        qui predict vr05
        label var vr05 "New road"
        `qui' di "reg $yvar vr05 base_y $controls $pop_controls $fe if `switchvar' == `switch' & vtag & dr05count & !bad98 & !bad05 & !bad_pop & sample_$sample & $inrange, vce(robust)"
        `qui' eststo: reg $yvar vr05 base_y $controls $pop_controls $fe if `switchvar' == `switch' & vtag & dr05count & !bad98 & !bad05 & !bad_pop & sample_$sample & $inrange, vce(robust)
        local b = _b["vr05"]
        local se = _se["vr05"]
        qui count if e(sample)
        local N `r(N)'
        qui test vr05 = 0
        drop vr05
        ren `old_vr05' vr05
        
        di  "`switchvar' == `switch': b, se, p, N: " %6.2f `b' %6.2f `se' %6.2f `r(p)' %7.0f `N'
      }
    }

    /* full sample probit here */
    else {
      
      /* probit first stage */
      `qui' di "probit vr05 $rank base_y $controls $pop_controls $fe if vtag & dr05count & !bad98 & !bad05 & !bad_pop & sample_$sample & $inrange, vce(robust)"
      `qui' probit vr05 $rank base_y $controls $pop_controls $fe if vtag & dr05count & !bad98 & !bad05 & !bad_pop & sample_$sample & $inrange, vce(robust)
      qui test $rank = 0
      di "PROBIT FIRST STAGE (untransformed b, se, p): " %7.3f _b[$rank] %7.2f _se[$rank] %5.2f `r(p)'

      /* probit second stage  */
      tempvar old_vr05
      ren vr05 `old_vr05'
      qui predict vr05
      `qui' di "reg $yvar vr05 base_y $controls $pop_controls $fe if vtag & dr05count & !bad98 & !bad05 & !bad_pop & sample_$sample & $inrange, vce(robust)"
      `qui' eststo: reg $yvar vr05 base_y $controls $pop_controls $fe if vtag & dr05count & !bad98 & !bad05 & !bad_pop & sample_$sample & $inrange, vce(robust)
      local b = _b["vr05"]
      local se = _se["vr05"]
      qui count if e(sample)
      local N = `r(N)'
      qui test vr05 = 0
      drop vr05
      ren `old_vr05' vr05

      di  "b, se, p, N: " %6.2f `b' %6.2f `se' %6.2f `r(p)' %7.0f `N'
    }
  }
  end
  /* *********** END program probit_test ***************************************** */


  /*******************************************************************************/
  /* program merge_cycle : exact merge over a series of different variable lists */
  /*******************************************************************************/

  /* NOTE: assumes that all subsequent merges are using subset of vars from first merge */
  cap prog drop merge_cycle
  prog def merge_cycle
  {
    syntax, master_pref(string) using_pref(string) path1(string) path2(string) master(string) using(string) list1(string) [list2(string) list3(string) list4(string) list5(string)]

    use `path1'/`master', clear

    /* generate merge vars, with strings cleaned up */
    foreach var in `list1' {
      gen `var' = `master_pref'_`var'
      cap replace `var' = lower(trim(`var'))
      cap replace `var' = subinstr(`var', " ", "", .)
      cap replace `var' = subinstr(`var', "/", "", .)
      cap replace `var' = subinstr(`var', "-", "", .)
      cap replace `var' = subinstr(`var', "(", "", .)
      cap replace `var' = subinstr(`var', ")", "", .)
    }

    /* drop duplicates */
    duplicates drop `list1', force

    /* save file for merge 1 */
    save `path2'/`master'_fm1, replace

    /* using file */
    use `path1'/`using', clear

    /* generate merge vars, with strings cleaned up */
    foreach var in `list1' {
      gen `var' = `using_pref'_`var'
      cap replace `var' = lower(trim(`var'))
      cap replace `var' = subinstr(`var', " ", "", .)
      cap replace `var' = subinstr(`var', "/", "", .)
      cap replace `var' = subinstr(`var', "-", "", .)
      cap replace `var' = subinstr(`var', "(", "", .)
      cap replace `var' = subinstr(`var', ")", "", .)
    }

    /* drop duplicates */
    duplicates drop `list1', force

    /* save file for merge 1 */
    save `path2'/`using'_fm1, replace

    /* merge 1 */
    use `path2'/`master'_fm1, clear
    merge 1:1 `list1' using `path2'/`using'_fm1, gen(_m_`using_pref')

    /* save good match */
    preserve
    keep if _m_`using_pref' == 3
    gen matchround_`using_pref' = 1
    save `path2'/`master'_`using'_match1, replace
    restore

    /* save unmatched master */
    preserve
    keep if _m_`using_pref' == 1
    keep `master_pref'_* `list1'
    save `path2'/`master'_unmatched1, replace
    restore

    /* save unmatched using */
    preserve
    keep if _m_`using_pref' == 2
    keep `using_pref'_* `list1'
    save `path2'/`using'_unmatched1, replace
    restore

    /* repeat for later rounds, using just that which is left */
    foreach num in 2 3 4 5 {

      if !mi("`list`num''") {

        local last = `num' - 1

        /* prep master */
        use `path2'/`master'_unmatched`last', clear
        duplicates drop `list`num'', force
        save `path2'/`master'_fm`num', replace

        /* prep using */
        use `path2'/`using'_unmatched`last', clear
        duplicates drop `list`num'', force
        save `path2'/`using'_fm`num', replace

        /* merge */
        use `path2'/`master'_fm`num', clear
        merge 1:1 `list`num'' using `path2'/`using'_fm`num', gen(_m_`using_pref')

        /* save good match */
        preserve
        keep if _m_`using_pref' == 3
        gen matchround_`using_pref' = `num'
        save `path2'/`master'_`using'_match`num', replace
        restore

        /* save unmatched master */
        preserve
        keep if _m_`using_pref' == 1
        keep `master_pref'_* `list1'
        save `path2'/`master'_unmatched`num', replace
        restore
        
        /* save unmatched using */
        preserve
        keep if _m_`using_pref' == 2
        keep `using_pref'_* `list1'
        save `path2'/`using'_unmatched`num', replace
        restore

      }
    }

    /* append and then save */
    use `path2'/`master'_`using'_match1, clear
    if !mi("`list2'") append using `path2'/`master'_`using'_match2
    if !mi("`list3'") append using `path2'/`master'_`using'_match3
    if !mi("`list4'") append using `path2'/`master'_`using'_match4
    if !mi("`list5'") append using `path2'/`master'_`using'_match5
    save `path2'/`master'_`using'_merge, replace

  }
  end
  /* *********** END program merge_cycle ***************************************** */


  /***********************************************************/
  /* program get_state_names : merge in statenames using ids */
  /***********************************************************/
  /* get state names ( y(91) if want 1991 ids ) */
  cap prog drop get_state_names
  prog def get_state_names
  {
    syntax , [Year(string)]

    /* default is 2001 */
    if mi("`year'") {
      local year 01
    }

    /* merge to the state key on state id */
    merge m:1 pc`year'_state_id using $keys/pc`year'_state_key, gen(_gsn_merge) keepusing(pc`year'_state_name) update replace

    /* display state ids that did not match the key */
    di "These ids were not found in the key: "
    cap noi table pc`year'_state_id if _gsn_merge == 1

    /* drop places that were only in the key */
    di _n "Dropping states only in the key, not in master data..."
    drop if _gsn_merge == 2
    drop _gsn_merge
  }
  end


  /*********************************************************************/
  /* program masala_merge2 : Fuzzy match using masalafied levenshtein  */
  /*********************************************************************/
  cap prog drop masala_merge2
  prog def masala_merge2
  {

    /* NOTE THAT THE DIST() PARAMETER IS FOR BACKWARD COMPATIBILITY AND IS NOT USED. */
    syntax [varlist] using/, S1(string) OUTfile(string) [DIST(real 0) FUZZINESS(real 1.0) quietly KEEPUSING(passthru) SORTWORDS] 

    // masala_merge2 state_id district_id using /tmp/pn/foo.dta, S1(village_name) OUTfile(string) [DIST(integer 5)]

    /* require tmp and masala_dir folders to be set */
    if mi("$tmp") | mi("$MASALA_DIR") {
        disp as error "Need to set globals 'tmp' and 'MASALA_DIR' to use this program"
        exit
    }

    /* store sort words parameter */
    if !mi("`sortwords'") {
      local sortwords "-s"
    }
    
    /* define maximum distance for lev.py as 0.4 + 1.25 * (largest acceptable match).
       This is the threshold limit, i.e. if we accept a match at 2.1, we'll reject it
          if there's another match at 0.4 + 2.1*1.25. (this is hardcoded below)
       (then i switched it from 0.4 to 0.35 so default max dist is 3 and not higher */
    local max_dist = 0.40 + 1.25 * 2.1 * `fuzziness'
    
    /* make everything quiet until python gets called -- it's not helpful */
    qui {

      /* create temporary file to store original dataset */
      tempfile master
      save `master', replace

      /* create a random 5-6 digit number to make the temp files unique */
      local time = real(subinstr(`"`c(current_time)'"', ":", "", .))
      local nonce = floor(`time' * runiform() + 1)
      
      local src1 $tmp/src1_`nonce'.txt
      local src2 $tmp/src2_`nonce'.txt
      local out $tmp/out_`nonce'.txt
      local lev_groups $tmp/lev_groups_`nonce'.dta
      
      preserve
      
      keep `varlist' `s1'
      sort `varlist' `s1'
      
      /* merge two datasets on ids to produce group names */
      merge m:m `varlist' using `using', keepusing(`varlist' `s1')
      
      // generate id groups
      egen g = group(`varlist')
      drop if mi(g)
      
      qui sum g
      local num_groups = r(max)
              
      // save group list
      keep g `varlist'
      duplicates drop
      save "`lev_groups'", replace
      
      /* now prepare group 1 */
      restore
      preserve
      
      keep `varlist' `s1'
    
      /* drop if missing string and store # observations */
      keep if !mi(`s1')
      qui count
      local g1_count = r(N)
      
      /* bring in group identifiers */
      merge m:1 `varlist' using "`lev_groups'", keepusing(g)
    
      /* places with missing ids won't match group */
      drop if _merge == 1
    
      /* only keep matches */
      keep if _merge == 3
      duplicates drop
      
      // outsheet string group 1
      outsheet g `s1' using "`src1'", comma replace nonames
      
      // prepare group2
      di "opening `using'..."
      use `using', clear
      keep `varlist' `s1'

      /* confirm no duplicates on this side */
      tempvar dup
      duplicates tag `varlist' `s1', gen(`dup')
      count if `dup' > 0
      if `r(N)' > 0 {
        display as error "`varlist' `s1' not unique on using side"
        exit 123
      }
      drop `dup'
      
      /* drop if missing string and store # observations */
      keep if !mi(`s1')
      qui count
      local g2_count = r(N)
      
      // merge in group identifiers
      merge m:1 `varlist' using "`lev_groups'", keepusing(g)
      
      /* something wrong if didn't match group ids for any observation */
      drop if _merge == 1
    
      /* only keep matches */
      keep if _merge == 3
      duplicates drop
      
      // outsheet string group 2
      outsheet g `s1' using "`src2'", comma replace nonames
    }
    
    // call python levenshtein program
    di "Matching `g1_count' strings to `g2_count' strings in `num_groups' groups."
    di "Calling lev.py:"

    di `" shell python -u $MASALA_DIR/lev.py -d `max_dist' -1 "`src1'" -2 "`src2'" -o "`out'" `sortwords'"'
    !python               $MASALA_DIR/lev.py -d `max_dist' -1 "`src1'" -2 "`src2'" -o "`out'" `sortwords'

    di "lev.py finished."

    /* quietly process the python output */
    qui {
      /* open output lev dataset */
      /* take care, this generates an error if zero matches */
      capture insheet using "`out'", comma nonames clear
    
      /* if there are zero matches, create an empty outfile and we're done */
      if _rc {
        disp_nice "WARNING: masala_merge2: There were no matches. Empty output file will be saved."
        clear
        save `outfile', replace emptyok
        exit
      }
      ren v1 g
      ren v2 `s1'_master
      ren v3 `s1'_using
      ren v4 lev_dist
    
      /* merge group identifiers back in */
      destring g, replace
      merge m:1 g using "`lev_groups'", keepusing(`varlist')
      
      /* _m == 1 would imply that our match list has groups not in the initial set */
      assert _merge != 1
    
      /* _m == 2 are groups with zero matches. drop them */
      drop if _merge == 2
    
      /* count specificity of each match */
      bys g `s1'_master: egen master_matches = count(g)
      bys g `s1'_using: egen using_matches = count(g)
    
      /* count distance to second best match */
    
      /* calculate best match for each var */
      foreach v in master using {
        bys g `s1'_`v': egen `v'_dist_rank = rank(lev_dist), unique
        
        gen tmp = lev_dist if `v'_dist_rank == 1
        bys g `s1'_`v': egen `v'_dist_best = max(tmp)
        drop tmp
        gen tmp = lev_dist if `v'_dist_rank == 2
        bys g `s1'_`v': egen `v'_dist_second = max(tmp)
        drop tmp
        
        drop `v'_dist_rank
      }
      
      drop g _m
    
      /* apply optimal matching rule (from 1991-2001 pop census confirmed village matches in calibrate_fuzzy.do) */
      /* initialize */
      gen keep_master = 1
      gen keep_using = 1
    
      /* get mean length of matched string */
      gen length = floor(0.5 * (length(`s1'_master) + length(`s1'_using)))
    
      /* 1. drop matches with too high a levenshtein distance (threshold is a function of length) */
      replace keep_master = 0 if lev_dist > (0.9 * `fuzziness') & length <= 4
      replace keep_master = 0 if lev_dist > (1.0 * `fuzziness') & length <= 5
      replace keep_master = 0 if lev_dist > (1.3 * `fuzziness') & length <= 8
      replace keep_master = 0 if lev_dist > (1.4 * `fuzziness') & inrange(length, 9, 14)
      replace keep_master = 0 if lev_dist > (1.8 * `fuzziness') & inrange(length, 15, 17)
      replace keep_master = 0 if lev_dist > (2.1 * `fuzziness')
      
      /* copy these thresholds to keep_using */
      replace keep_using = 0 if keep_master == 0
    
      /* 2. never use a match that is not the best match */
      replace keep_master = 0 if (lev_dist > master_dist_best) & !mi(lev_dist)
      replace keep_using = 0 if (lev_dist > using_dist_best) & !mi(lev_dist)
      
      /* 3. apply best empirical safety margin rule */
      replace keep_master = 0 if (master_dist_second - master_dist_best) < (0.4 + 0.25 * lev_dist)
      replace keep_using = 0 if (using_dist_second - using_dist_best) < (0.4 + 0.25 * lev_dist)
    
      /* save over output file */
      order `varlist' `s1'_master `s1'_using lev_dist keep_master keep_using master_* using_*
      save `outfile', replace
    }
    restore

    /* run masala_review */
    use `outfile', clear
    
    /* if quietly is not specified, use masala_review */
    if mi("`quietly'") {
      masala_review `varlist', s1(`s1') master(`master') using(`using')
    }

    /* if quietly was specified, use masala_process */
    else {
      masala_process `varlist', s1(`s1') master(`master') using(`using')
    }
    
    di "Masala merge complete."
    di " Original master file was saved here:   `master'"
    di " Complete set of fuzzy matches is here: `outfile'"
  }
  end
  /* *********** END program masala_merge2 ***************************************** */


  /**********************************************************************************/
  /* program masala_review : Reviews masala_merge results and calls masala_process  */
  /***********************************************************************************/
  cap prog drop masala_review
  prog def masala_review
  {
    syntax varlist, s1(string) master(string) using(string) [keepusing(passthru)]

    /* ensure a masala merge output file is open */
    cap confirm var keep_master
    if _rc {
      di "You must open the masala_merge output file before running this program."
    }
    
    /* count and report matches that are exact, but with alternatives */
    /* these are places where keep_master == 0 & lev_dist == 0 */
    qui bys `s1'_master: egen _min_dist = min(lev_dist)
    qui bys `s1'_master: egen _max_keep = max(keep_master)

    qui count if _max_keep == 0 & _min_dist == 0
    if `r(N)' > 0 {
      di "+-------------------------------------" _n "| These are exact matches, where alternate good matches exist." _n ///
        "| keep_master is 0, but masala_process() will keep the observations with lev_dist == 0." _n ///
          "+-------------------------------------" 
      list `varlist' `s1'* lev_dist if _max_keep == 0 & _min_dist == 0
    }
    qui drop _max_keep _min_dist

    /* visually review places with high lev_dist that script kept -- they look good. */
    qui count if keep_master == 1 & lev_dist > 1
    if `r(N)' > 1 {
      disp_nice "These are high cost matches, with no good alternatives. keep_master is 1."
      list `varlist' `s1'* lev_dist if keep_master == 1 & lev_dist > 1
    }

    /* run masala_process, and then show the unmatched places */
    masala_process `varlist', s1(`s1') master(`master') using(`using') `keepusing'

    /* tag each name so it doesn't appear more than once */
    qui egen _ntag = tag(`varlist' `s1')

    /* list unmatched places in a nice order */
    qui gen _matched = _masala_merge == 3
    gsort _matched -_ntag `varlist' `s1'

    /* ensure we don't trigger obs. nos. out of range in final list, by counting observations */
    qui count
    if `r(N)' < 200 {
      local limit `r(N)'
    }
    else {
      local limit 200
    }

    /* list unmatched places */
    qui count if _masala_merge < 3 & _ntag in 1/`limit'
    if `r(N)' {
      disp_nice "This is a sorted list of some places that did not match. Review for ideas on how to improve"
      // list `varlist' `s1' _masala_merge if _masala_merge < 3 & _ntag in 1/`limit', sepby(`varlist')
    }

    drop _ntag _matched
  }
  end
  /* *********** END program masala_review ***************************************** */

  /**********************************************************************************/
  /* program masala_process : Rejoins the initial files in a masala_merge           */
  /**********************************************************************************/
  cap prog drop masala_process
  prog def masala_process
  {
    syntax varlist, s1(string) master(string) using(string) [keepusing(passthru)]

    qui {
      /* override keep_master if lev_dist is zero. */
      replace keep_master = 1 if lev_dist == 0
      
      /* keep highly reliable matches only */
      keep if keep_master == 1
    
      /* drop all masala merge's variables */
      keep `varlist' `s1'*

      /* bring back master dataset */
      gen `s1' = `s1'_master
      merge 1:m `varlist' `s1' using `master', gen(_masala_master)

      /* fill in master fuzzy-string from unmatched data on master side */
      replace `s1'_master = `s1' if mi(`s1'_master)
      drop `s1'
      
      /* bring back using dataset */
      gen `s1' = `s1'_using
    
      merge m:1 `varlist' `s1' using `using', `keepusing' gen(_masala_using)

      /* fill in using fuzzy-string from unmatched data on using side  */
      replace `s1'_using = `s1' if mi(`s1'_using)
      drop `s1'
      
      /* set `s1' to the master value */
      ren `s1'_master `s1'
      
      /* fill in using values when _m == 2 */
      replace `s1' = `s1'_using if mi(`s1')
    }

    /* Assertion: if we couldn't match back to the using, it must be unmatched from the master side */
    assert _masala_master == 2 if _masala_using == 1

    /* show merge result */
    disp_nice "Results of masala_merge (counting unique strings only): "
    
    /* tag each name so it doesn't appear more than once */
    qui egen ntag = tag(`varlist' `s1')

    /* create a standard merge output variable */
    qui gen _masala_merge = 1 if _masala_master == 2
    qui replace _masala_merge = 2 if _masala_using == 2
    qui replace _masala_merge = 3 if _masala_using == 3 & _masala_master == 3
    drop _masala_master _masala_using
    label values _masala_merge _merge

    /* show results */
    table _masala_merge if ntag
    qui drop ntag
  }
  end
  /* *********** END program masala_process ***************************************** */


  /**********************************************************************************/
  /* program flag_duplicates : Insert description here */
  /***********************************************************************************/
  cap prog drop flag_duplicates
  prog def flag_duplicates
  {
    /* I. TAG DUPLICATES */

    /* drop duplicates in terms of all variables - there should be none for this dataset */
    /* but there may be some in case the same observation was listed twice in separate districts */
    //duplicates drop

    /* need destring command here - destring was run when appending all district files */
    destring house_no, replace

    /* generate id variable that drops first two digits of mord_hh_id */
    gen newid = substr(mord_hh_id, 3, .)

    /* extract house number from mord_id and destring to allow for comparison with house_no */
    gen mord_hh_no = substr(mord_hh_id, 24, .)
    destring mord_hh_no, replace force

    /* flag if house_no in mord_id is different from house_no that is given */
    gen dif_hh_no = 1 if mord_hh_no != house_no

    /* 1. drop duplicates in terms of all variables except for mord id */
    /* these are cases where it is suspected that new members were added */
    /* these observations will share values for statecode - kisan_cc + newid */

    /* tag duplicates in terms of all variables except for mord_id */
    duplicates tag statecode - kisan_cc, gen(dup_all)
    replace dup_all = . if dup_all == 0

    /* tag one observation per statecode - kisan_cc group */
    egen tag = tag(statecode-kisan_cc) if dif_hh_no != 1

    /* gen flag for first stage drop */
    gen first_drop = 1 if dup_all != . & tag != 1

    /* 2. drop duplicates where household number as given in mord id does not match value for house_no variable */
    /* having tracked these households back to draftlist / finallist csvs, only the household where mord id house_no */
    /* matched given house_no shared characteristics with the draft/final csvs */
    /* this rule applies to values that have duplicates both in terms of mord id and in terms of the given identifiers */

    /* tag duplicates in terms of given identifiers - location + house_no + sn*/
    duplicates tag statecode - house_no, gen(dup_ids)
    replace dup_ids = . if dup_ids == 0

    /* make sure households that already have observations dropped are not flagged again, which would cause */
    /* all observations from a household to be dropped from the dataset */
    bysort statecode - house_no : egen drop_count = count(first_drop)
    bysort statecode - house_no : replace dup_ids = . if drop_count == dup_all
    drop drop_count

    /* tag one observation per location identifier + house_no + sn group */
    egen tag2 = tag(statecode-house_no)

    /* tag duplicates in terms of mord id */
    duplicates tag mord_hh_id, gen(dup_mordid)
    replace dup_mordid = . if dup_mordid == 0

    /* gen flag for second stage drop */
    gen second_drop = 1 if (dup_ids != . | dup_mordid != .) & (dup_all == .) & (dif_hh_no == 1) & (first_drop != 1)

    /* 3. drop duplicates where households share mord id, but have different characteristics */
    /* these are also cases where it is suspected that new members were added */

    /* extract sn value from newly saved mord member id */
    gen memid = substr(mord_member_id, 27, 29)

    /* by each trimmed mord hh id group (household), calculate and save maximum value of sn, effectively */
    /* tagging the household row we want to keep */
    destring memid, replace force
    bysort newid : egen maxmemid = max(memid)

    /* gen flag for third stage drop */
    gen third_drop = 1 if (dup_ids != .) & (memid != maxmemid) & (first_drop != 1) & (second_drop != 1)

    /* 4. ddrop any remaining duplicates in terms of newid */
    /* these are household where we do have two households that share both the given identifiers */
    /* and a trimmed mord_hh_id. I am not yet sure how to treat these households as it is not clear which one it is */
    /* we should be considering as valid. Tracing these back to the draftlist/finallist data may reveal some */
    /* information but the best case scenario would be if contacts at the MoRD can let us know if the first two digits */
    /* may somehow point us toward the valid observation */
    duplicates tag newid first_drop second_drop third_drop, gen(dup)
    gen fourth_drop = 1 if dup != 0 & first_drop != 1 & second_drop != 1 & third_drop != 1

    /* generate flag for observations to be dropped */
    gen flag_duplicates = 0 
    foreach var of varlist first_drop second_drop third_drop fourth_drop {
      replace flag_duplicates = 1 if `var'==1
    }

    /* label new flag variable */
    label var flag_duplicates "equals 1 if household is a duplicate that needs to be dropped"
    
    /* drop intermediate variables */
    drop newid mord_hh_no dif_hh_no dup_all tag first_drop dup_ids tag2 dup_mordid second_drop memid maxmemid third_drop dup fourth_drop
  }
  end
  /* *********** END program flag_duplicates ***************************************** */


  /*****************************************************************************/
  /* program masala_lev_dist : Calculate levenshtein distance between two vars */
  /*****************************************************************************/
  /* uses external python program */
  cap prog drop masala_lev_dist
  prog def masala_lev_dist
  {
    syntax varlist(min=2 max=2), GEN(name)
    tokenize `varlist'
    foreach i in _masala_word1 _masala_word2 _masala_dist __masala_merge {
      cap drop `i'
    }

    gen _masala_word1 = `1'
    gen _masala_word2 = `2'
    replace _masala_word1 = lower(trim(_masala_word1))
    replace _masala_word2 = lower(trim(_masala_word2))

    gen _row_number = _n
    
    /* create temporary file for python  */
    outsheet _row_number _masala_word1 _masala_word2 using $tmp/masala_in.csv, comma replace nonames

    /* call external python program */
    di "Calling lev.py..."
    shell python $MASALA_DIR/lev.py -1 $tmp/masala_in.csv -o $tmp/masala_out.csv

    /* convert created file to stata format */
    preserve
    insheet using $tmp/masala_out.csv, clear names
    save $tmp/masala_lev_dist, replace
    restore

    /* merge result with new dataset */
    merge 1:1 _row_number using $tmp/masala_lev_dist.dta, gen(__masala_merge) keepusing(_masala_dist)

    /* clean up */
    destring _masala_dist, replace
    ren _masala_dist `gen'
    drop _masala_word1 _masala_word2 _row_number
    
    assert __masala_merge == 3
    drop __masala_merge
  }
  end
  /* *********** END program masala_lev_dist ***************************************** */


  /**********************************************************************************/
  /* program capdrop : Drop a bunch of variables without errors if they don't exist */
  /**********************************************************************************/
  cap prog drop capdrop
  prog def capdrop
  {
    syntax anything
    foreach v in `anything' {
      cap drop `v'
    }
  }
  end
  /* *********** END program capdrop ***************************************** */


  /*************************************************************/
  /* program cons_boot : primary consumption bootstrap program */
  /*************************************************************/
  cap prog drop cons_boot
  prog def cons_boot
  {

    qui {

      /* define syntax */
      syntax, Spec(string) OUTfile(string) name(string) [NUM_bs(integer 1000) sumvar(string) REUSE_boot] 

      /* get the number of observations - we will do a full size bootstrap
      sample with replacement */
      d
      global bs_size = r(N)

      /* generate village bootstrap vars, and merge in to working data
      previously saved*/
      if mi("`reuse_boot'") {

        /* add an observation identifier */
        gen obsno = _n

        /* save temp file for village bootstrap vars to be added on to */
        cap rm $tmp/boot_tmp_frame_`name'
        save $tmp/boot_tmp_frame_`name', replace

        noi disp _n "generating village bootstrap 1 of `num_bs'"
        forval i = 1/`num_bs' {

          if mod(`i', 100) == 0 {
            noi disp "generating village bootstrap `i' of `num_bs'"
          }
          
          /* set the size of our sample */
          clear
          set obs $bs_size

          /* randomly sample (with replacement) based on our obsno variable */
          gen obsno = floor($bs_size*runiform()+1)

          /* generate a variable that counts the number of times each village
          appears in this bootstrap */
          gen vsample_`i' = 1

          /* collapse by village, to get accurate counts */
          collapse (sum) vsample_`i', by(obsno)
          
          /* save as temp file so we can merge the new bootstrap counts into
          our working data */
          save $tmp/pmgsy_vill_boot_tmp_`name', replace

          /* merge the bootstrap into our working data and save it */
          use $tmp/boot_tmp_frame_`name'
          merge 1:1 obsno using $tmp/pmgsy_vill_boot_tmp_`name', keepusing(vsample_`i') nogen
          gen weight_`i' = vsample_`i' * kernel_tri_ik
          save $tmp/boot_tmp_frame_`name', replace
        }
      }

      /* if 'reuse' was specified, let us know */
      else {
        noi disp _n "Reusing last village bootstrap calcs from $tmp/boot_tmp_frame_`name'"
        use $tmp/boot_tmp_frame_`name', clear
      }
      
      /* prepare our output CSV to save regressions results */
      cap rm `outfile'

      /* check if we want an extra summary stat: variable mean */
      if !mi("`sumvar'") {
        local sumvar_clean  : subinstr local sumvar "BOOTSTRAPNUM" ""
        append_to_file using `outfile', s("beta,se,p,n,bootstrap,r2,r2_a,n_tot,`sumvar_clean'_mean")
      }
      else {
        append_to_file using `outfile', s("beta,se,p,n_boot_unique,bootstrap,r2,r2_a,n_tot")
      }

      /* run the RD regressions */
      noi disp _n "running RD 1 of `num_bs' - `c(current_time)'"
      forval i = 1/`num_bs' {

        if mod(`i', 100) == 0 {
          noi disp "running RD `i' of `num_bs' - `c(current_time)'"
        }

        /* replace BOOTSTRAPNUM from the regression specification with
        `i', so the regression works properly */
        local spec_run  : subinstr local spec "BOOTSTRAPNUM" "`i'", all
        local sumvar  : subinstr local sumvar "BOOTSTRAPNUM" "`i'"
        
        /* save the total number of observations in the sample */
        /* not sure how to do this without running the regression twice,
        unfortunately. */
        `spec_run'
        total vsample_`i' if e(sample)
        /* store matrix which contains total sample that bootstrap was generated from */
        matrix temp_mat = e(b)
        /* save the value we want from this matrix */
        scalar temp_n = temp_mat[1,1]
        /* put it in a local before writing out */
        local temp_n_loc = temp_n
        
        /* run the RD and store the output to our intermediary csv,
        which will be further analyzed by store_est_tpl_boot */
        `spec_run'
        sum `sumvar' if e(sample) & t == 0

        /* if we are storing an additional characteristic, do so */
        if !mi("`sumvar'") {
          append_est_to_file using `outfile', b(r2012) s(`i',`e(r2)',`e(r2_a)',`temp_n_loc', `r(mean)')
        }
        /* if not, don't */
        if mi("`sumvar'") {
          append_est_to_file using `outfile', b(r2012) s(`i', `e(r2)',`e(r2_a)', `temp_n_loc')
        }      
      }
    }
  }
  end
  /* *********** END program cons_boot ***************************************** */


  /***************************************************************/
  /* program store_est_tpl__boot : consumption bootstrap tables  */
  /***************************************************************/
  cap prog drop store_est_tpl_boot
  prog def store_est_tpl_boot
  {

    /* note that this program only works with beta se and p, which are the
    outputs previously written by the cons_boot program. this program will
    store median, 95% CI, and se of the bootstrapped beta. */

    qui {

      /* define syntax */
      syntax using/, infile(string) name(string) [format(string) sumvar(string) sumvarformat(string)]

      /* save the data in memory */
      preserve

      /* read in the CSV output from the bootstrapped regressions */
      insheet using `infile', clear
      
      /* set default formats if not specified */
      if mi("`format'") local format "%6.3f"
      if mi("`sumvarformat'") local sumvarformat "%6.3f"

      /* summarize the betas so we can extract our target info*/
      noi sum beta, d

      /* correctly format our beta point estimate */
      local beta_median = `r(p50)'
      local b_formatted:  di `format' `beta_median'

      /* write beta to file */
      append_to_file using `using', s("`name'_beta, `b_formatted'")

      /* format se and write out */
      noi sum beta, d
      local se_formatted:  di `format' `r(sd)'
      append_to_file using `using', s("`name'_se, `se_formatted'")

      /* generate our 95% ci upper and lower bounds */
      local ub = `beta_median' + (`r(p50)' * 1.96)
      local ub_formatted:  di `format' `ub'
      local lb = `beta_median' - (`r(p50)' * 1.96)
      local lb_formatted:  di `format' `lb'

      /* write out upper and lower bounds */
      append_to_file using `using', s("`name'_ub_95ci, `ub_formatted'")
      append_to_file using `using', s("`name'_lb_95ci, `lb_formatted'")
      
      /* now r2 */
      noi sum r2, d
      local r2_formatted:  di %6.2f `r(p50)'
      append_to_file using `using', s("`name'_r2, `r2_formatted'")
      
      /* now total n, from which bootstrap sample was drawn */
      noi sum n_tot, d
      local n_tot_formatted:  di %6.0f `r(p50)'
      append_to_file using `using', s("`name'_n, `n_tot_formatted'")
      
      /* check if there is an additonal summary stat we need */
      if !mi("`sumvar'") {
        sum `sumvar', d
        local sumvar_formatted:  di `sumvarformat' `r(mean)'
        append_to_file using `using', s("`sumvar'_mean, `sumvar_formatted'")
      }
      
      /* restore back to our original data */
      restore
    }
  }
  end
  /* *********** END program store_est_tpl_boot ***************************************** */

  /**********************************************************************************/
  /* program dc_density : McCrary test */
  /***********************************************************************************/
  
  //Notes:
  //  This ado file was created by Brian Kovak, a Ph.D. student at the University
  //  of Michigan, under the direction of Justin McCrary.  McCrary made some
  //  cosmetic alterations to the code, added some further error traps, and
  //  ran some simulations to ensure that
  //  there was no glitch in implementation.  This file is not the basis for
  //  the estimates in McCrary (2008), however.
  
  //  The purpose of the file is to create a STATA command, -DCdensity-, which
  //  will allow for ready estimation of a discontinuous density function, as
  //  outlined in McCrary (2008), "Manipulation of the Running Variable in the
  //  Regression Discontinuity Design: A Density Test", Journal of Econometrics.
  
  //  The easiest way to use the file is to put it in your ado subdirectory.  If
  //  you don't know where that is, try using -sysdir- at the Stata prompt.
  
  //  A feature of the program is that it is much faster than older STATA routines
  //  (e.g., -kdensity-).  The source of the speed improvements is the use of
  //  MATA for both looping and for estimation of the regressions, and the lack of
  //  use of -preserve-.
  
  // An example program showing how to use -DCdensity- is given in the file
  // DCdensity_example.do
  
  // JRM, 9/2008
  
  // Update: Fixed bug that occurs when issuing something like
  // DCdensity Z if female==1, breakpoint(0) generate(Xj Yj r0 fhat se_fhat) graphname(DCdensity_example.eps)
  
  // Update 11.17.2009: Fixed bugs in XX matrix (see comments) and in hright (both code typos)
  
    
  capture program drop dc_density
  program dc_density, rclass
  {
    version 9.0
    set more off
    pause on
    syntax varname(numeric) [if/] [in/], breakpoint(real) GENerate(string) ///
      [ b(real 0) h(real 0) at(string) graphname(string) noGRaph xtitle(passthru) ytitle(passthru) title(passthru) subtitle(passthru) graphregion(passthru) xlabel(passthru) ylabel(passthru)]
    
    // drop variables from last run
    capdrop Xj Yj r0 fhat se_fhat
    
    marksample touse
    
    //Advanced user switch
    //0 - supress auxiliary output  1 - display aux output
    local verbose 1 
   
    //Bookkeeping before calling MATA function
    //"running variable" in terminology of McCrary (2008)
    local R "`varlist'"
  
    tokenize `generate'
    local wc : word count `generate' 
    if (`wc'!=5) {
      //generate(Xj Yj r0 fhat se_fhat) is suggested
      di "Specify names for five variables in generate option"
      di "1. Name of variable in which to store cell midpoints of histogram"
      di "2. Name of variable in which to store cell heights of histogram"
      di "3. Name of variable in which to store evaluation sequence for local linear regression loop"
      di "4. Name of variable in which to store local linear density estimate"
      di "5. Name of variable in which to store standard error of local linear density estimate"
      error 198
    }
    else {
      local cellmpname = "`1'"
      local cellvalname = "`2'"
      local evalname = "`3'"
      local cellsmname = "`4'"
      local cellsmsename = "`5'"
      confirm new var `1'
      confirm new var `2'
      capture confirm new var `3'
      if (_rc!=0 & "`at'"!="`3'") error 198
      confirm new var `4'
      confirm new var `5'
    }
  
    //If the user does not specify the evaluation sequence, this it is taken to be the histogram midpoints
    if ("`at'" == "") {
      local at  = "`1'"
    }
  
    //Call MATA function
    mata: DCdensitysubmod("`R'", "`touse'", `breakpoint', `b', `h', `verbose', "`cellmpname'", "`cellvalname'", ///
                       "`evalname'", "`cellsmname'", "`cellsmsename'", "`at'")
  
    //Dump MATA return codes into STATA return codes 
    return scalar theta = r(theta)
    return scalar se = r(se)
    return scalar binsize = r(binsize)
    return scalar bandwidth = r(bandwidth)
  
    /* clean name and title vars */
    if "`title'" != "" {
      local title title(`title')
    }
    if "`name'" != "" {
      local name name(`name', replace)
    }
  
    //if user wants the graph...
    if ("`graph'"!="nograph") { 
      tempvar hi
      quietly gen `hi' = `cellsmname' + 1.96*`cellsmsename'
      tempvar lo
      quietly gen `lo' = `cellsmname' - 1.96*`cellsmsename'
      gr twoway (scatter `cellvalname' `cellmpname', msymbol(circle_hollow) mcolor(gray))           ///
        (line `cellsmname' `evalname' if `evalname' < `breakpoint', lcolor(black) lwidth(medthick))   ///
          (line `cellsmname' `evalname' if `evalname' > `breakpoint', lcolor(black) lwidth(medthick))   ///
            (line `hi' `evalname' if `evalname' < `breakpoint', lcolor(black) lwidth(vthin))              ///
              (line `lo' `evalname' if `evalname' < `breakpoint', lcolor(black) lwidth(vthin))              ///
                (line `hi' `evalname' if `evalname' > `breakpoint', lcolor(black) lwidth(vthin))              ///
                  (line `lo' `evalname' if `evalname' > `breakpoint', lcolor(black) lwidth(vthin)),             ///
                    xline(`breakpoint', lcolor(black)) legend(off) `xtitle' `ytitle' `title' `subtitle' `name' `graphregion' `xlabel' `ylabel'
      if ("`graphname'"!="") {
        di "Exporting graph as `graphname'"
        graph export `graphname', replace
      }
    }
  }

  end
  
  cap mata : mata drop DCdensitysubmod()
  mata:
  mata set matastrict off
  
  void DCdensitysubmod(string scalar runvar, string scalar tousevar, real scalar c, real scalar b, ///
                    real scalar h, real scalar verbose, string scalar cellmpname, string scalar cellvalname, ///
                    string scalar evalname, string scalar cellsmname, string scalar cellsmsename, ///
                    string scalar atname) {
    //   inputs: runvar - name of stata running variable ("R" in McCrary (2008))
    //             tousevar - name of variable indicating which obs to use
    //             c - point of potential discontinuity
    //             b - bin size entered by user (zero if default is to be used)
    //             h - bandwidth entered by user (zero if default is to be used)
    //             verbose - flag for extra messages printing to screen
    //             cellmpname - name of new variable that will hold the histogram cell midpoints
    //             cellvalname - name of new variable that will hold the histogram values
    //             evalname - name of new variable that will hold locations where the histogram smoothing was
    //                        evaluated
    //             cellsmname - name of new variable that will hold the smoothed histogram cell values
    //             cellsmsename - name of new variable that will hold standard errors for smoothed histogram cells
    //             atname - name of existing stata variable holding points at which to eval smoothed histogram
  
    //declarations for general use and histogram generation
    real colvector run						// stata running variable
    string scalar statacom					// string to hold stata commands
    real scalar errcode                                           // scalar to hold return code for stata commands
    real scalar rn, rsd, rmin, rmax, rp75, rp25, riqr     	// scalars for summary stats of running var
    real scalar l, r						// midpoint of lowest bin and highest bin in histogram
    real scalar lc, rc						// midpoint of bin just left of and just right of breakpoint
    real scalar j							// number of bins spanned by running var
    real colvector binnum						// each obs bin number
    real colvector cellval					// histogram cell values
    real scalar i							// counter
    real scalar cellnum						// cell value holder for histogram generation
    real colvector cellmp						// histogram cell midpoints
  
    //Set up histogram grid
  
    st_view(run, ., runvar, tousevar)     //view of running variable--only observations for which `touse'=1
  
    //Get summary stats on running variable
    statacom = "quietly summarize " + runvar + " if " + tousevar + ", det"
    errcode=_stata(statacom,1)
    if (errcode!=0) {
      "Unable to successfully execute the command "+statacom
      "Check whether you have given Stata enough memory"
    }
    rn = st_numscalar("r(N)")
    rsd = st_numscalar("r(sd)")
    rmin = st_numscalar("r(min)")
    rmax = st_numscalar("r(max)")
    rp75 = st_numscalar("r(p75)") 
    rp25 = st_numscalar("r(p25)")
    riqr = rp75 - rp25
  
    stata("di r(min)")
    stata("di r(max)")  
    
    if ( (c<=rmin) | (c>=rmax) ) {
      printf("Breakpoint must lie strictly within range of running variable\n")
      _error(3498)
    }
    
    //set bin size to default in paper sec. III.B unless provided by the user
    if (b == 0) {
      b = 2*rsd*rn^(-1/2)
      if (verbose) printf("Using default bin size calculation, bin size = %f\n", b)
    }
  
    //bookkeeping
    l = floor((rmin-c)/b)*b+b/2+c  // midpoint of lowest bin in histogram
    r = floor((rmax-c)/b)*b+b/2+c  // midpoint of lowest bin in histogram
    lc = c-(b/2) // midpoint of bin just left of breakpoint
    rc = c+(b/2) // midpoint of bin just right of breakpoint
    j = floor((rmax-rmin)/b)+2
  
    //create bin numbers corresponding to run... See McCrary (2008, eq 2)
    binnum = round((((floor((run :- c):/b):*b:+b:/2:+c) :- l):/b) :+ 1)  // bin number for each obs
  
    //generate histogram 
    cellval = J(j,1,0)  // initialize cellval as j-vector of zeros
    for (i = 1; i <= rn; i++) {
      cellnum = binnum[i]
      cellval[cellnum] = cellval[cellnum] + 1
    }
    
    cellval = cellval :/ rn  // convert counts into fractions
    cellval = cellval :/ b  // normalize histogram to integrate to 1
    cellmp = range(1,j,1)  // initialize cellmp as vector of integers from 1 to j
    cellmp = floor(((l :+ (cellmp:-1):*b):-c):/b):*b:+b:/2:+c  // convert bin numbers into cell midpoints
    
    //place histogram info into stata data set
    real colvector stcellval					// stata view for cell value variable
    real colvector stcellmp					// stata view for cell midpoint variable
  
    (void) st_addvar("float", cellvalname)
    st_view(stcellval, ., cellvalname)
    (void) st_addvar("float", cellmpname)
    st_view(stcellmp, ., cellmpname)
    stcellval[|1\j|] = cellval
    stcellmp[|1\j|] = cellmp
    
    //Run 4th order global polynomial on histogram to get optimal bandwidth (if necessary)
    real matrix P							// projection matrix returned from orthpoly command
    real matrix betaorth4						// coeffs from regression of orthogonal powers of cellmp
    real matrix beta4						// coeffs from normal regression of powers of cellmp
    real scalar mse4						// mean squared error from polynomial regression
    real scalar hleft, hright					// bandwidth est from polynomial left of and right of breakpoint
    real scalar leftofc, rightofc	      			        // bin number just left of and just right of breakpoint
    real colvector cellmpleft, cellmpright			// cell midpoints left of and right of breakpoint
    real colvector fppleft, fppright				// fit second deriv of hist left of and right of breakpoint
  
    //only calculate optimal bandwidth if user hasn't provided one
    if (h == 0) {
      //separate cells left of and right of the cutoff
      leftofc =  round((((floor((lc - c)/b)*b+b/2+c) - l)/b) + 1) // bin number just left of breakpoint
      rightofc = round((((floor((rc - c)/b)*b+b/2+c) - l)/b) + 1) // bin number just right of breakpoint
      if (rightofc-leftofc != 1) {
        printf("Error occurred in optimal bandwidth calculation\n")
        _error(3498)
      }
      cellmpleft = cellmp[|1\leftofc|]
      cellmpright = cellmp[|rightofc\j|]
  
      //estimate 4th order polynomial left of the cutoff
      statacom = "orthpoly " + cellmpname + ", generate(" + cellmpname + "*) deg(4) poly(P)"
      errcode=_stata(statacom,1)
      if (errcode!=0) {
        "Unable to successfully execute the command "+statacom
        "Check whether you have given Stata enough memory"
      }
      P = st_matrix("P")
      statacom = "reg " + cellvalname + " " + cellmpname + "1-" + cellmpname + "4 if " + cellmpname + " < " + strofreal(c)
      errcode=_stata(statacom,1)
      if (errcode!=0) {
        "Unable to successfully execute the command "+statacom
        "Check whether you have given Stata enough memory"
      }
      mse4 = st_numscalar("e(rmse)")^2
      betaorth4 = st_matrix("e(b)")
      beta4 = betaorth4 * P
      fppleft = 2*beta4[2] :+ 6*beta4[3]:*cellmpleft + 12*beta4[4]:*cellmpleft:^2
      hleft = 3.348 * ( mse4*(c-l) / sum( fppleft:^2) )^(1/5)
  
      //estimate 4th order polynomial right of the cutoff
      P = st_matrix("P")
      statacom = "reg " + cellvalname + " " + cellmpname + "1-" + cellmpname + "4 if " + cellmpname + " > " + strofreal(c)
      errcode=_stata(statacom,1)
      if (errcode!=0) {
        "Unable to successfully execute the command "+statacom
        "Check whether you have given Stata enough memory"
      }
      mse4 = st_numscalar("e(rmse)")^2
      betaorth4 = st_matrix("e(b)")
      beta4 = betaorth4 * P
      fppright = 2*beta4[2] :+ 6*beta4[3]:*cellmpright + 12*beta4[4]:*cellmpright:^2
      hright = 3.348 * ( mse4*(r-c) / sum( fppright:^2) )^(1/5)
      statacom = "drop " + cellmpname + "1-" + cellmpname + "4"
      errcode=_stata(statacom,1)
      if (errcode!=0) {
        "Unable to successfully execute the command "+statacom
        "Check whether you have given Stata enough memory"
      }
  
      //set bandwidth to average of calculations from left and right
      h = 0.5*(hleft + hright)
      if (verbose) printf("Using default bandwidth calculation, bandwidth = %f\n", h)
    }
  
    //Add padding zeros to histogram (to assist smoothing)
    real scalar padzeros						// number of zeros to pad on each side of hist
    real scalar jp						// number of histogram bins including padded zeros
    
  //  padzeros = ceil(h/b)  // number of zeros to pad on each side of hist
    padzeros = 0 
    jp = j + 2*padzeros
    if (padzeros >= 1) {
      //add padding to histogram variables
      cellval = ( J(padzeros,1,0) \ cellval \ J(padzeros,1,0) )
      cellmp = ( range(l-padzeros*b,l-b,b) \ cellmp \ range(r+b,r+padzeros*b,b) )
      //dump padded histogram variables out to stata
      stcellval[|1\jp|] = cellval
      stcellmp[|1\jp|] = cellmp
    }
  
    //Generate point estimate of discontinuity
    real colvector dist						// distance from a given observation
    real colvector w						// triangle kernel weights
    real matrix XX, Xy						// regression matrcies for weighted regression
    real rowvector xmean, ymean					// means for demeaning regression vars
    real colvector beta						// regression estimates from weighted reg.
    real colvector ehat						// predicted errors from weighted reg.
    real scalar fhatr, fhatl					// local linear reg. estimates at discontinuity
                                                                  //   estimated from right and left, respectively
    real scalar thetahat						// discontinuity estimate
    real scalar sethetahat					// standard error of discontinuity estimate
    
    //Estimate left of discontinuity
    dist = cellmp :- c  // distance from potential discontinuity
    w = rowmax( (J(jp,1,0), (1:-abs(dist:/h))) ):*(cellmp:<c)  // triangle kernel weights for left
    w = (w:/sum(w)) :* jp  // normalize weights to sum to number of cells (as does stata aweights)
    xmean = mean(dist, w)
    ymean = mean(cellval, w)
    XX = quadcrossdev(dist,xmean,w,dist,xmean)    //fixed error on 11.17.2009
    Xy = quadcrossdev(dist,xmean,w,cellval,ymean)
    beta = invsym(XX)*Xy
    beta = beta \ ymean-xmean*beta
    fhatl = beta[2,1]
    
    //Estimate right of discontinuity
    w = rowmax( (J(jp,1,0), (1:-abs(dist:/h))) ):*(cellmp:>=c)  // triangle kernel weights for right
    w = (w:/sum(w)) :* jp  // normalize weights to sum to number of cells (as does stata aweights)
    xmean = mean(dist, w)
    ymean = mean(cellval, w)
    XX = quadcrossdev(dist,xmean,w,dist,xmean)   //fixed error on 11.17.2009
    Xy = quadcrossdev(dist,xmean,w,cellval,ymean)
    beta = invsym(XX)*Xy
    beta = beta \ ymean-xmean*beta
    fhatr = beta[2,1]
    
    //Calculate and display discontinuity estimate
    thetahat = ln(fhatr) - ln(fhatl)
    sethetahat = sqrt( (1/(rn*h)) * (24/5) * ((1/fhatr) + (1/fhatl)) )
    printf("\nDiscontinuity estimate (log difference in height): %f\n", thetahat)
    printf("                                                   (%f)\n", sethetahat)
  
    loopover=1 //This is an advanced user switch to get rid of LLR smoothing
    //Can be used to speed up simulation runs--the switch avoids smoothing at
    //eval points you aren't studying
    
    //Perform local linear regression (LLR) smoothing
    if (loopover==1) {
      real scalar cellsm						// smoothed histogram cell values
      real colvector stcellsm					// stata view for smoothed values
      real colvector atstata					// stata view for at variable (evaluation points)
      real colvector at						// points at which to evaluate LLR smoothing
      real scalar evalpts						// number of evaluation points
      real colvector steval						// stata view for LLR smothing eval points
  
      // if evaluating at cell midpoints
      if (atname == cellmpname) {  
        at = cellmp[|padzeros+1\padzeros+j|]
        evalpts = j
      }
      else {
        st_view(atstata, ., atname)
        evalpts = nonmissing(atstata)
        at = atstata[|1\evalpts|]
      }
      
      if (verbose) printf("Performing LLR smoothing.\n")
      if (verbose) printf("%f iterations will be performed \n",j)
      
      cellsm = J(evalpts,1,0)  // initialize smoothed histogram cell values to zero
      // loop over all evaluation points
      for (i = 1; i <= evalpts; i++) {
        dist = cellmp :- at[i]
        //set weights relative to current bin - note comma below is row join operator, not two separate args
        w = rowmax( (J(jp,1,0), ///
          (1:-abs(dist:/h))):*((cellmp:>=c)*(at[i]>=c):+(cellmp:<c):*(at[i]<c)) )
        //manually obtain weighted regression coefficients
        w = (w:/sum(w)) :* jp  // normalize weights to sum to N (as does stata aweights)
        xmean = mean(dist, w)
        ymean = mean(cellval, w)
        XX = quadcrossdev(dist,xmean,w,dist,xmean)  //fixed error on 11.17.2009 
        Xy = quadcrossdev(dist,xmean,w,cellval,ymean)
        beta = invsym(XX)*Xy
        beta = beta \ ymean-xmean*beta
        cellsm[i] = beta[2,1]
        //Show dots
        if (verbose) {
          if (mod(i,10) == 0) {
            printf(".")
            displayflush()
            if (mod(i,500) == 0) {
              printf(" %f LLR iterations\n",i)
              displayflush()
            }
          }
        }
      }
      printf("\n")
    
      //set up stata variable to hold evaluation points for smoothed values
      (void) st_addvar("float", evalname)
      st_view(steval, ., evalname)
      steval[|1\evalpts|] = at
  
      //set up stata variable to hold smoothed values
      (void) st_addvar("float", cellsmname)
      st_view(stcellsm, ., cellsmname)
      stcellsm[|1\evalpts|] = cellsm
      
      //Calculate standard errors for LLR smoothed values
      real scalar m					// amount of kernel being truncated by breakpoint
      real colvector cellsmse				// standard errors of smoothed histogram
      real colvector stcellsmse				// stata view for cell midpoint variable
      cellsmse = J(evalpts,1,0)  // initialize standard errors to zero
      for (i = 1; i <= evalpts; i++) {
        if (at[i] > c) {
          m = max((-1, (c-at[i])/h))
          cellsmse[i] = ((12*cellsm[i])/(5*rn*h))* ///
            (2-3*m^11-24*m^10-83*m^9-72*m^8+42*m^7+18*m^6-18*m^5+18*m^4-3*m^3+18*m^2-15*m)/ ///
              (1+m^6+6*m^5-3*m^4-4*m^3+9*m^2-6*m)^2
          cellsmse[i] = sqrt(cellsmse[i])
        }
        if (at[i] < c) {
          m = min(((c-at[i])/h, 1))
          cellsmse[i] = ((12*cellsm[i])/(5*rn*h))* ///
            (2+3*m^11-24*m^10+83*m^9-72*m^8-42*m^7+18*m^6+18*m^5+18*m^4-3*m^3+18*m^2+15*m)/ ///
              (1+m^6-6*m^5-3*m^4+4*m^3+9*m^2+6*m)^2
          cellsmse[i] = sqrt(cellsmse[i])
        }
      }
      //set up stata variable to hold standard errors for smoothed values
      (void) st_addvar("float", cellsmsename)
      st_view(stcellsmse, ., cellsmsename)
      stcellsmse[|1\evalpts|] = cellsmse
    }
    //End of loop over evaluation points
    
    //Fill in STATA return codes
    st_rclear()
    st_numscalar("r(theta)", thetahat)
    st_numscalar("r(se)", sethetahat)
    st_numscalar("r(binsize)", b)
    st_numscalar("r(bandwidth)", h)
  }
  end
  
  /* *********** END program dc_density ***************************************** */

  /* load stata-tex programs */
  do $pmgsy_code/stata-tex/stata-tex
}

