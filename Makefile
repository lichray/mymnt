PREFIX=${HOME}
BINDIR=${PREFIX}/bin

scripts=mymnt.sh umymnt.sh

all : ${scripts}

clean :
	rm -f *~

install : ${scripts}
	install -m 744 ${.ALLSRC} ${BINDIR}
	@echo "======================================================================"
	@echo "To enable the csh completion, add the following to your"
	@echo "~/.cshrc:"
	@tail -6 csh.mymnt
	@echo "Thank you for interested in the mymnt,"
	@echo "especially as a FreeBSD lover :)"
	@echo "======================================================================"

uninstall :
	-rm ${scripts:S/^/${BINDIR}\//g}

package : ../mymnt-nodoc.tar.gz
../mymnt-nodoc.tar.gz : *
	tar -czf ${.TARGET} .
