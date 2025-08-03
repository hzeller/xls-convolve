# XLS experiments

A framework to play with XLS from the distribution (avoids compiling for ~2h)
and also not having to use the bazel rules but simple Makefiles instead.

The `shell.nix` fetches the binaries distributed in
the [releases](https://github.com/google/xls/releases).

Either request with nix-shell
```
nix-shell
```
... or set up `direnv` to do that automatically.

The distributed XLS binaries have very technical names that don't make sense
for end-users and uses some naming-conventions with underscores.
Rename them to always have an `xls-` prefix for tab-completion discoverability,
replace underscores with dashes and remove the superfluous `_main` suffix.
This provides the binaries `xls-ir-converter`, `xls-interpreter`, `xls-opt`,
`xls-codegen`, `xls-proto-to-dslx`, `xls-prove-quickcheck`.

Also have `dslx-fmt` and `dslx-ls` have friendlier names (with dashes).

Since the stdlib comes with the distribution, set up environment variables
`DSLX_PATH` and `DSLX_STDLIB_PATH` for easy use in scripting.

See https://google.github.io/xls/dslx_lanandguage_server/ how to set up language
server (but use the nicer binary name with dash).

## Building

This uses a simple makefile for ease of use and clarity what is going on.

## To use

Given a foo.x file,

   * `make foo.opt.ir` builts an optimmized ir.
   * `make foo.test` runs all the unit tests in the given *.x file.
   * `make foo.sv` generates system verilog.

Current assumption is that top is called `top` (configured in Makefile).

## Convolve experiment

This should eventually become a proc that takes a sample (e.g. audio sample)
and runs a convolution over it (e.g. to get a FIR filter). Also prepared for
time-multiplexing a convolution core, so that each input can take multiple
cycles to generate one output.

```
make convolve.sv
make convolve.test  # to run tests
```
