# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

	
sim_veril: ./build/lio_i8080_0/sim_verilator/coverage.dat
	cd ./build/lio_i8080_0/sim_verilator; verilator_coverage --annotate coverage_reports ./coverage.dat; cd ../../..

./build/lio_i8080_0/sim_verilator/coverage.dat:
	fusesoc --cores-root=.. run --target sim_verilator --no-export lio_i8080 

sim_icar:
	fusesoc --cores-root=.. run --target sim_iverilog  --no-export lio_i8080 

lint_veril: 
	fusesoc --cores-root=.. run --target lint --tool verilator --no-export lio_i8080 

lint_verib: 
	fusesoc --cores-root=.. run --target lint --tool veriblelint --no-export lio_i8080 
 
clean:
	rm -Rf ./build
	

