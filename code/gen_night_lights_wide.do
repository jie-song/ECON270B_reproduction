/* this do file simply reshapes existing night lights data. */
use ~/iec2/night_lights/village_poly_nl_annual, clear
reshape wide *_light num_cells, i(pc01_state_id pc01_village_id) j(year)
save $pmgsy_data/pc11_poly_nl_wide_pc01, replace

