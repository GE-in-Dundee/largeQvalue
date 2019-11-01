#!/bin/bash
for x in "temp" "parameter_file"; do
    if [ -f $x ]; then
	echo "Running tests would overwrite a temporary file:" $x
	exit 1
    fi
done

./bin/largeQvalue --header --col 4 --out temp --param parameter_file data/vQTLresults.txt

if [[ ($( sha1sum temp | awk {'print toupper($1)'}) == "83B632E8A06C7FBC529D05EC8C15697FE649BA2A") &&
      ($( sha1sum parameter_file | awk {'print toupper($1)'}) == "005C2960776F41D888B585B1080617EB200A0603")]]; then
echo "Passed: smooth pi0 estimate."
else
echo "Failed: smooth pi0 estimate."
rm -f temp parameter_file
exit 1
fi

./bin/largeQvalue --boot --header --col 4 --out temp --param parameter_file data/vQTLresults.txt

if [[ ($( sha1sum temp | awk {'print toupper($1)'}) == "D5C0B7F8E25349FB024258A2647CD3DADED8E0F8") &&
      ($( sha1sum parameter_file | awk {'print toupper($1)'}) == "F1833969B9019B6577E6C1631E90E9A7C7321602")]]; then
echo "Passed: bootstrap pi0 estimate."
else
echo "Failed: bootstrap pi0 estimate."
rm -f temp parameter_file
exit 1
fi


if [[ $( ./bin/largeQvalue --fast 0.05 --col 10 data/nominal | sha1sum | awk {'print toupper($1)'}) == "1F742A9FDF978E626A84A8A26D608FD52DD6A796" ]]; then
    echo "Passed: fast estimates."
else
    echo "Failed: fast estimates."
    rm -f temp parameter_file
    exit 1
fi

rm -f temp parameter_file

echo "All tests completed successfully."
