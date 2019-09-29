#!/bin/bash
set -ev
conda activate py36 && pip install cython twine
export STATIC_GSL=1 && python setup.py bdist_wheel
conda deactivate
conda activate py37 && pip install cython twine
python setup.py bdist_wheel
twine upload dist/* -u zhaofeng-shu33 && echo "success" || echo "failed"
