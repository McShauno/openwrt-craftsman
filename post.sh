#!/bin/bash

logline "Updating OpenWrt feeds."
${repository_target}/scripts/feeds update -a
