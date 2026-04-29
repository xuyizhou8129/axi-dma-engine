# System-level DMA testbench — Questa / ModelSim
# Run from sim/:   make golden | sim | sim-all | sim-gui | clean
#
# MODELSIM_ENV= to skip sourcing the environment file.
# GUI_FIX=0   to disable the X11-over-SSH display fixes.

PYTHON         ?= python3
OUT_DIR        ?= out
SCENARIO       ?= scenarios/example.csv
ERR_TEST       ?= overflow_sets_error
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

.PHONY: golden sim sim-gui sim-all sim-expect-error sim-error sim-error-all clean

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

# Like sim, but sets EXPECT_ERROR=1 — for scenarios that intentionally trigger irq_rm_error.
sim-expect-error: golden
ifneq ($(strip $(MODELSIM_ENV)),)
	$(MODELSIM_SHELL) -c 'if ( -f "$(MODELSIM_ENV)" ) source "$(MODELSIM_ENV)"; \
	    cd "$(SIM_DIR)"; setenv TB_BATCH 1; setenv EXPECT_ERROR 1; $(VSIM) -c -do $(VSIM_DO)'
else
	bash -lc 'cd "$(SIM_DIR)" && TB_BATCH=1 EXPECT_ERROR=1 $(VSIM) -c -do $(VSIM_DO)'
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
	    if grep -q "^# EXPECT_ERROR=1" "$$f"; then \
	      tgt=sim-expect-error; \
	    else \
	      tgt=sim; \
	    fi; \
	    if $(MAKE) $$tgt SCENARIO="$$f"; then \
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

# Batch simulation for directed error tests in tb_error_top.sv.
# Usage: make sim-error ERR_TEST=overflow_sets_error
sim-error:
ifneq ($(strip $(MODELSIM_ENV)),)
	$(MODELSIM_SHELL) -c 'if ( -f "$(MODELSIM_ENV)" ) source "$(MODELSIM_ENV)"; \
	    cd "$(SIM_DIR)"; setenv TB_BATCH 1; setenv ERR_TEST "$(ERR_TEST)"; $(VSIM) -c -do dma_error_sim.do'
else
	bash -lc 'cd "$(SIM_DIR)" && TB_BATCH=1 ERR_TEST="$(ERR_TEST)" $(VSIM) -c -do dma_error_sim.do'
endif

# Run all directed error tests listed in scenarios/error_tests.txt.
# Writes $(OUT_DIR)/sim-error-report.txt. Add a new test case name there;
# no Makefile edit needed — mirrors how sim-all reads scenarios/*.csv.
sim-error-all:
	bash -lc 'cd "$(SIM_DIR)"; mkdir -p "$(OUT_DIR)"; \
	  rep="$(OUT_DIR)/sim-error-report.txt"; \
	  echo "sim-error-all started $$(date -Iseconds)" > "$$rep"; \
	  pass=0; fail=0; \
	  while IFS= read -r tc || [ -n "$$tc" ]; do \
	    [ -z "$$tc" ] && continue; \
	    echo "=== sim-error-all: $$tc ==="; \
	    if $(MAKE) sim-error ERR_TEST="$$tc"; then \
	      echo "$$tc PASS $$(date -Iseconds)" >> "$$rep"; \
	      pass=$$((pass + 1)); \
	    else \
	      echo "$$tc FAIL $$(date -Iseconds)" >> "$$rep"; \
	      fail=$$((fail + 1)); \
	    fi; \
	  done < scenarios/error_tests.txt; \
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