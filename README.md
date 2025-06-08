# XLS experiments

The `shell.nix` fetches the binaries distributed in
the [releases](https://github.com/google/xls/releases).

The distributed XLS binaries have very technical names that don't make sense
for end-users and uses some eye-sore naming-conventions with underscores.
Rename them to always have an `xls-` prefix for tab-completion discoverability,
replace underscores with dashes and remove the superfluous `_main`.
This provides the binaries `xls-ir-converter`, `xls-interpreter`, `xls-opt`,
`xls-codegen`, `xls-proto-to-dslx`, `xls-prove-quickcheck`.

Also, sets up an environment variable `DSLX_PATH` with the stdlib path.

Also `dslx-fmt` and `dslx-ls` have friendlier names.

See https://google.github.io/xls/dslx_language_server/ how to set up language
server (but use the nicer binary name with dash).
Need to set the dslx path via flag or wait
for https://github.com/google/xls/pull/2353 to have that automatically.

## Building

This uses a simple makefile for ease of use and clarity what is going on.

## To use

Given a foo.x file,

   * `make foo.opt.ir` builts an optimmized ir.
   * `make foo.test` runs all the unit tests in the given *.x file.
   * `make foo.sv` generates system verilog.

Current assumption is that top is called `top` (configured in Makefile).
