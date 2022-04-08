/**************************************************************/
/* Generate sectoral shares of workers in non-ag manual labor */
/**************************************************************/

/*
Use the NSS to generate table showing share of rural workers in non-ag
manual labor in the major sectors (will be construction, etc). Sample:
rural workers in NSS in 9 (elementary occupations) minus 92 (agricultural labor).

Occupation var: prim_nco
Industry var: prim_nic
*/

/* read in NSS data */
use ~/iec1/misc_data/nss68/nss_sch10.dta, clear

/* cut to our desired sample - non-ag manual laborers. this regular
expression search keeps all 900-level codes, but drops 92* as those
are agricultural. */
keep if regexm(prim_nco, "^[9]+[1, 3]+[0-9]")

/* drop the NIC codes that match to ag/forestry/fishing - these are
01-03 (plus an additional 3 digits) */
drop if inrange(prim_nic, 0, 4000)

/* create our new classification for industries that non-ag manual
laborers participate in */
gen other = 1
label var other "Manual laborers with other NIC codes"

gen constr = 0
replace constr = 1 if inrange(prim_nic, 41000, 43999)
replace other = 0 if inrange(prim_nic, 41000, 43999)
label var constr "NIC 41-43 for non-ag manual laborers"

gen transport = 0
replace transport = 1 if inrange(prim_nic, 49000, 49999)
replace other = 0 if inrange(prim_nic, 49000, 49999)
label var transport "NIC 49 for non-ag manual laborers"

gen retail = 0
replace retail = 1 if inrange(prim_nic, 47000, 47999)
replace other = 0 if inrange(prim_nic, 47000, 47999)
label var retail "NIC 41 for non-ag manual laborers"

gen manuf_brick = 0
replace manuf_brick = 1 if inrange(prim_nic, 23000, 23999)
replace other = 0 if inrange(prim_nic, 23000, 23999)
label var manuf_brick "NIC 23 for non-ag manual laborers, primarily brick/stone"

gen domestic = 0
replace domestic = 1 if inrange(prim_nic, 96000, 97999)
replace other = 0 if inrange(prim_nic, 96000, 97999)
label var domestic "NIC 41 for non-ag manual laborers"

gen total = 1

/* remove any previous versions of our output file */
cap rm $tmp/nss_manlab_sectors.csv

foreach var in domestic manuf_brick retail transport constr other total {

  /* note that we don't have to include `if manlab` since we already
  dropped everyone who is not a non-ag manual laborer */
  sum `var' [aw=hhwt]

  /* store the statistic of interest */
  store_val_tpl using $tmp/nss_manlab_sectors.csv, name("`var'_share") value(`r(mean)') format("%5.2f")
}

table_from_tpl, t($table_templates/nss_manlab_sectors_tpl.tex) r($tmp/nss_manlab_sectors.csv) o($out/nss_manlab_sectors.tex)

