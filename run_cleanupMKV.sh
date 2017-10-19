#!/bin/bash
find . -iname '*.mkv' -type f -exec ~/cleanupMKV.awk {} \; | tee /mnt/NAS/media/log.txt
exit