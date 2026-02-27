#!/usr/bin/env bash

# ----------------------------------------------------------------------------------------
# Input parsing
# ----------------------------------------------------------------------------------------
REVOCATION=false
FILENAME="keybackup"
HINT=""
QRSIZE=512
USE_FONT=false
FONT_PATH=""

if [[ $# -lt 1 ]]; then
    echo "Usage: keybackup <KEYID> [-r|--revocation] [-n|--filename <filename>] [-h|--hint <hint>] [-s|--qrsize <size>] [-f|--font <path>]"
    exit 1
fi

KEYID="$1"
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--revocation)
            REVOCATION=true
            ;;
        -f|--font)
            if [[ -z "$2" ]]; then
                echo "Error: --font requires a path"
                exit 1
            fi

            if [[ ! -f "$2" ]]; then
                echo "Error: font file not found: $2"
                exit 1
            fi

            if [[ "$2" != *.ttf ]]; then
                echo "Error: font file must be a .ttf file"
                exit 1
            fi

            FONT_PATH="$2"
            USE_FONT=true
            shift
            ;;
        -n|--filename)
            if [[ -z "$2" ]]; then
                echo "Error: --filename requires an argument"
                exit 1
            fi
            FILENAME="$2"
            shift
            ;;
        -h|--hint)
            if [[ -z "$2" ]]; then
                echo "Error: --hint requires an argument"
                exit 1
            fi
            HINT="$2"
            shift
            ;;
        -s|--qrsize)
            if [[ -z "$2" ]]; then
                echo "Error: --qrsize requires an argument"
                exit 1
            fi

            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --qrsize must be a positive number"
                exit 1
            fi

            if [[ "$2" -le 0 ]]; then
                echo "Error: --qrsize must be greater than 0"
                exit 1
            fi

            QRSIZE="$2"
            shift
            ;;
        *)
            echo "Unknown option: $1"
    		echo "Usage: keybackup <KEYID> [-r|--revocation] [-n|--filename <filename>] [-h|--hint <hint>] [-s|--qrsize <size>] [-f|--font <path>]"
            exit 1
            ;;
    esac
    shift
done


# ----------------------------------------------------------------------------------------
# Export Key
# ----------------------------------------------------------------------------------------
KEYPATH="$FILENAME.asc"
REVPATH="$FILENAME.rev.asc"

gpg --export-secret-keys --armor "$KEYID" | gpg --symmetric --armor -o "$KEYPATH"
if $REVOCATION; then
	gpg --gen-revoke "$KEYID" | gpg --symmetric --armor -o "$REVPATH"
fi


# ----------------------------------------------------------------------------------------
# Create QR Codes
# ----------------------------------------------------------------------------------------
python3 -m venv venv
source venv/bin/activate
python3 src/createQR.py "$KEYPATH" -f "./src/Ubuntu-B.ttf" -o "qr_chunks" -s "$QRSIZE" > /dev/null
	if $USE_FONT; then
		python3 src/createQR.py "$KEYPATH" -f "$FONT_PATH" -o "qr_chunks" -s "$QRSIZE" > /dev/null
	else
		python3 src/createQR.py "$KEYPATH" -o "qr_chunks" -s "$QRSIZE" > /dev/null
	fi

if $REVOCATION; then 
	if $USE_FONT; then
		python3 src/createQR.py "$REVPATH" -f "$FONT_PATH" -o "qr_chunks_rev" -s "$QRSIZE" > /dev/null
	else
		python3 src/createQR.py "$REVPATH" -o "qr_chunks_rev" -s "$QRSIZE" > /dev/null
	fi
fi


# ----------------------------------------------------------------------------------------
# Gather key information 
# ----------------------------------------------------------------------------------------
KEYUID=$(gpg --list-secret-keys --with-colons "$KEYID" | awk -F: '/^uid:/ {print $10; exit}')
CREATED=$(gpg --list-secret-keys --with-colons "$KEYID" | awk -F: '/^sec:/ {print $6}')
EXPIRES=$(gpg --list-secret-keys --with-colons "$KEYID" | awk -F: '/^sec:/ {print $7}')


NAME=$(echo "$KEYUID" | sed 's/ (.*//')
EMAIL=$(echo "$KEYUID" | grep -o '<.*>' | tr -d '<>')
DATECREATED=$(date -d @"$CREATED" +"%Y-%m-%d")
if [ "$EXPIRES" != "" ] && [ "$EXPIRES" != "0" ]; then
    DATEEXPIRES=$(date -d @"$EXPIRES" +"%Y-%m-%d")
else
    DATEEXPIRES="Never"
fi
FINGERPRINT=$(gpg --fingerprint --with-colons "$KEYID" | awk -F: '/^fpr:/ {print $10; exit}')

CHECKSUM=$(sha256sum "$KEYPATH" | cut -d' ' -f1)
KEYFILENAME="$KEYPATH"
QRCOUNT=$(ls qr_chunks/qr_chunk_*.png 2>/dev/null | wc -l)


REVCHECKSUM=""
REVFILENAME=""
REVQRCOUNT=0 # needs to be set either way
if $REVOCATION; then 
	REVCHECKSUM=$(sha256sum "$REVPATH" | cut -d' ' -f1)
	REVFILENAME="$REVPATH"
	REVQRCOUNT=$(ls qr_chunks_rev/qr_chunk_*.png 2>/dev/null | wc -l)
fi

if [ "$REVOCATION" = "true" ]; then
  REVOCATIONFLAG="\\\\revocationtrue"
else
  REVOCATIONFLAG="\\\\revocationfalse"
fi


# ----------------------------------------------------------------------------------------
# Create PDF 
# ----------------------------------------------------------------------------------------
sed \
  -e "s/__KEYID__/$KEYID/g" \
  -e "s/__KEYNAME__/$FILENAME/g" \
  -e "s/__NAME__/$NAME/g" \
  -e "s/__EMAIL__/$EMAIL/g" \
  -e "s/__DATECREATED__/$DATECREATED/g" \
  -e "s/__DATEEXPIRES__/$DATEEXPIRES/g" \
  -e "s/__FINGERPRINT__/$FINGERPRINT/g" \
  -e "s/__CHECKSUM__/$CHECKSUM/g" \
  -e "s/__KEYFILENAME__/$KEYFILENAME/g" \
  -e "s/__QRCOUNT__/$QRCOUNT/g" \
  -e "s/__REVOCATIONFLAG__/$REVOCATIONFLAG/g" \
  -e "s/__REVCHECKSUM__/$REVCHECKSUM/g" \
  -e "s/__REVFILENAME__/$REVFILENAME/g" \
  -e "s/__REVQRCOUNT__/$REVQRCOUNT/g" \
  -e "s/__HINT__/$HINT/g" \
  src/template.tex > "backup.tex"

mkdir -p "$FILENAME"
pdflatex -output-directory="$FILENAME" backup.tex > /dev/null

rm "$FILENAME/backup.aux"
rm "$FILENAME/backup.log"

mv "$KEYPATH" "$FILENAME/$KEYPATH"
if [ "$REVOCATION" = "true" ]; then
	mv "$REVPATH" "$FILENAME/$REVPATH"
fi

mv "$FILENAME/backup.pdf" "$FILENAME/${FILENAME}_backup.pdf"

deactivate
rm backup.tex
rm -rf qr_chunks
rm -rf qr_chunks_rev

