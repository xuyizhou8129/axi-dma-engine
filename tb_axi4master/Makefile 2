# Golden vectors + Questa/ModelSim (cwd for vsim = sim/).  make golden | sim | sim-gui
# MODELSIM_ENV= to skip sourcing.  sim-gui sets LIBGL_/QT_ for X11 over SSH (GUI_FIX=0 to disable).

PYTHON   ?= python3
OUT_DIR  ?= out
SIM_DIR  := $(abspath $(CURDIR)/sim)
MODELSIM_ENV   ?= /vol/eecs392/env/modelsim.env
MODELSIM_SHELL ?= tcsh
VSIM     ?= vsim
VSIM_DO  := axi4master_sim.do

GUI_FIX  ?= 1
ifeq ($(GUI_FIX),1)
GUI_FIX_TCSH := setenv LIBGL_ALWAYS_SOFTWARE 1; setenv QT_XCB_GL_INTEGRATION none; setenv QT_X11_NO_MITSHM 1;
else
GUI_FIX_TCSH :=
endif

.PHONY: golden sim sim-gui clean

golden:
	$(PYTHON) csv_golden_runner.py scenarios/example.csv $(OUT_DIR)

sim: golden
ifneq ($(strip $(MODELSIM_ENV)),)
	$(MODELSIM_SHELL) -c 'if ( -f "$(MODELSIM_ENV)" ) source "$(MODELSIM_ENV)"; cd "$(SIM_DIR)"; setenv TB_BATCH 1; $(VSIM) -c -do $(VSIM_DO)'
else
	bash -lc 'cd "$(SIM_DIR)" && TB_BATCH=1 $(VSIM) -c -do $(VSIM_DO)'
endif

sim-gui: golden
ifneq ($(strip $(MODELSIM_ENV)),)
	$(MODELSIM_SHELL) -c 'if ( -f "$(MODELSIM_ENV)" ) source "$(MODELSIM_ENV)"; cd "$(SIM_DIR)"; $(GUI_FIX_TCSH) $(VSIM) -do $(VSIM_DO)'
else
ifeq ($(GUI_FIX),1)
	bash -lc 'export LIBGL_ALWAYS_SOFTWARE=1; export QT_XCB_GL_INTEGRATION=none; export QT_X11_NO_MITSHM=1; cd "$(SIM_DIR)" && $(VSIM) -do $(VSIM_DO)'
else
	bash -lc 'cd "$(SIM_DIR)" && $(VSIM) -do $(VSIM_DO)'
endif
endif

clean:
	rm -f $(SIM_DIR)/transcript $(SIM_DIR)/vsim.wlf $(SIM_DIR)/axi4master.wlf
	rm -rf $(SIM_DIR)/work
	rm -f sim.vvp
