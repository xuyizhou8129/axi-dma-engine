# Simple Makefile - just calls shell script
.PHONY: clean smoke run

smoke:
	@bash scripts/run_sim.sh

run:
	@bash scripts/run_sim.sh -nogui

clean:
	@rm -rf xcelium.d xrun.log xrun.history waves.shm .simvision *.vpd *.fsdb
