!include ..\..\..\mkconfig.nmk
!include ..\..\..\$(SYSHOST)\mkhost

MODULE=..\..\..\module

DIRS=\
	httpd\
	webget\

all \
install \
uninstall \
clean \
nuke \
package :
 	@for %%j in ( $(DIRS) )  \
 	do $(MAKE) /NOLOGO TARGCD=%%j TARGMK=$@ cdmk 

cdmk: 
	@echo cd $(TARGCD); $(MAKE) /NOLOGO $(TARGMK) 
	@cd $(TARGCD)
	@$(MAKE) /NOLOGO $(TARGMK)
