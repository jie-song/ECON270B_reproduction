use $pmgsy_data/pmgsy_working_aer, clear
do $pmgsy_code/settings

/* histogram */
histogram pc01_pca_tot_p if pc01_pca_tot_p < 1500, start(0) width(25) xline(500 1000, lcolor(gs5)) freq title("Histogram of Village Population") subtitle("2001 Population Census Data") xtitle("Population") ylabel(2000 "2000" 4000 "4000" 6000 "6000" 8000 "8000") lpattern(solid color(white)) graphregion(color(white)) gap(5) color(gs12) lcolor(white)
graph export $out/hist_pc01pop.eps, replace
!epstopdf $out/hist_pc01pop.eps

/* mccrary test */

/* pooled 500 1000 */
dc_density v_pop if $states & (inrange(pc01_pca_tot_p, 400, 599) | inrange(pc01_pca_tot_p, 900, 1099)) & $noroad & $nobad, breakpoint(0) b(1) generate(Xj Yj r0 fhat se_fhat) graphname($out/mccrary_leftright_pooled.eps) xtitle("Normalized Population") ytitle("Density") graphregion(color(white)) 
drop Xj Yj r0 fhat se_fhat
!epstopdf $out/mccrary_leftright_pooled.eps

