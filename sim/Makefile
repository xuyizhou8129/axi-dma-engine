# System-level DMA testbench — Questa / ModelSim
# Run from sim/:   make golden | sim | sim-all | sim-gui | clean
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

GUI_FIX ?= 1
ifeq ($(GUI_FIX),1)
GUI_FIX_TCSH := setenv LIBGL_ALWAYS_SOFTWARE 1; setenv QT_XCB_GL_INTEGRATION none; setenv QT_X11_NO_MITSHM 1;
else
GUI_FIX_TCSH :=
endif

.PHONY: golden sim sim-gui sim-all clean

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

# Batch simulation for every scenarios/*.csv. Each iteration runs golden + vsim;
# OUT_DIR (default out/) is overwritten each time. Writes $(OUT_DIR)/sim-all-report.txt
# (PASS/FAIL per scenario + timestamps). Exits with status 1 if any scenario failed.
sim-all:
	bash -lc 'shopt -s nullglob; cd "$(SIM_DIR)"; \
	  mkdir -p "$(OUT_DIR)"; \
	  rep="$(OUT_DIR)/sim-all-report.txt"; \
	  echo "sim-all started $$(date -Iseconds)" > "$$rep"; \
	  pass=0; fail=0; \
	  for f in scenarios/*.csv; do \
	    echo "=== sim-all: $$f ==="; \
	    if $(MAKE) sim SCENARIO="$$f"; then \
	      echo "$$f PASS $$(date -Iseconds)" >> "$$rep"; \
	      pass=$$((pass + 1)); \
	    else \
	      echo "$$f FAIL $$(date -Iseconds)" >> "$$rep"; \
	      fail=$$((fail + 1)); \
	    fi; \
	  done; \
	  summ="--- summary: $$pass pass, $$fail fail ---"; \
	  echo "$$summ" >> "$$rep"; \
	  echo "$$summ"; \
	  case "$$rep" in /*) echo "Report: $$rep";; *) echo "Report: $$(pwd)/$$rep";; esac; \
	  test $$fail -eq 0'

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

clean:
	rm -f transcript vsim.wlf
	rm -rf work
	rm -rf $(OUT_DIR)
