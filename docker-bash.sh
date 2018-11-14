#!/bin/bash

docker run --rm -it --mount type=bind,source=$(pwd),destination=/root/workspace markfirmware/ultibo
