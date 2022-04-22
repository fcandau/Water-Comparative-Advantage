
clear all
global path "C:\Users\schli\Desktop\sauvegarde_code_soumissions\Data_code_replication_v2"

**********************************************************
******************Part I : Selection Data*****************
**********************************************************

****************** I. Selection of countries, products and creation of intermediate table (population)

    use "$path\raw_data\spatialproductdata.dta", clear
        keep iso3 Pop_i AL_i_km2
            drop if Pop_i<5000000 & AL_i_km2<10000
                keep iso3
                    duplicates drop
        save "$path\prepa_data\ctry_list.dta", replace
		
    use "$path\prepa_data\waterindicators.dta", clear
        keep hs4
            duplicates drop
                drop if hs4==1801 | hs4==5201
        save "$path\prepa_data\pdt_list.dta", replace

    use "$path\raw_data\spatialproductdata.dta", clear
        keep iso3 Pop_i
                    duplicates drop
        save "$path\prepa_data\population_country.dta", replace


******************II. Trade data for estimation

    use "$path\raw_data\bilateraldata.dta", clear
        rename iso3_im iso3
            merge m:1 iso3 using "$path\prepa_data\ctry_list.dta"
                keep if _merge==3
                    drop _merge
        rename iso3 iso3_im
        rename iso3_ex iso3
            merge m:1 iso3 using "$path\prepa_data\ctry_list.dta"
                keep if _merge==3
                    drop _merge
        rename iso3 iso3_ex
            merge m:1 hs4 using "$path\prepa_data\pdt_list.dta"
                keep if _merge==3
                    drop _merge
                drop if iso3_ex==iso3_im
        save "$path\prepa_data\estimation.dta", replace


**************************************************************************************
************************Part II. Preparation Data Vulnerability Indicator*************
**************************************************************************************

*****Country_list****
***Treatment for Botswana, Namibia, Lesotho and South Africa:
***trade data include the total of SACU not by members in BACI database 

use "$path\prepa_data\ctry_list.dta", clear
	set obs 116
		replace iso3 = "BWA" in 116
	set obs 117
		replace iso3 = "NAM" in 117
	set obs 118
		replace iso3 = "LSO" in 118
	set obs 119
		replace iso3 = "SWZ" in 119
		
save "$path\prepa_data\ctry_list2.dta", replace

		
*********I. Readiness
	

	import delimited "$path\raw_data\readiness.csv", varnames(1) clear
		foreach v of var v* {
			local lbl : var label `v'
			local lbl = strtoname("`lbl'")
				rename `v' read`lbl'
}
		reshape long read_, i(iso3 name) j(year)
			rename read_ read
			keep if year>1994 & year<2006
		collapse (mean) read, by (iso3)
			gen year=2000
		merge 1:1 iso3 using "$path\prepa_data\ctry_list2.dta"
		keep if _merge==3
		drop _merge

	save "$path\prepa_data\readiness.dta", replace
		
	
*********II. Stock of capital

	import excel "$path\raw_data\pwt90.xlsx", sheet("Data") firstrow clear	
			keep year countrycode pop ck
				duplicates drop
			rename countrycode iso3
			rename ck capital
			keep if year>1994 & year<2006
		collapse (mean) capital pop, by (iso3)
			gen year=2000
		merge 1:1 iso3 using "$path\prepa_data\ctry_list2.dta"
			keep if _merge==3
			drop _merge
		gen capital_hab=capital/pop
			keep iso3 year capital_hab
	save "$path\prepa_data\capital.dta", replace
	
****III. Vulnerability indicator (PVCCI from Ferdi)***
	
import delimited "$path\raw_data\pvcci.csv", delimiter(";") clear		
		rename iso iso3
		keep iso3 pvcci
		destring pvcci, dpcomma replace force
		merge 1:1 iso3 using "$path\prepa_data\ctry_list2.dta"
		keep if _merge==3
		drop _merge
		gen year=2000
	save "$path\prepa_data\pvcci.dta", replace
	
		merge 1:1 iso3 year using "$path\prepa_data\capital.dta"
		drop _merge	
		merge 1:1 iso3 year using "$path\prepa_data\readiness.dta"
		drop _merge
	save "$path\prepa_data\indicators.dta", replace
	
