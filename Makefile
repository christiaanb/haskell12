soosim.pdf : soosim.tex content.tex jabref.bib haskell2012.bib
	latexmk -pdf -pvc -r latexmkrc soosim

paper : soosim.tex content.tex jabref.bib haskell2012.bib
	latexmk -pdf soosim

