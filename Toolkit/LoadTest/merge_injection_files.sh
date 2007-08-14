#!/bin/sh

find . -name "LoadTest07_files_info_*" -exec cat {} \; | sed -e s+\,\ +\,+g| sort -n > LoadTest07_files_info

