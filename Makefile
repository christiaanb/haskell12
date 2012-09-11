main : styled.pdf

styled.pdf : styled.tex jabref.bib haskell2012.bib
	latexmk -pdf -r latexmkrc styled

soosim.pdf : styled.tex jabref.bib haskell2012.bib
	rm -f soosim.pdf
	make styled.pdf
	ln styled.pdf soosim.pdf

crop.pdf : styled.pdf
	pdfcrop --margin 1 styled.pdf
	mv styled-crop.pdf crop.pdf

#soosim.pdf : soosim.tex content.tex jabref.bib haskell2012.bib
#	latexmk -pdf -pvc -r latexmkrc soosim

old : soosim.tex content.tex jabref.bib haskell2012.bib
	latexmk -pdf soosim

clean :
	latexmk -C soosim
	latexmk -C styled

input.tex : header.tex footer.tex content.tex
	cat header.tex content.tex footer.tex > input.tex

styled.tex : input.tex
	lhs2TeX input.tex -o styled.tex

old-styled.pdf : styled.tex jabref.bib haskell2012.bib
	latexmk -pdf styled

