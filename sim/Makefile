# System-level DMA testbench — Questa / ModelSim
# Run from sim/:   make golden | sim | sim-gui | clean
#
# MODELSIM_ENV= to skip sourcing the environment file.
# GUI_FIX=0   to disable the X11-over-SSH display fixes.

PYTHON         ?= python3
OUT_DIR        ?= out
SCENARIO       ?= scenarios/example.csv
SIM_DIR        := $(CURDIR)
MODELSIM_ENV   ?= /vol/eecs392/env/modelsim.env
MODELSIM_SHELL ?= tcsh
VSIM           ?= vsim
VSIM_DO        := dma_sim.do
TRANSCRIPT     ?= transcript

GUI_FIX ?= 1
ifeq ($(GUI_FIX),1)
GUI_FIX_TCSH := setenv LIBGL_ALWAYS_SOFTWARE 1; setenv QT_XCB_GL_INTEGRATION none; setenv QT_X11_NO_MITSHM 1;
else
GUI_FIX_TCSH :=
endif

.PHONY: golden sim sim-gui verify clean

# Generate golden reference files from the Python model
golden:
	$(PYTHON) run_golden.py $(SCENARIO) $(OUT_DIR)

# Batch simulation (no GUI)
sim: golden
ifneq ($(strip $(MODELSIM_ENV)),)
	$(MODELSIM_SHELL) -c 'if ( -f "$(MODELSIM_ENV)" ) source "$(MODELSIM_ENV)"; \
	    cd "$(SIM_DIR)"; setenv TB_BATCH 1; $(VSIM) -c -do $(VSIM_DO)'
else
	bash -lc 'cd "$(SIM_DIR)" && TB_BATCH=1 $(VSIM) -c -do $(VSIM_DO)'
endif

# GUI simulation
sim-gui: golden
ifneq ($(strip $(MODELSIM_ENV)),)
	$(MODELSIM_SHELL) -c 'if ( -f "$(MODELSIM_ENV)" ) source "$(MODELSIM_ENV)"; \
	    cd "$(SIM_DIR)"; $(GUI_FIX_TCSH) $(VSIM) -do $(VSIM_DO)'
else
ifeq ($(GUI_FIX),1)
	bash -lc 'export LIBGL_ALWAYS_SOFTWARE=1 QT_XCB_GL_INTEGRATION=none QT_X11_NO_MITSHM=1; \
	    cd "$(SIM_DIR)" && $(VSIM) -do $(VSIM_DO)'
else
	bash -lc 'cd "$(SIM_DIR)" && $(VSIM) -do $(VSIM_DO)'
endif
endif

# Batch simulation with transcript verification checks
verify: sim
	@echo "Checking simulation transcript: $(TRANSCRIPT)"
	@grep -q "TB: ring empty after" $(TRANSCRIPT)
	@grep -q "TB: check_mem PASS" $(TRANSCRIPT)
	@grep -q "TB: check_sram PASS" $(TRANSCRIPT)
	@grep -q "TB: check_irq PASS" $(TRANSCRIPT)
	@grep -q "\*\*\* TB PASS \*\*\*" $(TRANSCRIPT)
	@if grep -Eiq "mismatch|fatal|timed out" $(TRANSCRIPT); then \
		echo "Verification FAILED: found mismatch/fatal/timeout in $(TRANSCRIPT)"; \
		exit 1; \
	fi
	@echo "Verification PASS for SCENARIO=$(SCENARIO)"

clean:
	rm -f transcript vsim.wlf
	rm -rf work
	rm -rf $(OUT_DIR)
