/*  Income by Education and Occupation */

/* reset maximum number of vars we can have in our dataset */
clear all
clear mata
set maxvar 30000

/* load settings */
do $pmgsy_code/settings

/* initialize the intermediate and final output files - note that
intermed file gets overwritten in the loop */
cap rm $tmp/cons_by_ed_occ_boot.csv

/* loop over all levels of the two vars we have bootstrapped consumption for */
foreach x in hh_man_ag edmax_3 {
  foreach y in 1 2 3 {

    /* read in our data */
    use $pmgsy_data/cons_boot_in, clear

    /* get rid of previous datafiles */
    cap rm $tmp/inc_by_ed_occ_intermed_`x'`y'.csv

    /* if using edmax_3bin, our program creates names (mean) that are one
    character too long. so rename */
    if "`x'" == "edmax_3" {
      rename *edmax_3bin* *edmax_3*
    }

    /* run the programs */
    cons_boot, outfile("$tmp/cons_by_ed_occ_intermed_`x'`y'.csv") name(secc_conspc`i'winln_`x'`y') spec("ivregress 2sls secc_conspcBOOTSTRAPNUMwinln_`x'`y' (r2012 = t) left right  $controls i.vhg_dist_id [aw = weight_BOOTSTRAPNUM] if mainsample, vce(robust)") sumvar(secc_conspcBOOTSTRAPNUMwinln_`x'`y')
    store_est_tpl_boot using $tmp/cons_by_ed_occ_boot.csv, infile("$tmp/cons_by_ed_occ_intermed_`x'`y'.csv") name(secc_conspcwinln_`x'`y') sumvar(secc_conspcwinln_`x'`y'_mean) sumvarformat("%6.2f") 
  }
}

/* now use template to make our table */
table_from_tpl, t($table_templates/cons_by_ed_occ_boot_tpl.tex) r($tmp/cons_by_ed_occ_boot.csv) o($out/cons_by_ed_occ_boot.tex)

