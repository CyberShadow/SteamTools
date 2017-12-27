set datafile separator ","
set logscale y
set key top left
plot \
"./review.csv" using 1:(stringcolumn(4) eq "Overwhelmingly Negative"?$2:1/0) title "Overwhelmingly Negative", \
"./review.csv" using 1:(stringcolumn(4) eq "Very Negative"?$2:1/0) title "Very Negative", \
"./review.csv" using 1:(stringcolumn(4) eq "Negative"?$2:1/0) title "Negative", \
"./review.csv" using 1:(stringcolumn(4) eq "Mostly Negative"?$2:1/0) title "Mostly Negative", \
"./review.csv" using 1:(stringcolumn(4) eq "Mixed"?$2:1/0) title "Mixed", \
"./review.csv" using 1:(stringcolumn(4) eq "Mostly Positive"?$2:1/0) title "Mostly Positive", \
"./review.csv" using 1:(stringcolumn(4) eq "Positive"?$2:1/0) title "Positive", \
"./review.csv" using 1:(stringcolumn(4) eq "Very Positive"?$2:1/0) title "Very Positive", \
"./review.csv" using 1:(stringcolumn(4) eq "Overwhelmingly Positive"?$2:1/0) title "Overwhelmingly Positive"
