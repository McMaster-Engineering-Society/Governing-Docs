latexindent -s -w -l format.yaml -c=build_files/ -m bylaws.tex Sections/*.tex Sect
ions/Exec\ Portfolios/*.tex
rm indent.log

if [ $# -gt 0 ]; then
  rm bylaws.pdf
fi
