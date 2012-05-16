$pdflatex = 'pdflatex --file-line-error --halt-on-error --shell-escape --enable-write18 %O %B.tex %B.pdf';

add_cus_dep('svg', 'pdf', 0, 'cus_dep_require_primary_run');
