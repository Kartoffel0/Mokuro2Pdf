# Mokuro2Pdf
Cli Ruby script to generate pdf files with selectable text from Mokuro's html overlay

<img src="Mokuro2Pdf on Kindle.png" width=auto heigth=auto>

#### You can use [Memo2Anki](https://github.com/Kartoffel0/Memo2Anki) to mine from the pdfs created with this script

# Requirements
- Prawn `gem install prawn`
- Nokogiri `gem install nokogiri`
- Cgi `gem install cgi`
- MiniMagick `gem install mini_magick`

Also
- [Image Magick](https://imagemagick.org/script/download.php) as it is required by MiniMagick

# Usage
- Use [Mokuro](https://github.com/kha-white/mokuro) to generate a html overlay for the manga volume you want to convert
- This script at the moment doesn't support whole series html overlays, please make a html overlay for each volume
- Copy both the html file and the source images to the same folder as the script
- On your terminal run `ruby Mokuro2Pdf.rb "<html filename>" "<pdf output filename>" <gamma value(optional)>`
- Copy both the `<name you gave to the pdf> - MKR2PDF.json` json file and the folder with all the manga pages to [Memo2Anki](https://github.com/Kartoffel0/Memo2Anki)'s directory if you plan to mine from the pdfs

#### A [20 page demo](https://github.com/Kartoffel0/Mokuro2Pdf/blob/master/Mokuro2Pdf-Demo%20-%20MKR2PDF.pdf) is avaiable, to read it on your kindle simply drag and drop "Mokuro2Pdf-Demo - MKR2PDF.pdf" to your kindle's documents folder
