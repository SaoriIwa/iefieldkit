//! version 0.1 19OCT2018  DIME Analytics bdaniels@worldbank.org

// Main syntax –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

cap program drop iecodebook
	program def  iecodebook

	syntax anything using , [*]

	// Select and execute subcommand

		gettoken subcommand anything : anything
		iecodebook_`subcommand' `anything' `using' , `options'

end

// Export subroutine –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

cap program drop iecodebook_export
	program 	 iecodebook_export

	syntax [anything] [using] , [template(string asis)]
qui {

	// Template Setup

		if "`anything'" != "" {
			use "`anything'" , clear
		}

		if "`template'" != "" {
			local template_colon ":`template'" 	// colon for titles
			local TEMPLATE = 1					// flag for template functions
		}
		else local TEMPLATE = 0

	// Set up temps

		preserve
		clear

		tempfile theLabels

		tempfile theCommands
			save `theCommands' , replace emptyok

		restore

	// TODO: trim variable set to variables specified in selected dofiles

	// Create XLSX file with all current variable names and labels – use SurveyCTO syntax for sheet names and column names
	preserve

		// Record dataset info

			local allVariables
			local allLabels
			local allChoices

			foreach var of varlist * {
				local theVariable 	= "`var'"
				local theLabel		: var label `var'
				local theChoices	: val label `var'

				local allVariables 	`"`allVariables' "`theVariable'""'
				local allLabels    	`"`allLabels'   "`theLabel'""'
				local allChoices 	`"`allChoices'   "`theChoices'""'
			}

		// Write to new dataset

			clear

			local theN : word count `allVariables'

			local templateN ""
			if `TEMPLATE' {
				import excel `using' , clear first sheet("survey")

				count
				local templateN "+ `r(N)'"
			}

			set obs `=`theN' `templateN''

			gen name`template' = ""
				label var name`template' "name`template_colon'"
			gen label`template' = ""
				label var label`template' "label`template_colon'"
			gen choices`template' = ""
				label var choices`template' "choices`template_colon'"
			if `TEMPLATE' gen recode`template' = ""
				if `TEMPLATE' label var recode`template' "recode`template_colon'"

			forvalues i = 1/`theN' {
				local theVariable 	: word `i' of `allVariables'
				local theLabel		: word `i' of `allLabels'
				local theChoices	: word `i' of `allChoices'

				replace name`template' 		= "`theVariable'" 	in `=`i'`templateN''
				replace label`template' 	= "`theLabel'" 		in `=`i'`templateN''
				replace choices`template' 	= "`theChoices'" 	in `=`i'`templateN''
			}

		// Export variable information to "survey" sheet

			export excel `using' , sheet("survey") sheetreplace first(varl)
	restore

	// Create value labels sheet

		// Fill temp dataset with value labels

			foreach var of varlist * {
				local theLabel : value label `var'
				cap label save `theLabel' using `theLabels' ,replace
				if _rc==0 {
					preserve
					import delimited using `theLabels' , clear delimit(", modify", asstring)
					append using `theCommands'
						save `theCommands' , replace emptyok

					restore
				}
			}

		// Clean up value labels for export – use SurveyCTO syntax for sheet names and column names

			use `theCommands' , clear

			count
			if `r(N)' > 0 {
				duplicates drop
				drop v2
				replace v1 = trim(subinstr(v1,"label define","",.))
				split v1 , parse(`"""')
				split v11 , parse(`" "')
				keep v111 v112 v12
				order v111 v112 v12

				rename (v111 v112 v12)(list_name value label)
			}
			else {
				set obs 1
				gen list_name = ""
				gen value = ""
				gen label = ""
			}

		// Export value labels to "choices" sheet

			export excel `using' , sheet("choices`template'") sheetreplace first(var)

} // end qui
end

// Apply subroutine –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

cap program drop iecodebook_apply
	program 	 iecodebook_apply

	syntax [anything] [using] , [template] [survey(string asis)]

	// Setups

		if "`survey'" == "" local survey "current"

	// Template setup

		if "`template'" != "" {
			// create empty codebook
				preserve
					clear
					set obs 1
					gen survey = 0
						label var survey "Survey"
					iecodebook export `using'
				restore
			save current.temp , replace
			iecodebook export "current.temp" `using' , template(`survey')
			!rm current.temp
		}

	// Apply codebook
	preserve

		// Loop over survey sheet and accumulate rename, relabel, recode, vallab

			import excel `using' , clear first sheet(survey)

			keep if name != "" & name`survey' != ""

			count
			forvalues i = 1/`r(N)' {
				local theName		= name`survey'[`i']
		    	local theRename 	= name[`i']
				local theLabel		= label[`i']
				local theChoices	= choices[`i']
				local theRecode		= recode`survey'[`i']

				local allRenames 	= `"`allRenames' "rename `theName' `theRename'""'
				local allLabels 	= `"`allLabels' "label var `theName' `theLabel'""'
				local allChoices 	= `"`allChoices' "label val `theName' `theChoices'""'
				local allRecodes 	= `"`allRecodes' "recode `theName' `theRecode'""'
			}

		// Loop over choices sheet and accumulate vallab definitions

			// Prepare list of value labels needed.

				drop if choices == ""
				cap duplicates drop choices, force

				count
				if `r(N)' == 1 {
					local theValueLabels = vallab[1]
				}
				else {
					forvalues i = 1/`r(N)' {
						local theNextValLab  = vallab[`i']
						local theValueLabels `theValueLabels' `theNextValLab'
					}
				}

			// Prepare list of values for each value label.

				import excel `using', first clear sheet(choices)
					tempfile choices
						save `choices', replace

				foreach theValueLabel in `theValueLabels' {
					use `choices', clear
					keep if list_name == "`theValueLabel'"
					local theLabelList "`theValueLabel'"
						count
						local n_vallabs = `r(N)'
						forvalues i = 1/`n_vallabs' {
							local theNextValue = value[`i']
							local theNextLabel = label[`i']
							local theLabelList_`theValueLabel' `" `theLabelList_`theValueLabel'' `theNextValue' "`theNextLabel'" "'
						}
				}

	restore

		// Define value labels

			foreach theValueLabel in `theValueLabels' {
				label def `theValueLabel' `theLabelList_`theValueLabel'', replace
				}

				destring `theVarNames', replace

				local n_labels : word count `theValueLabelNames'
				if `n_labels' == 1 {
					label val `theVarNames' `theValueLabelNames'
					}
				else {
					forvalues i = 1/`n_labels' {
						local theNextVarname : word `i' of `theVarNames'
						local theNextValLab  : word `i' of `theValueLabelNames'
						label val `theNextVarname' `theNextValLab'
						}
					}

end

// Append subroutine –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

cap program drop iecodebook_append
	program 	 iecodebook_append

	syntax [anything] [using] , surveys(string asis) [template]

	// Template setup

		if "`template'" != "" {
			// create empty codebook
			preserve
				clear
				set obs 1
				gen survey = 0
					label var survey "Survey"
				iecodebook export `using'
			restore
			// append one codebook per survey
			local x = 0
			foreach survey in `surveys' {
				local ++x
				local filepath : word `x' of `anything'
				iecodebook export `filepath' `using' , template(`survey')
			}
		}

end


// TESTING

	/* Create template

		sysuse auto.dta , clear
			save "/users/bbdaniels/desktop/dta2.dta" , replace

		gen check = (rnormal() > 0)
			label def yesno 0 "No" 1 "Yes"
			label val check yesno

		iecodebook append ///
			"/users/bbdaniels/desktop/dta.dta" ///
			"/users/bbdaniels/desktop/dta2.dta" ///
		using "/users/bbdaniels/desktop/test.xlsx" ///
		, surveys(s1 s2) template

	*/

	// Apply codebook

		use "/users/bbdaniels/desktop/dta2.dta" , clear

		iecodebook apply ///
			using "/users/bbdaniels/desktop/test_meta.xlsx" ///
			, survey(s1)

	-


// Have a lovely day!