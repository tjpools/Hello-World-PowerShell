POWERSHELL = pwsh
SCRIPT = scripts\build.ps1

all: release

release:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File $(SCRIPT) -Target release

debug:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File $(SCRIPT) -Target debug

run:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File $(SCRIPT) -Target run

debug-run:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File $(SCRIPT) -Target debug-run

dumps:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File $(SCRIPT) -Target dumps

clean:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File $(SCRIPT) -Target clean
