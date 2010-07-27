# Makefile for phd. Created Thu Feb 04 11:21:04 2010,

# Define default target before importing other Makefile settings
all: default

##############################################################################
### DEFAULT SETTINGS (can be overridden by Makefile.settings) ################

# Filenames
MAINDIR = $(empty)$(empty)
MAINTEX = thesis.tex
MAINBIBTEXFILE = thesis.bib
DEFS_THESIS = defs_thesis.tex # Thesiswide preamble settings

CHAPTERSDIR = chapters
IMAGEDIR = image # This corresponds to $(CHAPTERSDIR)/<chapter>/$(IMAGEDIR)

DEFS = defs.tex # Autogenerated by this Makefile from $(DEFS_THESIS) 
				# and $(CHAPTERSDIR)/*/$(DEFS).

CLEANEXTENSIONS = toc aux log bbl blg log lof lot ilg out glo gls nlo nls brf ist glg synctex.gz tgz idx ind
REALCLEANEXTENSIONS = dvi pdf ps

FORCE_REBUILD = .force_rebuild

# Binaries
TEX = latex
PDFTEX = pdflatex
DVIPS = dvips
PS2PDF = ps2pdf
BIBTEX = bibtex
MAKEINDEX = makeindex
DETEX = detex
GNUDICTION = diction
GNUSTYLE = style
ASPELL = aspell --lang=en_GB --add-tex-command="eqref p" \
			--add-tex-command="psfrag pP" --add-tex-command="special p" \
			--encoding=iso-8859-1 -t

##############################################################################
### INCLUDE GENERAL SETTINGS (Everything above can be overridden) ############
include Makefile.settings
 
##############################################################################
### DERIVED SETTINGS #########################################################

# Other tex files that might be included in $(MAINTEX)
INCLUDEDCHAPTERNAMES = $(shell grep -e "^[^%]*\include" $(MAINTEX) | sed -n -e 's|.*{\(.*\)}.*|\1|p')
CHAPTERTEXS = $(wildcard $(CHAPTERSDIR)/*/*.tex)
CHAPTERTEXS = $(foreach chaptername,$(CHAPTERNAMES),$(shell test -f $(CHAPTERSDIR)/$(chaptername)/.ignore || echo $(CHAPTERSDIR)/$(chaptername)/$(chaptername).tex) )
CHAPTERNAMES = $(subst ./,,$(shell (cd $(CHAPTERSDIR); find -mindepth 1 -maxdepth 1 -type d)))

# Check if we passed the environment variable CHAPTERS. If so, redefine
# $(CHAPTERNAMES).
ifeq ($(origin CHAPTERS),environment) 
	CHAPTERNAMES = $(CHAPTERS) 
endif

# TODO: onderstaande wildcard dinges kunnen nog verbeterd worden!
CHAPTERDEFS = $(wildcard $(CHAPTERSDIR)/*/$(DEFS))
CHAPTERMAKEFILES = $(addsuffix /Makefile,$(shell find $(CHAPTERSDIR) -mindepth 1 -maxdepth 1 -type d))
CHAPTERAUX = $(foreach chaptername,$(CHAPTERNAMES),$(shell test -f $(CHAPTERSDIR)/$(chaptername)/.ignore || echo $(CHAPTERSDIR)/$(chaptername)/$(chaptername).aux) )

DVIFILE = $(MAINTEX:.tex=.dvi)
PSFILE = $(MAINTEX:.tex=.ps)
PDFFILE = $(MAINTEX:.tex=.pdf)
BBLFILE = $(MAINTEX:.tex=.bbl)
NOMENCLFILE = $(MAINTEX:.tex=.nls)
GLOSSFILE = $(MAINTEX:.tex=.gls)

IGNOREINCHAPTERMODE = \(makefrontcover\|makebackcover\|maketitle\|includepreface\|includeabstract\|listoffigures\|listoftables\|printnomenclature\|printglossary\|includecv\|includepublications\|includeonly\|instructionschapters\)

