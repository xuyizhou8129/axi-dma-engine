# sys_mem TB + golden vectors (cwd for vsim = sim/)

PYTHON   ?= python3
SCENARIO ?= test0
SCENARIOS := $(patsubst scenarios/%.csv,%,$(wildcard scenarios/*.csv))
SCENARIO_OUT := $(CURDIR)/out/$(SCENARIO)
SIM_DIR  := $(abspath $(CURDIR)/sim)
MODELSIM_ENV   ?= /vol/eecs392/env/modelsim.env
MODELSIM_SHELL ?= tcsh
VSIM     ?= vsim
VSIM_DO  := sys_mem_sim.do

GUI_FIX  ?= 1
ifeq ($(GUI_FIX),1)
GUI_FIX_TCSH := setenv LIBGL_ALWAYS_SOFTWARE 1; setenv QT_XCB_GL_INTEGRATION none; setenv QT_X11_NO_MITSHM 1;
else
GUI_FIX_TCSH :=
endif

.PHONY: golden sim sim-gui sim-all golden-all clean \
        $(addprefix _sim-,$(SCENARIOS)) $(addprefix _golden-,$(SCENARIOS))

# --- Single scenario targets (default SCENARIO=test0) ---

golden:
	$(PYTHON) csv_golden_runner.py scenarios/$(SCENARIO).csv $(SCENARIO_OUT)

sim: golden
ifneq ($(strip $(MODELSIM_ENV)),)
	$(MODELSIM_SHELL) -c 'if ( -f "$(MODELSIM_ENV)" ) source "$(MODELSIM_ENV)"; cd "$(SIM_DIR)"; setenv TB_BATCH 1; setenv SCENARIO_OUT "$(SCENARIO_OUT)"; $(VSIM) -c -do $(VSIM_DO)'
else
	bash -lc 'cd "$(SIM_DIR)" && TB_BATCH=1 SCENARIO_OUT="$(SCENARIO_OUT)" $(VSIM) -c -do $(VSIM_DO)'
endif

sim-gui: golden
ifneq ($(strip $(MODELSIM_ENV)),)
	$(MODELSIM_SHELL) -c 'if ( -f "$(MODELSIM_ENV)" ) source "$(MODELSIM_ENV)"; cd "$(SIM_DIR)"; $(GUI_FIX_TCSH) setenv SCENARIO_OUT "$(SCENARIO_OUT)"; $(VSIM) -do $(VSIM_DO)'
else
ifeq ($(GUI_FIX),1)
	bash -lc 'export LIBGL_ALWAYS_SOFTWARE=1; export QT_XCB_GL_INTEGRATION=none; export QT_X11_NO_MITSHM=1; cd "$(SIM_DIR)" && SCENARIO_OUT="$(SCENARIO_OUT)" $(VSIM) -do $(VSIM_DO)'
else
	bash -lc 'cd "$(SIM_DIR)" && SCENARIO_OUT="$(SCENARIO_OUT)" $(VSIM) -do $(VSIM_DO)'
endif
endif

# --- Per-scenario pattern rules: make _sim-test1, make _golden-test2 ---

$(addprefix _sim-,$(SCENARIOS)): _sim-%:
	$(MAKE) sim SCENARIO=$*

$(addprefix _golden-,$(SCENARIOS)): _golden-%:
	$(MAKE) golden SCENARIO=$*

# --- Run all scenarios ---

sim-all: $(addprefix _sim-,$(SCENARIOS))

golden-all: $(addprefix _golden-,$(SCENARIOS))

# --- Clean ---

clean:
	rm -f $(SIM_DIR)/transcript $(SIM_DIR)/vsim.wlf $(SIM_DIR)/sys_mem.wlf
	rm -rf $(SIM_DIR)/work
	rm -rf out/
