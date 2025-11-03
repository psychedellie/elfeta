consensus=$1
output=$2
db=$3

mkdir -p $output
plasmidfinder.py -i $consensus -p $db -o $output -x