IGNOREINCHAPTERMODEBARE = $(subst makefrontcover,makefrontcover\|tableofcontents,$(IGNOREINCHAPTERMODE))

PDFNUP = $(shell which pdfnup)

test:
	@echo $(CHAPTERNAMES)
	#@echo $(IGNOREINCHAPTERMODEBARE)
	#@echo $(PDFNUP)
	#@echo $(CHAPTERAUX)
	#echo 'lkasdjf'
	#echo $(CHAPTERNAMES)
	#echo $(wildcard $(CHAPTERSDIR)/*)/Makefile
	#echo $(wildcard $(CHAPTERSDIR)/*/$(DEFS))
	#echo $(CHAPTERDEFS)

# Default build target
default: $(PSFILE) $(PDFFILE)

##############################################################################
### BUILD PDF/PS (with relaxed dependencies on bibtex, nomenclature, glossary)

$(DVIFILE): %.dvi : $(FORCE_REBUILD)
	$(TEX) $(@:.dvi=.tex)
	$(TEX) $(@:.dvi=.tex)

%.ps: %.dvi
	$(DVIPS) -P pdf -o $@ $<

%.pdf: %.ps
	$(PS2PDF) -dMaxSubsetPct=100 -dSubsetFonts=true -dEmbedAllFonts=true \
		-dPDFSETTINGS=/printer -dCompatibilityLevel=1.3 $<

$(DVIFILE): $(MAINTEX) $(DEFS) $(EXTRADEP) $(CHAPTERTEXS) $(CHAPTERMAKEFILES) $(BBLFILE) $(NOMENCLFILE) $(GLOSSFILE)

##############################################################################
### PUT 2 LOGICAL PAGES ON SINGLE PHYSICAL PAGE  #############################

.PHONY: psnup
psnup: $(PDFFILE)
	if [ "$(PDFNUP)" != "" ]; then \
		pdfnup --frame true $<;\
	else \
		pdftops -q $< - | psnup -q -2 -d1 -b0 -m20 -s0.65 > $(PDFFILE:.pdf=-2x1.ps);\
		echo "Finished: output is $$PWD/$(PDFFILE:.pdf=-2x1.ps)";\
	fi;

##############################################################################
### BUILD THESIS AND CHAPTERS ################################################
.PHONY: thesisfinal
thesisfinal: $(MAINTEX) $(DEFS) $(FORCE_REBUILD)
	@make nomenclature
	@echo "Running bibtex..."
	$(BIBTEX) $(basename $<)
	@echo "Running latex a second time..."
	$(TEX) $<
	@echo "Running latex a third time..."
	$(TEX) $<
	@echo "Converting dvi -> ps -> pdf..."
	make $(PDFFILE)
	@echo "Done."

thesis_bare.pdf: empty:=
thesis_bare.pdf: space:= $(empty) $(empty)
thesis_bare.pdf: comma:= ,
thesis_bare.pdf: CHAPTERTEXS = $(foreach chaptername,$(CHAPTERNAMES),$(CHAPTERSDIR)/$(chaptername)/$(chaptername).tex)
thesis_bare.pdf: CHAPTERAUX = $(foreach chaptername,$(CHAPTERNAMES),$(CHAPTERSDIR)/$(chaptername)/$(chaptername).aux)
thesis_bare.pdf: CHAPTERINCLUDEONLYSTRING = $(subst $(space),$(comma),$(foreach chaptername,$(CHAPTERNAMES),$(CHAPTERSDIR)/$(chaptername)/$(chaptername)))
thesis_bare.pdf: $(CHAPTERAUX) $(CHAPTERTEXS)
	@echo $(CHAPTERNAMES)
	@echo $(CHAPTERTEXS)
	@echo "Creating pdf '$@' only containing chapters:"
	@for i in $(CHAPTERNAMES); do echo "  + $$i"; done
	grep -v '$(IGNOREINCHAPTERMODE)' $(MAINTEX) \
		| sed -e 's|\\begin{document}|\\includeonly{$(CHAPTERINCLUDEONLYSTRING)}\\begin{document}|' > my${@:.pdf=.tex}
	make my${@:.pdf=.bbl}
	$(TEX) my${@:.pdf=.tex}
	$(TEX) my${@:.pdf=.tex}
	make my$@
	make cleanpar TARGET=my${@:.pdf=}
	mv my$@ $@
	$(RM) my${@:.pdf=.tex} my${@:.pdf=.dvi}

