# pybhcd: Bayesian Hierarchical Community Discovery
[![PyPI](https://img.shields.io/pypi/v/pybhcd.svg)](https://pypi.org/project/pybhcd)

An efficient Bayesian nonparametric model for discovering hierarchical community structure in social networks. 

## Parameter Tuning
There are five parameters (alpha, beta, lambda, delta, gamma) to be tuned, lines within interval (0,1) and satisifies the following
constraint.

alpha > beta
lambda > delta

## Build

Use CMake to build, necessary dependencies are glib and gsl. For Windows, you can use [vcpkg](https://github.com/microsoft/vcpkg) to install the dependencies.
remove lua support.
