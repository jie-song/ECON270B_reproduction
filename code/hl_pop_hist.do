use $pmgsy_data/pmgsy_2015, clear

/* load settings */
do $pmgsy_code/settings

/* generate histogram */
histogram hl2_hab_pop if hl2_hab_pop < 2000, width(25) start(0) xline(500 1000, lcolor(gs5)) xtitle("Population") freq ylabel(10000 "10,000" 20000 "20,000" 30000 "30,000" 40000 "40,000" 50000 "50,000" 60000 "60,000") lpattern(solid color(white)) graphregion(color(white)) gap(5) color(gs12) lcolor(white) 
graph export $out/hl_pop_hist.eps, replace
!epstopdf $out/hl_pop_hist.eps

