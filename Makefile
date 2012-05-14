default: paper

paper:
	latexmk -r lhs2texmkrc -pdf -pvc haskell2012.lhs

clean:
	latexmk -CA
