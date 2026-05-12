#!/bin/csh
# cd to this script's directory (works from repo root or from syn/; avoids `cd syn` when already in syn/)
cd `dirname $0`
source /vol/eecs392/env/synplify.env
synplify_premier dma.prj
