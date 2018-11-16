#!/bin/bash

docker run --rm -it --mount type=bind,source=$(pwd),destination=/root/workspace -p 5080:5080 markfirmware/ultibo
