qui {

  /* clear programs */
  clear programs
  
  /* data directories -- no need to change because all being set according to $base set above */
  global tmp "$base/tmp"
  global pmgsytmp "$tmp/pmgsy"
  global table_templates $base/code/tables
  global PYTHONPATH "$base/code/stata-tex"
  global output $base/output
  global outpmgsy $output/pmgsy
  global out $outpmgsy/aer_shrug
  global pmgsy_code $base/code
  global pmgsy          $base/data/misc_data/pmgsy
  global pmgsy_data     $base/data/pmgsy
  global pmgsy_raw      $base/data/misc_data/pmgsy/scrape
  global shrug_data     $shrug
  global shrug_keys     $shrug
  global ndvi           $base/data/ndvi
  global ec_collapsed   $base/data/ec_collapsed
  global keys           $base/data/keys
  global fao            $base/data/misc_data/fao
  global pc11           $base/data/pc11
  global pc11_ag        $base/data/pc11/ag_comm
  global night_lights   $base/data/misc_data/night_lights
  global ddp            $base/data/misc_data/ddp
  global bpl            $base/data/misc_data/bpl_2002

  /* set location for calling lev.py */
  global MASALA_DIR $pmgsy_code
  
  /* make sure all folders are created */
  cap mkdir $tmp
  cap mkdir $pmgsytmp
  cap mkdir $output
  cap mkdir $outpmgsy
  cap mkdir $out
  cap mkdir $table_templates
  
  /* set estout options */
  global estout_params       cells(b(fmt(3) star) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(N r2, fmt(0 2)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\$^{*}p<0.10, ^{**}p<0.05, ^{***}p<0.01\$} \\" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_txt   cells(b(fmt(3) star) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(N r2, fmt(0 2)) collabels(none) replace
  global estout_params_fstat cells(b(fmt(3) star) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(f_stat N r2, labels("F Statistic" "N" "R2" suffix(\hline)) fmt(%9.4g)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{$^{*}p<0.10, ^{**}p<0.05, ^{***}p<0.01$} \\" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global esttab_params       prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")

  /* clear estimates storage */
  eststo clear
  cap set processors 2
  cap set processors 4
  set matsize 10000

  /* load clean graph scheme */
  cap set scheme simplescheme

  /* load programs */
  do $pmgsy_code/pmgsy_include

  /* set family index globals */
  global transport_vars pc11_vd_bus_gov pc11_vd_bus_priv pc11_vd_taxi pc11_vd_vans pc11_vd_auto
  global occupation_vars nco2d_cultiv_share 
  global firms_vars ec13_emp_all_ln 
  global agriculture_vars ndvi_delta_2011_2013_ln secc_mech_farm_share secc_irr_equip_share secc_land_own_share pc11_ag_acre_ln any_noncerpul
  global consumption_vars cons_pc_win_ln secc_asset_index ln_light2011_2013 secc_inc_5k_plus_share 

  /* set firm specification for non-bad observations */
  global nobad_firms inrange(ec13_emp_share, 0, 1)

  /* set base levels */
  cap fvset base 1 dist_id
  cap fvset base 1 state_id
  cap fvset base 1 v_high_group
  cap fvset base 1 vhg_dist_id

  /* set scheme */
  set scheme s2color

  /* define new estout params such that stored bin means will be included in table */
  global estout_params_means_cultiv cells(b(nostar fmt(3)) se(par fmt(3))) varlabels(_cons Constant) label stats(mean_cultivation_share N r2, labels("Control mean cult share" "N" "R2" suffix(\hline)) fmt(%9.3f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_means_pop cells(b(nostar fmt(3)) se(par fmt(3))) varlabels(_cons Constant) label stats(mean_cultivation_share N r2, labels("Control mean pop growth" "N" "R2" suffix(\hline)) fmt(%9.3f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_fe cells(b(nostar fmt(3)) se(par fmt(3))) varlabels(_cons Constant) label stats(FE N r2, labels("Fixed Effects" "N" "R2" suffix(\hline)) fmt(%9.3f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_fstat cells(b(nostar fmt(3)) se(par fmt(3))) varlabels(_cons Constant) label stats(f_stat N r2, labels("F statistic" "N" "R2" suffix(\hline)) fmt(%9.1f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global esttab_params prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_panel cells(b(nostar fmt(3)) se(par fmt(3))) varlabels(_cons Constant) label stats(obs, labels("N") fmt(0 2)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline"  "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_panel_noobs cells(b(nostar fmt(3)) se(par fmt(3))) varlabels(_cons Constant) label collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline"  "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_panel_means cells(b(nostar fmt(3)) se(par fmt(3))) varlabels(_cons Constant) label stats(mean_mech mean_irr obs, labels("Control mean mech equip share" "Control mean irr equip share" "N") fmt(2 2 0)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline"  "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_means_outcome cells(b(nostar fmt(3)) se(par fmt(3))) varlabels(_cons Constant) label stats(outcome_mean N r2, labels("Control group mean" "N" "R2" suffix(\hline)) fmt(%9.3f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_means_level cells(b(nostar fmt(3)) se(par fmt(3))) varlabels(_cons Constant) label stats(outcome_mean N r2, labels("Mean level" "N" "R2" suffix(\hline)) fmt(%9.3f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_means_outcome_emp cells(b(nostar fmt(3)) se(par fmt(3))) varlabels(_cons Constant) label stats(outcome_mean N r2, labels("Mean employment" "N" "R2" suffix(\hline)) fmt(%9.1f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_means_outcome_cons cells(b(nostar fmt(3)) se(par fmt(3))) varlabels(_cons Constant) label stats(outcome_mean N r2, labels("Mean consumption pc" "N" "R2" suffix(\hline)) fmt(%9.0f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_means_land cells(b(nostar fmt(3)) se(par fmt(3))) varlabels(_cons Constant) label stats(mean_land_share N r2, labels("Share of HH" "N" "R2" suffix(\hline)) fmt(%9.3f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_panel_means_pc cells(b(nostar fmt(3)) se(par fmt(3))) varlabels(_cons Constant) label stats(noprior_mean, labels("Mean difference") fmt(2 2 0)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline"  "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_interact cells(b(nostar fmt(3)) se(par fmt(3))) varlabels(_cons Constant) label stats(pval N r2, labels("Joint p-value" "N" "R2" suffix(\hline)) fmt(%9.3f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")

  /* define globals for formatting balance tables */
  global balance_start \setlength{\linewidth}{.1cm} \begin{center} \newcommand{\contents}{\begin{tabular}{l r r r r r r}\hline\hline Variable & Below & Above & Difference & t-stat on & RD & t-stat on \\ & threshold & threshold & of means & difference & estimate & RD estimate \\ \hline
  global balance_pres_start \begin{tabular}{l r r r}\hline\hline Variable & t-stat on & RD & t-stat on \\ & difference & estimate & RD estimate \\ \hline
  global balance_end \hline \multicolumn{7}{p{\linewidth}}{\footnotesize \tablenote} \end{tabular} }  \setbox0=\hbox{\contents} \setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}
  global estout_params_balance $estout_params note("All regressions with robust standard errors") 

  /* hack to get formatting right */
  global dec_list `" $balance_vars "'

  /* estout with stars */
  global estout_params_means_cultiv_s cells(b(star fmt(3)) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(mean_cultivation_share N r2, labels("Control mean cult share" "N" "R2" suffix(\hline)) fmt(%9.3f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_means_pop_s cells(b(star fmt(3)) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(mean_cultivation_share N r2, labels("Control mean pop growth" "N" "R2" suffix(\hline)) fmt(%9.3f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_fe_s cells(b(star fmt(3)) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(FE N r2, labels("Fixed Effects" "N" "R2" suffix(\hline)) fmt(%9.3f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_fstat_s cells(b(star fmt(3)) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(f_stat N r2, labels("F statistic" "N" "R2" suffix(\hline)) fmt(%9.1f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global esttab_params_s prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_panel_s cells(b(star fmt(3)) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(obs, labels("N") fmt(0 2)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline"  "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_panel_noobs_s cells(b(star fmt(3)) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline"  "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_panel_means_s cells(b(star fmt(3)) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(mean_mech mean_irr obs, labels("Control mean mech equip share" "Control mean irr equip share" "N") fmt(2 2 0)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline"  "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_means_outcome_s cells(b(star fmt(3)) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(outcome_mean N r2, labels("Control group mean" "N" "R2" suffix(\hline)) fmt(%9.3f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{$^{*}p<0.10, ^{**}p<0.05, ^{***}p<0.01$} \\" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_means_level_s cells(b(star fmt(3)) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(outcome_mean N r2, labels("Mean level" "N" "R2" suffix(\hline)) fmt(%9.3f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_means_outcomeemps cells(b(star fmt(3)) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(outcome_mean N r2, labels("Mean employment" "N" "R2" suffix(\hline)) fmt(%9.1f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_means_outcomeconss cells(b(star fmt(3)) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(outcome_mean N r2, labels("Mean consumption pc" "N" "R2" suffix(\hline)) fmt(%9.0f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_means_land_s cells(b(star fmt(3)) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(mean_land_share N r2, labels("Share of HH" "N" "R2" suffix(\hline)) fmt(%9.3f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_panel_means_pc_s cells(b(star fmt(3)) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(noprior_mean, labels("Mean difference") fmt(2 2 0)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline"  "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")
  global estout_params_interact_s cells(b(star fmt(3)) se(par fmt(3))) starlevels(* .1 ** .05 *** .01) varlabels(_cons Constant) label stats(pval N r2, labels("Joint p-value" "N" "R2" suffix(\hline)) fmt(%9.3f %9.0f %9.2f)) collabels(none) style(tex) replace prehead("\setlength{\linewidth}{.1cm} \begin{center}" "\newcommand{\contents}{\begin{tabular}{l*{@M}{c}}" "\hline\hline") posthead(\hline) prefoot(\hline) postfoot("\hline" "\multicolumn{@span}{p{\linewidth}}{\footnotesize \tablenote}" "\end{tabular} }" "\setbox0=\hbox{\contents}" "\setlength{\linewidth}{\wd0-2\tabcolsep-.25em} \contents \end{center}")

  /* controls (and subset for displaying balance) */
  global controls     primary_school med_center elect tdist irr_share ln_land pc01_lit_share pc01_sc_share bpl_landed_share bpl_inc_source_sub_share bpl_inc_250plus 
  global balance_vars primary_school med_center elect tdist irr_share ln_land pc01_lit_share pc01_sc_share

  /* parameters to define sample */
  global states (rj_l | mp_l | mp_h | cg_l | cg_h | or_l | mh_l | gj_l)
  global statelist rj_l mp_l mp_h cg_l cg_h or_l mh_l gj_l
  global noroad (app_pr == 0 | con00 == 0)
  global nobad inrange(secc_pop_ratio, .8, 1.2)
  cap mkdir $out

  /* set specification parameters */
  global rdbands 60 70 80 90 100 110
  global mainband ik
  global kernel tri

  /* set quality measures for spillover catchments */
  global catch_sample (inrange(secc_pop_ratio, .8, 1.2) & !mi(latitude) & !mi(longitude))

  /* set sample for spillover villages (centers of spillover catchments) */
  global spill_sample (inrange(pc01_pca_tot_p, 400, 600) | inrange(pc01_pca_tot_p, 900, 1100)) & $catch_sample

  /* where we will write out final spillover data */
  global spill_out $pmgsy_data/pmgsy/

  /* set list of pc11 PMGSY state names into a global */
  global pc11_pmgsy_states chhattisgarh gujarat madhyapradesh odisha rajasthan maharashtra

  /* set list of regression vars necessary for consumption imputation in
  the SECC */
  global secc_impute_vars land_own kisan_cc refrig num_room wall_mat_grass wall_mat_mud wall_mat_plastic wall_mat_wood wall_mat_brick wall_mat_gi wall_mat_stone wall_mat_concrete roof_mat_grass roof_mat_tile roof_mat_slate roof_mat_plastic roof_mat_gi roof_mat_brick roof_mat_stone roof_mat_concrete house_own_owned vehicle_two vehicle_four phone_landline_only phone_mobile_only phone_both high_inc_5000_10000 high_inc_more_10000

  /* set statelist for all of india */
  global allindia_statenames andhrapradesh assam bihar chhattisgarh gujarat haryana himachalpradesh jammukashmir jharkhand karnataka kerala madhyapradesh maharashtra odisha punjab rajasthan tamilnadu uttarakhand uttarpradesh westbengal

  /* set ik and cct bands for any analysis */
  global ik_band 84
  global cct_band 78 

  /* set globals containing keep variables for merging in datasets
  parsimoniously. first NCOs */
  global nco04_1d_vars
  global nco04_2d_vars
  foreach sex in p m f {
    foreach num in 21 26 31 36 41 46 51 56 {
      global nco04_1d_vars $nco04_1d_vars secc_nco04_1d_`sex'_`num'
      global nco04_2d_vars $nco04_2d_vars secc_nco04_2d_92_`sex'_`num'
      global nco04_2d_vars $nco04_2d_vars secc_nco04_1d_Y_`sex'_`num'
      global nco04_2d_vars $nco04_2d_vars secc_nco04_1d_Z_`sex'_`num'
      foreach nco in 6 9 Y {
        global nco04_1d_vars $nco04_1d_vars secc_nco04_1d_`nco'_`sex'_`num'
      }
    }
  }
  global nco04_1d_vars $nco04_1d_vars secc_nco04_1d_6_share secc_nco04_1d_9_share secc_nco04_1d_Y secc_nco04_1d_Z secc_nco04_1d_Y_share secc_nco04_1d_Z_share
  global nco04_2d_vars $nco04_2d_vars secc_nco04_2d_92_share  

  /* now gender and age */
  global secc_age_vars
  foreach sex in p m f {
    forval i = 1(5)60 {
      local ip4 = `i' + 4
      global secc_age_vars $secc_age_vars secc_age_`i'_`ip4'_`sex'
    }
  }



}
