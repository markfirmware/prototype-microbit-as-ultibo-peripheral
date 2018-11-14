#!/bin/bash

docker run -it --mount type=bind,source=$(pwd),destination=/root/workspace markfirmware/ultibo