erase "$path\prepa_data\readiness.dta"
erase "$path\prepa_data\pvcci.dta"
erase "$path\prepa_data\capital.dta"
erase "$path\prepa_data\ctry_list2.dta"	
erase "$path\prepa_data\ctry_list.dta"
erase "$path\prepa_data\pdt_list.dta"
		
***Treatment for Botswana, Namibia, Lesotho and South Africa:
***trade data include the total of SACU not by members in BACI database 
		keep if iso3=="ZAF" | iso3=="BWA"| iso3=="NAM"| iso3=="LSO"| iso3=="SWZ"
			collapse (mean) capital read pvcci
				gen iso3="SACU"
					append using "$path\prepa_data\indicators.dta"
		drop if iso3=="ZAF" | iso3=="BWA"| iso3=="NAM"| iso3=="LSO"| iso3=="SWZ"
			replace iso3="ZAF" if iso3=="SACU"
			replace year=2000 if iso3=="ZAF"	

*****Creation of categories for each indicator for gravity estimations			
local indic "capital_hab read pvcci"
foreach x of local indic {
		summarize `x', detail
			egen p25_`x' = pctile(`x'), p(25)
			egen p50_`x' = pctile(`x'), p(50)
			egen p75_`x' = pctile(`x'), p(75)
			gen cat1_`x' = 0
			replace cat1_`x' = 1 if `x' < p25_`x'
			gen cat2_`x' = 0
			replace cat2_`x' = 1 if `x' < p50_`x' & `x' >= p25_`x'
			gen cat3_`x' = 0
			replace cat3_`x' = 1 if `x' < p75_`x' & `x' >= p50_`x'
			gen cat4_`x' = 0
			replace cat4_`x' = 1 if `x' >= p75_`x' 

		drop p25_`x' p50_`x' p75_`x'	
		
	gen cat_`x'=.
		replace cat_`x'=1 if cat1_`x'==1
		replace cat_`x'=2 if cat2_`x'==1
		replace cat_`x'=3 if cat3_`x'==1
		replace cat_`x'=4 if cat4_`x'==1
		replace cat_`x'=. if `x'==.		
	drop cat1_`x' cat2_`x' cat3_`x'	cat4_`x'	

}	

	save "$path\prepa_data\indicators.dta", replace
	
		rename iso3 iso3_ex
			merge 1:m iso3_ex using "$path\prepa_data\estimation.dta"
		keep if _merge==3
			drop _merge
			
local indic "capital_hab read pvcci"
foreach x of local indic {
		rename cat_`x' cat_`x'_ex
}

	save "$path\prepa_data\estimation_indicator.dta", replace 
	
		rename iso3_im iso3
			merge m:1 iso3 using "$path\prepa_data\indicators.dta" 
		rename iso3 iso3_im
		keep if _merge==3
		drop _merge
		
local indic "capital_hab read pvcci"
foreach x of local indic {
		rename cat_`x' cat_`x'_im
}

drop popcount_l
	order year iso3_ex iso3_im hs4 X_mean
	save "$path\prepa_data\estimation_indicator.dta", replace	