$(DEFS): $(DEFS_THESIS) $(CHAPTERDEFS)
	cat $(DEFS_THESIS) > $@
	for i in $(CHAPTERDEFS);\
	do \
	  [ -f $$i ] && ! [ -L $$i ] && (cat $$i >> $@);\
	done

%: $(CHAPTERAUX) $(CHAPTERSDIR)/%  
	@echo "Creating chapter 'my$@'..."
	IGNOREINCHAPTERMODE='$(IGNOREINCHAPTERMODE)' ; \
		[ "$$(sed -n -s 's/.*includeabstract{\(.*\)}/\1/p' $(MAINTEX))" = "$@" ] \
		&& IGNOREINCHAPTERMODE=$$(echo '$(IGNOREINCHAPTERMODE)' | sed -e 's/\\|includeabstract//') \
		&& echo "$$IGNOREINCHAPTERMODE"; \
		grep -v "$$IGNOREINCHAPTERMODE" $(MAINTEX) \
		| sed -e 's|\\begin{document}|\\includeonly{$(CHAPTERSDIR)/$@/$@}\\begin{document}|' > my$@.tex
	make my$@.bbl 
	$(TEX) my$@.tex
	$(TEX) my$@.tex
	make my$@.ps my$@.pdf
	make cleanpar TARGET=my$@
	$(RM) my$@.tex

%_bare: BARECHAPNAME = $(@:_bare=)
%_bare: $(CHAPTERAUX) $(CHAPTERSDIR)/%  
	@echo "Creating chapter 'my$(BARECHAPNAME)'..."
	#IGNOREINCHAPTERMODEBARE=$$(echo '$(IGNOREINCHAPTERMODEBARE)' | sed -e 's/\\|includeabstract//')
	#@echo "$$IGNOREINCHAPTERMODEBARE"
	grep -v '$(IGNOREINCHAPTERMODEBARE)' $(MAINTEX) \
		| sed -e 's|\\begin{document}|\\includeonly{$(CHAPTERSDIR)/$(BARECHAPNAME)/$(BARECHAPNAME)}\\begin{document}|' > my$@.tex
	$(TEX) my$@.tex
	make my$@.bbl
	$(TEX) my$@.tex
	$(TEX) my$@.tex
	sed -i.bak -e 's/^.*bibliography.*$$//' my$@.tex 
	$(TEX) my$@.tex
	make my$@.ps my$@.pdf
	make cleanpar TARGET=my$@
	$(RM) my$@.tex my$@.tex.bak

$(CHAPTERAUX): $(DEFS) $(CHAPTERTEXS)
	@echo "Creating $@ ..."
	$(TEX) $(MAINTEX)

.PHONY: chaptermakefiles
chaptermakefiles: $(CHAPTERMAKEFILES)

$(CHAPTERSDIR)/%/Makefile: $(CHAPTERSDIR)/Makefile.chapters
	@echo "Generating chapter makefile..."
	@echo "# Autogenerated Makefile, $(shell date)." > $@
	@echo "MAINDIR=$(PWD)" >> $@
	@echo "include ../Makefile.chapters" >> $@

##############################################################################
### BIBTEX/REFERENCES ########################################################

.PHONY: ref
ref: 
	@make $(BBLFILE)

