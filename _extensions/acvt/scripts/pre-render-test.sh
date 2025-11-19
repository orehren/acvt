#!/bin/sh
# This is a simple diagnostic script to test if Quarto pre-render is working.
# It creates a log file and writes the current working directory to it.

echo "Shell script was executed successfully." > pre-render-test.log
echo "Current Working Directory: $(pwd)" >> pre-render-test.log
