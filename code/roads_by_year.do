/* used to make timeline figure */
use $pmgsy_raw/comp_roads_DVW2, clear
gen year = year(dvw2_date_completion)
keep if inrange(year, 2000, 2014)
gen one = 1
collapse (sum) one, by(year)
ren one roads_completed
export excel $out/road_comp_by_year, replace firstrow(variables)
