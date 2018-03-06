*! version 0.0 DIME Analytics lcardosodeandrad@worldbank.org
		
	capture program drop ieenumtime
	program ieenumtime
	
		syntax varlist(varlist) [if] [in], 									///
																			///
				ENUMvar(varname)											///
				TEAMvar(varname) 											///
				LOWERbound()												///
				UPPERbound()												///
				barcolor()													///
				meancolor()													///
				lowercolor()												///
				uppercolor()												///
				outfolder()													///
				outformat()													///
				REPLACE
				
				
				
	
********************************************************************************
* 						Part 1: Calculate option locals
********************************************************************************
	
		*Is option enumvar() used:
		if "`enumvar'" 			== "" local ENUM_USED = 0 
		if "`enumvar'" 			!= "" local ENUM_USED = 1 
		
		*Is option teamvar() used:
		if "`teamvar'" 			== "" local TEAM_USED = 0 
		if "`teamvar'" 			!= "" local TEAM_USED = 1 
		
		*Is option lowerbound() used:
		if "`lowerbound'" 		== "" local LOWER_USED = 0 
		if "`lowerbound'" 		!= "" local LOWER_USED = 1 		
		
		*Is option uppperbound() used:
		if "`uppperbound'"		== "" local UPPER_USED = 0 
		if "`uppperbound'" 		!= "" local UPPER_USED = 1 
		
		*Is option barcolor() used:
		if "`barcolor'"			== "" local BCOLOR_USED = 0 
		if "`barcolor'" 		!= "" local BCOLOR_USED = 1 
		
		*Is option meancolor() used:
		if "`meancolor'"		== "" local MCOLOR_USED = 0 
		if "`meancolor'" 		!= "" local MCOLOR_USED = 1 
		
		*Is option lowercolor() used:
		if "`lowercolor'"		== "" local LCOLOR_USED = 0 
		if "`lowercolor'" 		!= "" local LCOLOR_USED = 1 
		
		*Is option uppercolor() used:
		if "`uppercolor'"		== "" local UCOLOR_USED = 0 
		if "`uppercolor'" 		!= "" local UCOLOR_USED = 1 
		
		*Is option outfolder() used:
		if "`outfolder'"		== "" local FOLDER_USED = 0 
		if "`outfolder'" 		!= "" local FOLDER_USED = 1 
		
		*Is option outformat() used:
		if "`outformat'"		== "" local FORMAT_USED = 0 
		if "`outformat'" 		!= "" local FORMAT_USED = 1 
		
	
********************************************************************************
* 						Part 2: Display error messages
********************************************************************************

	* Enumerator variable not specified
	* Enumerator variable has missings
	* Team variable is not defined for some enumerators
	* Lower bound format is incorrectly specified
	* Upper bound format is incorrectly specified
	* Upper bound and lower bound are the same
	* Upper bound is smaller than lower bound
	* Output folder path
	* Output format is incorrectly specified
	

********************************************************************************
* 						Part 3: Calculate general inputs
********************************************************************************		

	* Variables
	local durationList	`varlist'
	
	* Set default options
	if !`BCOLOR_USED' {
		local barcolor		stone
	}
	if !`MCOLOR_USED' {
		local meancolor		olive
	}
	if !`LCOLOR_USED' {
		local lowercolor	dkorange
	}
	if !`UCOLOR_USED' {
		local uppercolor	ebblue
	}
	if !`FORMAT_USED' {
		local outformat		png
	}

	* Teams list
	if `TEAM_USED' {
		levelsof `teamvar', local(teamsList)
	}
	
********************************************************************************
* 				Part 4: Create graphs for all variables in the list
********************************************************************************
	
	foreach durationVar of local durationList {
	
*-------------------------------------------------------------------------------
* 							Part 4.1: Calculate inputs
*-------------------------------------------------------------------------------

		* Calculate mean 
		qui sum `durationVar'
		local 	mean = r(mean)
		
		* Calculate percentiles to be marked
		centile `durationVar', centile(`lowerbound' `upperbound')
		
		if `LOWER_USED' & `UPPER_USED' {
			local 	low  = `r(c_1)'
			local 	high = `r(c_2)'
		}
		else if `LOWER_USED' & !`UPPER_USED' {
			local 	low  = `r(c_1)'
		}
		else if !`LOWER_USED' & `UPPER_USED' {
			local 	high  = `r(c_1)'
		}
		
		* Calculate graph title
		local title: var label `durationVar'
		
		* Calculate output path
		if `FOLDER_USED' {
			local outputPath "`outfolder'/ieenumtime_`durationVar'"
		}
		else {
			local outputPath "ieenumtime_`durationVar'"
		}

*-------------------------------------------------------------------------------
* 						Part 4.2: Create graph by teams
*-------------------------------------------------------------------------------

		if `TEAM_USED' {
		
			foreach teamCode of local teamsList {
			
				* Create graph
				gr 	hbox `durationVar' if `teamvar' == `teamCode', over(`enumvar') ///
					box(1, color(`barcolor')) ///
					title("`title'") ///
					ytitle("") ///
					yline(`mean', lcolor(`meancolor') lpattern(dash)) ///
					yline(`low', lcolor(`lowercolor') lpattern(dash)) ///
					yline(`high', lcolor(`uppercolor') lpattern(dash)) ///
					graphregion(color(white))
						
				* Export graph
				graph export "`outputPath'_team`teamCode'", as(`outformat') width(5000) replace
			}
		}
		
*-------------------------------------------------------------------------------
*						Part 4.3: Create graph without teams
*-------------------------------------------------------------------------------

		else {
			* Create graph
				gr 	hbox `durationVar', over(`enumvar') ///
					box(1, color(`barcolor')) ///
					title("`title'") ///
					ytitle("") ///
					yline(`mean', lcolor(`meancolor') lpattern(dash)) ///
					yline(`low', lcolor(`lowercolor') lpattern(dash)) ///
					yline(`high', lcolor(`uppercolor') lpattern(dash)) ///
					graphregion(color(white))
						
				* Export graph
				graph export "`outputPath'", as(`outformat') width(5000) `replace'
		}			
	}
