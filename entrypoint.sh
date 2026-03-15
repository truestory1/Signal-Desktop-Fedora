#!/bin/bash

set -euo pipefail

mkdir -p /output
cp /rpm/*.rpm /output/

echo -e "\e[42;30mDone !\e[0m"
