@echo off
rem Arranca el agente de NANA para la demo (revisa corriente, Ollama y clave).
rem -ExecutionPolicy Bypass vale solo para esta ventana, no cambia Windows.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0agente\arrancar_demo.ps1"
