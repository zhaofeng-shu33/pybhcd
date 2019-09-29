[![Travis](https://api.travis-ci.com/zhaofeng-shu33/pybhcd.svg?branch=master)](https://travis-ci.com/zhaofeng-shu33/pybhcd)
[![Appveyor](https://ci.appveyor.com/api/projects/status/github/zhaofeng-shu33/pybhcd?branch=master&svg=true)](https://ci.appveyor.com/project/zhaofeng-shu33/pybhcd)

[![CircleCI](https://circleci.com/gh/zhaofeng-shu33/pybhcd.svg?style=svg)](https://circleci.com/gh/zhaofeng-shu33/pybhcd)

# pybhcd: Bayesian Hierarchical Community Discovery
[![PyPI](https://img.shields.io/pypi/v/pybhcd.svg)](https://pypi.org/project/pybhcd)

An efficient Bayesian nonparametric model for discovering hierarchical community structure in social networks. 

## Parameter Tuning
There are five parameters (alpha, beta, lambda, delta, gamma) to be tuned, lines within interval (0,1) and satisifies the following
constraint.

alpha > beta
lambda > delta

## Build

For Windows, you can use [vcpkg](https://github.com/microsoft/vcpkg) to install the dependencies.
