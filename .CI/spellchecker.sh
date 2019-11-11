#!/usr/bin/env bash
SCRIPT_DIR=$(dirname "${0}")
SCRIPT_NAME=$(basename "${0}")
BASEDIR="./"
TOTAL_ERRORS=0
export DICPATH="${SCRIPT_DIR}/dict"
for FILE_NAME in $(find "${BASEDIR}" -name "*.md");
do
    if test -f "${FILE_NAME}";
    then
        echo "Checking ${FILE_NAME}...";
        python "${SCRIPT_DIR}/markdown2html.py" "${FILE_NAME}";
        OUTPUT=$(hunspell -l -H -d "en_US,neteye_dict" "${FILE_NAME}.html");
        ERRORS=$(echo "${OUTPUT}" | grep -v "^\s*$" | wc -l);
        TOTAL_ERRORS=$((TOTAL_ERRORS + ERRORS))
        if [[ "$ERRORS" -ne 0 ]]; then
            echo "${FILE_NAME} errors: '$(echo "${OUTPUT}" | tr "\n" ", " | rev | cut -c3- | rev)'";
        fi;
        rm "${FILE_NAME}.html"
    fi;
done
echo "Total Errors: ${TOTAL_ERRORS}"

if [[ "${TOTAL_ERRORS}" -eq 0 ]]; then
    echo "If you are sure one or more words are not spelling errors,"
    echo "feel free to add them to the dictionary under ${DICPATH}/neteye_dict.dic."
    echo "N.B. Add the words to the list in alphabetical order and update the first line of the file" 
fi

exit "${TOTAL_ERRORS}"
