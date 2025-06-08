
TOP=top
DELAY_MODEL=sky130
PIPELINE_STAGES=1

convolve.sv:

%.ir: %.x
	xls-ir-converter --top=$(TOP) --dslx_stdlib_path=$(DSLX_STDLIB_PATH) --output_file=$@ $^

%.opt.ir: %.ir
	xls-opt --output_path=$@ $^

%.sv : %.opt.ir
	xls-codegen --delay_model=$(DELAY_MODEL) --pipeline_stages=$(PIPELINE_STAGES) --output_verilog_path=$@ --use_system_verilog $^

%.test: %.x
	xls-interpreter --dslx_stdlib_path=$(DSLX_STDLIB_PATH) $^

clean:
	rm -f *.ir *.sv
