#!/bin/bash
set -ev
ROOT=$(conda info --root)
PY36=$ROOT/envs/py36/bin
PY37=$ROOT/envs/py37/bin
$PY36/pip install cython twine
export STATIC=1 && $PY36/python setup.py bdist_wheel
$PY37/pip install cython twine
$PY37/python setup.py bdist_wheel
$PY37/twine upload dist/* -u zhaofeng-shu33 && echo "success" || echo "failed"
