soosim.pdf : soosim.tex content.tex jabref.bib haskell2012.bib
	latexmk -pdf -pvc -r latexmkrc soosim

paper : soosim.tex content.tex jabref.bib haskell2012.bib
	latexmk -pdf soosim

clean :
	latexmk -C soosim
	latexmk -C styled

input.tex : header.tex footer.tex content.tex
	cat header.tex content.tex footer.tex > input.tex

styled.tex : input.tex
	lhs2TeX input.tex -o styled.tex

styled.pdf : styled.tex jabref.bib haskell2012.bib
	latexmk -pdf styled

