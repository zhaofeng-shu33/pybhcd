#!/bin/bash
set -e -x
export PLAT=manylinux2010_x86_64
PY36=/opt/python/cp36-cp36m/bin
PY37=/opt/python/cp37-cp37m/bin
$PY36/pip wheel . -w dist/
$PY37/pip wheel . -w dist/
# Bundle external shared libraries into the wheels
for whl in dist/*.whl; do
    auditwheel repair "$whl" --plat $PLAT -w dist/wheelhouse/
done