***Treatment for Botswana, Namibia, Lesotho and South Africa:
***trade data include the total of SACU not by members in BACI database 
			
    use "$path\prepa_data\waterindicators.dta", clear
	sort iso3
		replace iso3="ZAF" if iso3=="BWA"| iso3=="NAM"| iso3=="LSO"| iso3=="SWZ"
        collapse (sum) Lhat_lk simhar_Lhat_lk, by(iso3 hs4)
            foreach v of varlist iso3 Lhat_lk simhar_Lhat_lk {
                rename `v' `v'_ex
                }
            merge 1:m iso3_ex hs4 using "$path\prepa_data\estimation_indicator.dta"
                keep if _merge==3
                    drop _merge
        save "$path\prepa_data\temp.dta", replace

    use "$path\prepa_data\waterindicators.dta", clear
	sort iso3
	replace iso3="ZAF" if iso3=="BWA"| iso3=="NAM"| iso3=="LSO"| iso3=="SWZ"
        collapse (sum) Lhat_lk simhar_Lhat_lk, by(iso3 hs4)
            foreach v of varlist iso3 Lhat_lk simhar_Lhat_lk {
                rename `v' `v'_im
                }
            merge 1:m iso3_im hs4 using "$path\prepa_data\temp.dta"
                keep if _merge==3
                    drop _merge

                gen ln_Lhat_lk_ex=ln(Lhat_lk_ex)
                    replace ln_Lhat_lk_ex=0 if ln_Lhat_lk_ex==.
                gen ln_Lhat_lk_im=ln(Lhat_lk_im)
                    replace ln_Lhat_lk_im=0 if ln_Lhat_lk_im==.
				
					order year iso3_ex iso3_im hs4 X_mean Lhat_lk_ex Lhat_lk_im ln_Lhat_lk_ex ln_Lhat_lk_im
		
	save "$path\prepa_data\estimation_waterindicator_indicator.dta", replace
	saveold "$path\prepa_data\estimation_waterindicator_indicator.dta", replace

erase "$path\prepa_data\temp.dta"
erase "$path\prepa_data\estimation_indicator.dta"

******************************************************
****Country names for categories table (Appendix)****
******************************************************
	import delimited "$path\raw_data\pvcci.csv", delimiter(";") clear		
		keep iso country
		rename iso iso3
	save "$path\prepa_data\country_name.dta", replace

