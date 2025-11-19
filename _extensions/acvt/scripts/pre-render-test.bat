@echo off
REM This is a simple diagnostic script to test if Quarto pre-render is working on Windows.
REM It creates a log file and writes the current working directory to it.

echo Shell script was executed successfully. > pre-render-test.log
echo Current Working Directory: %CD% >> pre-render-test.log