%.bbl: %.tex $(MAINBIBTEXFILE)
	@echo "Running latex..."
	$(TEX) $<
	@echo "Running bibtex..."
	$(BIBTEX) $(<:.tex=)
	$(RM) $(<:.tex=.dvi)

reflist:
	fgrep "\cite" $(MAINTEX) | grep -v "^%.*" | \
		sed -n -e 's/^.*cite{\([^}]*\)}.*/\1/p' | sed -e 's/,/\n/g' | uniq $(PIPE)

reflist.bib: PIPE := | python extract_from_bibtex.py --bibfile=$(MAINBIBTEXFILE)--stdin > reflist.bib
reflist.bib: reflist

##############################################################################
### NOMENCLATURE  ############################################################

.PHONY: nomenclature
nomenclature: 
	@make $(NOMENCLFILE)
	
$(MAINTEX:.tex=).nls: $(MAINTEX) $(DEFS)
%.nls: %.tex
	@echo "Running latex..."
	$(TEX) $<
	@echo "Creating nomenclature..."
	$(MAKEINDEX) $(<:.tex=.nlo) -s nomencl.ist -o $(<:.tex=.nls)
	$(RM) $(DVIFILE)

##############################################################################
### GLOSSARY: LIST OF ABBREVIATIONS  #########################################

.PHONY: glossary
glossary: 
	@make $(GLOSSFILE)
	
%.gls: %.tex
	@echo "Running latex..."
	$(TEX) $<
	@echo "Creating nomenclature..."
	$(MAKEINDEX) $(<:.tex=.glo) -s $(<:.tex=.ist) -t $(<:.tex=.glg) -o $(<:.tex=.gls)
	$(RM) $(DVIFILE)

##############################################################################
### FORCE REBUILD ############################################################

#force: touch all
force_rebuild: force_rebuild_ all
force_rebuild_:
	touch $(FORCE_REBUILD)

$(FORCE_REBUILD):
	[ -e $(FORCE_REBUILD) ] || touch $(FORCE_REBUILD)

##############################################################################
### FIGURES ##################################################################

image: figures

figures:
	cd image && make

figurelist:
	@fgrep includegraphic $(MAINTEX) | sed 's/^[ \t]*//' | grep -v "^%" | \
		sed -n -e 's/.*includegraphics[^{]*{\([^}]*\)}.*/\1/p' $(FIGPIPE)

figurelist.txt: FIGPIPE := > figurelist.txt
figurelist.txt: figurelist

##############################################################################
### Sanity check #############################################################

sanitycheck:
	# Check some basic things in the tex source
	##############################
	# 1. look for todo or toremove or tofix
	@for f in $(MAINTEX) $(CHAPTERTEXS); \
	do \
		echo "\nProcessing $$f...\n";\
		GREP_COLOR="41;50" grep -n -i --color '\(todo\|toremove\|tofix\)' $$f;\
		echo "";\
	done;

##############################################################################
### CLEAN etc ################################################################

.PHONY: clean
clean:
	make cleanpar TARGET=$(basename $(MAINTEX))

.PHONY: realclean
realclean: clean
	make realcleanpar TARGET=$(basename $(MAINTEX))
	# Remove autogenerated $(DEFS)
	$(RM) $(DEFS)
	# Remove all compiled chapters
	@echo "Removing temporary files for all chapters..."
	for i in $(CHAPTERSDIR)/*;\
	do \
		i=$(basename "$$i");\
		if [ -f my"$$i".pdf ]; then $(RM) my"$$i".pdf; fi;\
		if [ -f my"$$i".dvi ]; then $(RM) my"$$i".dvi; fi;\
		if [ -f my"$$i".ps ]; then $(RM) my"$$i".ps; fi;\
	done
	# Remove .aux files in chapters
	$(RM) $(CHAPTERSDIR)/*/*.aux

##############################################################################

s:
	echo gvim $(MAINTEX) $(MAINBIBTEXFILE) > $@
	chmod +x $@

##############################################################################
# vim: tw=78