****Output classification for vulnerability indicator by country (appendix)
			forval t=1/4 {
local indic "capital_hab read pvcci"
foreach x of local indic {

	use "$path\prepa_data\indicators.dta", clear
		keep cat_`x' iso3
			duplicates drop
		merge 1:m iso3 using "$path\prepa_data\country_name.dta"
			keep if _merge==3
			drop _merge
			sort cat_`x'
			gen `x'=country if cat_`x'==`t'
			keep iso3 `x'
			drop if `x'==""
			sort `x'
	save "$path\prepa_data\temp_`x'.dta", replace
}	

	merge using "$path\prepa_data\temp_capital_hab.dta"
	drop _merge
	merge using "$path\prepa_data\temp_read.dta"
	drop _merge


    label var pvcci "Vulnerability Indicator"
	label var capital_hab "Capital per inhabitant Indicator"
	label var read "Readiness Indicator"
texsave pvcci capital_hab read using "$path\results\Categorie`t'.tex", title(Countries included in category `t' for each variable) varlabels nofix replace
	

erase "$path\prepa_data\temp_capital_hab.dta"
erase "$path\prepa_data\temp_read.dta"
}

erase "$path\prepa_data\indicators.dta"


******************************************************************************
*********Part II: Estimations importer and exporter and Debaere (Table 2)******
******************************************************************************

******1. All regression

	use "$path\prepa_data\estimation_waterindicator_indicator.dta", clear
	
******Creating Fixed Effetcs

	            cap egen imp=group(iso3_im)
                cap egen exp=group(iso3_ex)
                cap egen pdt=group(hs4)
				rename Lhat_lk_ex Lhat_ik_ex
				rename Lhat_lk_im Lhat_ik_im
				rename ln_Lhat_lk_ex ln_Lhat_ik_ex
				rename ln_Lhat_lk_im ln_Lhat_ik_im

******Replacing trade = 0 if no production

				replace X_mean=0 if Lhat_ik_ex==0

				
******************Change labels				
	
				label variable ln_Lhat_ik_ex   "Exp. Water Indic." 
				label variable ln_Lhat_ik_im   "Imp. Water Indic." 
				label variable X_mean   "Flow" 


    eststo spec_1:ppmlhdfe X_mean ln_Lhat_ik_ex, a(imp#pdt exp#imp exp) d(FX) nolog
						drop FX
							
					quietly estadd local FE_imp "No", replace
					quietly estadd local FE_exp "Yes", replace
					quietly estadd local FE_bil "Yes", replace
					quietly estadd local FE_pdt "No", replace
					quietly estadd local FE_imp_pdt "Yes", replace
					quietly estadd local FE_exp_pdt "No", replace

					
    eststo spec_2:ppmlhdfe X_mean ln_Lhat_ik_im, a(imp exp#imp exp#pdt) d(FX) nolog
                            drop FX 
							
					quietly estadd local FE_imp "Yes", replace
					quietly estadd local FE_exp "No", replace
					quietly estadd local FE_bil "Yes", replace
					quietly estadd local FE_pdt "No", replace
					quietly estadd local FE_imp_pdt "No", replace
					quietly estadd local FE_exp_pdt "Yes", replace					


    eststo spec_3:ppmlhdfe X_mean ln_Lhat_ik_ex ln_Lhat_ik_im, a(imp exp exp#imp pdt) d(FX) nolog
                            drop FX
						
					quietly estadd local FE_imp "Yes", replace
					quietly estadd local FE_exp "Yes", replace
					quietly estadd local FE_bil "Yes", replace
					quietly estadd local FE_pdt "Yes", replace
					quietly estadd local FE_imp_pdt "No", replace
					quietly estadd local FE_exp_pdt "No", replace	
					
    use "$path\prepa_data\debaere.dta", clear
        rename iso3_ex iso3_im
        rename lnWDeb_grbl_ex lnWDeb_grbl_im
            merge 1:m iso3_im hs4 using "$path\prepa_data\estimation.dta"
                keep if _merge==3
                    drop _merge
            merge m:1 iso3_ex hs4 using "$path\prepa_data\debaere.dta"
                keep if _merge==3
                    drop _merge
					
******************Change labels				
	
				label variable lnWDeb_grbl_ex   "Exp. TRWR" 
				label variable lnWDeb_grbl_im   "Imp. TRWR"

                cap egen imp=group(iso3_im)
                cap egen exp=group(iso3_ex)
                cap egen pdt=group(hs4)
				

    eststo spec_4: ppmlhdfe X_mean lnWDeb_grbl_ex, a(imp#pdt exp#imp exp) nolog
					quietly estadd local FE_imp "No", replace
					quietly estadd local FE_exp "Yes", replace
					quietly estadd local FE_bil "Yes", replace
					quietly estadd local FE_pdt "No", replace
					quietly estadd local FE_imp_pdt "Yes", replace
					quietly estadd local FE_exp_pdt "No", replace

    eststo spec_5: ppmlhdfe X_mean lnWDeb_grbl_im, a(imp exp#imp exp#pdt) nolog
					quietly estadd local FE_imp "Yes", replace
					quietly estadd local FE_exp "No", replace
					quietly estadd local FE_bil "Yes", replace
					quietly estadd local FE_pdt "No", replace
					quietly estadd local FE_imp_pdt "No", replace
					quietly estadd local FE_exp_pdt "Yes", replace	
					
    eststo spec_6: ppmlhdfe X_mean lnWDeb_grbl_ex lnWDeb_grbl_im, a(imp exp exp#imp pdt) nolog
					quietly estadd local FE_imp "Yes", replace
					quietly estadd local FE_exp "Yes", replace
					quietly estadd local FE_bil "Yes", replace
					quietly estadd local FE_pdt "Yes", replace
					quietly estadd local FE_imp_pdt "No", replace
					quietly estadd local FE_exp_pdt "No", replace	

#delimit ;
esttab spec_1 spec_2 spec_3 spec_4 spec_5 spec_6 using "$path/results/table2.tex", 
	replace label se star(* 0.10 ** 0.05 *** 0.01)
	title("Gravity Equation Regression by Group") 
	s(FE_imp FE_exp FE_pdt FE_bil FE_imp_pdt FE_exp_pdt N ll r2_p,
	label("Importer FE" "Exporter FE" "Product FE" "Bilateral FE" "Importer-Product FE" "Exporter-Product FE" "Observations" "Log-Likelihood" "Pseudo R2"))
	 addnotes("The dependant variable is the mean of bilateral flows between 1995 and 2005.")
	;
#delimit cr	

******************************************************************************
*************Part III: Estimations importer and exporter (Table 3)*************
******************************************************************************

 use "$path\prepa_data\estimation_waterindicator_indicator.dta", clear
		
******Creating Fixed Effetcs

	            cap egen imp=group(iso3_im)
                cap egen exp=group(iso3_ex)
                cap egen pdt=group(hs4)
				rename Lhat_lk_ex Lhat_ik_ex
				rename Lhat_lk_im Lhat_ik_im
				rename ln_Lhat_lk_ex ln_Lhat_ik_ex
				rename ln_Lhat_lk_im ln_Lhat_ik_im
				
******Replacing trade = 0 if no production

				replace X_mean=0 if Lhat_ik_ex==0

				
******************Change labels					
				label variable ln_Lhat_ik_ex   "Exp. Water Indic." 
				label variable ln_Lhat_ik_im   "Imp. Water Indic." 
				label variable X_mean   "Flow"
				label variable cat_capital_hab_ex   "Exp. Capital Indic"
				label variable cat_read_ex   "Exp. Readiness Indic"
				label variable cat_pvcci_ex   "Exp. PVCCI Indic"
				label variable cat_capital_hab_im   "Imp. Capital Indic"
				label variable cat_read_im   "Imp. Readiness Indic"
				label variable cat_pvcci_im   "Imp. PVCCI Indic"
					
***1.Readiness interaction
    eststo spec_1:ppmlhdfe X_mean c.ln_Lhat_ik_ex##cat_read_ex c.ln_Lhat_ik_im, a(imp exp exp#imp pdt) nolog
	
					quietly estadd local FE_imp "Yes", replace
					quietly estadd local FE_exp "Yes", replace
					quietly estadd local FE_bil "Yes", replace
					quietly estadd local FE_pdt "Yes", replace
					quietly estadd local FE_imp_pdt "No", replace
					quietly estadd local FE_exp_pdt "No", replace

***2.Capital interaction
    eststo spec_2:ppmlhdfe X_mean c.ln_Lhat_ik_ex##cat_capital_hab_ex c.ln_Lhat_ik_im, a(imp exp exp#imp pdt) nolog
							
					quietly estadd local FE_imp "Yes", replace
					quietly estadd local FE_exp "Yes", replace
					quietly estadd local FE_bil "Yes", replace
					quietly estadd local FE_pdt "Yes", replace
					quietly estadd local FE_imp_pdt "No", replace
					quietly estadd local FE_exp_pdt "No", replace
					
***3.PVCCI interaction
    eststo spec_3:ppmlhdfe X_mean c.ln_Lhat_ik_ex##cat_pvcci_ex c.ln_Lhat_ik_im, a(imp exp exp#imp pdt) nolog
							
					quietly estadd local FE_imp "Yes", replace
					quietly estadd local FE_exp "Yes", replace
					quietly estadd local FE_bil "Yes", replace
					quietly estadd local FE_pdt "Yes", replace
					quietly estadd local FE_imp_pdt "No", replace
					quietly estadd local FE_exp_pdt "No", replace

#delimit ;
esttab spec_3 spec_2 spec_1 using "$path/results/table3.tex", 
	replace label se star(* 0.10 ** 0.05 *** 0.01) noomit
	title("Gravity Equation Regression by Group (Vulnerability Indicator)") 
	s(FE_imp FE_exp FE_pdt FE_bil FE_imp_pdt FE_exp_pdt N ll r2_p,
	label("Importer FE" "Exporter FE" "Product FE" "Bilateral FE" "Importer-Product FE" "Exporter-Product FE" "Observations" "Log-Likelihood" "Pseudo R2"))
	 addnotes("The dependant variable is the mean of bilateral flows between 1995 and 2005. The capital indicator is the capital per inhabitant.")
	;
#delimit cr	

************************************************************
***************Part IV : Simulations************************
************************************************************


****************** Computation trade values simulated

	use "$path\prepa_data\estimation_waterindicator_indicator.dta", clear

******Creating Fixed Effetcs

	            cap egen imp=group(iso3_im)
                cap egen exp=group(iso3_ex)
                cap egen pdt=group(hs4)
				rename Lhat_lk_ex Lhat_ik_ex
				rename Lhat_lk_im Lhat_ik_im
				rename ln_Lhat_lk_ex ln_Lhat_ik_ex
				rename ln_Lhat_lk_im ln_Lhat_ik_im

******Replacing trade = 0 if no production

				replace X_mean=0 if Lhat_ik_ex==0
				
****Estimations to obtain coefficients by category				
			ppmlhdfe X_mean c.ln_Lhat_ik_ex##cat_pvcci_ex c.ln_Lhat_ik_im, a(imp pdt exp#imp exp, savefe) d(FX) nolog				
				predict X_hat_ijk
					matrix coeff = e(b)
                    gen lambda1=coeff[1,1]
***Coefficent lambda2 equal to the first coefficient because no significant
                    gen lambda2=coeff[1,1]
                    gen lambda3=coeff[1,8]+ coeff[1,1]
                    gen lambda4=coeff[1,9]+ coeff[1,1]
					gen lambda5=coeff[1,10]
                    gen fe0=coeff[1,11]								

****Compute predicted trade and simulations trade            
            rename X_mean X_mean_ik
            rename X_hat_ijk X_hat_ik
			rename simhar_Lhat_lk_ex simhar_Lhat_ik_ex
			rename simhar_Lhat_lk_im simhar_Lhat_ik_im

				gen X_hat_ik_2=.
				gen X_simhar_ik=.
				gen cat=.
				
			replace __hdfe1__=0 if __hdfe1__==.
			replace __hdfe2__=0 if __hdfe2__==.
			replace __hdfe3__=0 if __hdfe3__==.
			replace __hdfe4__=0 if __hdfe4__==.


			forvalues i = 1(1)4 {
				replace X_hat_ik_2 =  Lhat_ik_im^lambda5*Lhat_ik_ex^lambda`i'*exp(fe0+__hdfe1__+__hdfe2__+__hdfe3__+__hdfe4__) if cat_pvcci_ex==`i'
                replace X_simhar_ik=simhar_Lhat_ik_im^lambda5*simhar_Lhat_ik_ex^lambda`i'*exp(fe0+__hdfe1__+__hdfe2__+__hdfe3__+__hdfe4__) if cat_pvcci_ex==`i'
				replace cat=`i' if cat_pvcci_ex==`i'
 }

                    collapse (sum) X_mean_ik X_hat_ik_2 X_simhar_ik, by(iso3_ex hs4)
						rename X_hat_ik_2 X_hat_ik
        save "$path\prepa_data\simulations.dta", replace

            collapse (sum) X_mean_ik X_hat_ik X_simhar_ik, by(hs4)
                rename X_mean_ik X_mean_k
                rename X_hat_ik X_hat_k
                rename X_simhar_ik X_simhar_k
                    merge 1:m hs4 using "$path\prepa_data\simulations.dta"
                        drop _merge
        save "$path\prepa_data\simulations.dta", replace

            collapse (sum) X_mean_ik X_hat_ik X_simhar_ik, by(iso3_ex)
                rename X_mean_ik X_mean_i
                rename X_hat_ik X_hat_i
                rename X_simhar_ik X_simhar_i
                    merge 1:m iso3 using "$path\prepa_data\simulations.dta"
                        drop _merge
        save "$path\prepa_data\simulations.dta", replace

            collapse (sum) X_mean_ik X_hat_ik X_simhar_ik
                rename X_mean_ik X_mean
                rename X_hat_ik X_hat
                rename X_simhar_ik X_simhar
                    cross using "$path\prepa_data\simulations.dta"
        save "$path\prepa_data\simulations.dta", replace

****Compute RCA and simulations of RCA
            gen RCA_ik=(X_mean_ik/X_mean_k)/(X_mean_i/X_mean)
            gen RCAhat_ik=(X_hat_ik/X_hat_k)/(X_hat_i/X_hat)
            gen RCAsimhar_ik=(X_simhar_ik/X_simhar_k)/(X_simhar_i/X_simhar)
        save "$path\prepa_data\simulations.dta", replace


use "$path\prepa_data\estimation_waterindicator_indicator.dta", clear
	keep cat_pvcci_ex iso3_ex
	duplicates drop
		merge 1:m iso3_ex using "$path\prepa_data\simulations.dta"
			drop _merge
			 rename cat_pvcci_ex cat
        save "$path\prepa_data\simulations.dta", replace

			 
export delimited using "$path\simulations.csv", replace


************************************************************
***************************END******************************
************************************************************

