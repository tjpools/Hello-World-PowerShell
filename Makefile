TARGET = test.exe
SRC = test.cpp
OBJ = test.obj
CXX = cl
RELEASE_CXXFLAGS = /EHsc /nologo /O2
DEBUG_CXXFLAGS = /EHsc /nologo /Zi /Od
DEBUG_LDFLAGS = /DEBUG
PDB = test.pdb
OBJDUMP = test.objdump.txt
MAIN_OBJDUMP = test.main.objdump.txt
INVOKE_MAIN_OBJDUMP = test.invoke_main.objdump.txt
MAINCRTSTARTUP_OBJDUMP = test.mainCRTStartup.objdump.txt
HEXDUMP = test.hexdump.txt

all: release

release: $(SRC)
	$(CXX) $(RELEASE_CXXFLAGS) /Fe:$(TARGET) $(SRC)

debug: $(SRC)
	$(CXX) $(DEBUG_CXXFLAGS) /Fe:$(TARGET) $(SRC) /link $(DEBUG_LDFLAGS)

run: release
	cmd /c .\$(TARGET)

debug-run: debug
	cmd /c .\$(TARGET)

dumps: $(OBJDUMP) $(MAIN_OBJDUMP) $(INVOKE_MAIN_OBJDUMP) $(MAINCRTSTARTUP_OBJDUMP) $(HEXDUMP)

$(OBJDUMP): debug
	dumpbin /DISASM /RAWDATA:NONE $(TARGET) > $(OBJDUMP)

$(MAIN_OBJDUMP): $(OBJDUMP)
	pwsh -NoProfile -Command "$$lines = Get-Content '$(OBJDUMP)'; $$start = [Array]::IndexOf($$lines, 'main:'); if ($$start -lt 0) { throw 'main symbol not found in objdump output' }; $$end = $$start + 1; while ($$end -lt $$lines.Length) { if ($$end -gt $$start -and $$lines[$$end] -match '^[^ ].*:$$') { break }; $$end++ }; $$lines[$$start..($$end - 1)] | Set-Content '$(MAIN_OBJDUMP)' -Encoding ascii"

$(INVOKE_MAIN_OBJDUMP): $(OBJDUMP)
	pwsh -NoProfile -Command "$$lines = Get-Content '$(OBJDUMP)'; $$start = [Array]::IndexOf($$lines, 'invoke_main:'); if ($$start -lt 0) { throw 'invoke_main symbol not found in objdump output' }; $$end = $$start + 1; while ($$end -lt $$lines.Length) { if ($$end -gt $$start -and $$lines[$$end] -match '^[^ ].*:$$') { break }; $$end++ }; $$lines[$$start..($$end - 1)] | Set-Content '$(INVOKE_MAIN_OBJDUMP)' -Encoding ascii"

$(MAINCRTSTARTUP_OBJDUMP): $(OBJDUMP)
	pwsh -NoProfile -Command "$$lines = Get-Content '$(OBJDUMP)'; $$start = [Array]::IndexOf($$lines, 'mainCRTStartup:'); if ($$start -lt 0) { throw 'mainCRTStartup symbol not found in objdump output' }; $$end = $$start + 1; while ($$end -lt $$lines.Length) { if ($$end -gt $$start -and $$lines[$$end] -match '^[^ ].*:$$') { break }; $$end++ }; $$lines[$$start..($$end - 1)] | Set-Content '$(MAINCRTSTARTUP_OBJDUMP)' -Encoding ascii"

$(HEXDUMP): debug
	pwsh -NoProfile -Command "Format-Hex -Path '$(TARGET)' | Out-File -FilePath '$(HEXDUMP)' -Encoding ascii"

clean:
	if exist $(OBJ) del /Q $(OBJ)
	if exist $(TARGET) del /Q $(TARGET)
	if exist $(PDB) del /Q $(PDB)
	if exist $(OBJDUMP) del /Q $(OBJDUMP)
	if exist $(MAIN_OBJDUMP) del /Q $(MAIN_OBJDUMP)
	if exist $(INVOKE_MAIN_OBJDUMP) del /Q $(INVOKE_MAIN_OBJDUMP)
	if exist $(MAINCRTSTARTUP_OBJDUMP) del /Q $(MAINCRTSTARTUP_OBJDUMP)
	if exist $(HEXDUMP) del /Q $(HEXDUMP)
