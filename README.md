# Mokuro2Pdf
Create pdf files with selectable text from [Mokuro](https://github.com/kha-white/mokuro)'s html overlay

<img src="img/Mokuro2Pdf on Kindle.png" width=auto heigth=auto>

#### You can use [Memo2Anki](https://github.com/Kartoffel0/Memo2Anki) to mine from the pdfs

# Requirements
- Prawn `gem install prawn`
- MiniMagick `gem install mini_magick`

- [Image Magick](https://imagemagick.org/script/download.php)

# Usage
Process your manga volume(s) using [Mokuro](https://github.com/kha-white/mokuro)

### Single Volume conversion
`ruby Mokuro2Pdf.rb -i "[1]" -o "[2]" -n "[3]" -g [4] -f [5] -w "[6]"`
  - **[1] - Path to volume's images folder, relative/absolute**
  - **[2] - Path to volume's [mokuro _ocr folder](https://github.com/Kartoffel0/Mokuro2Pdf/blob/master/img/folders.JPG), defaults to `Mokuro2Pdf/_ocr/[1]` if [1] is relative**
  - **[3] (Optional) - Generated pdf's filename, defaults to volume's images folder's name**
  - **[4] (Optional) - Gamma value to be used on all pages, defaults to 0.8**
  - **[5] (Optional) - Selectable text's font transparency, defaults to 0.2**
  - **[6] (Optional) - Output folder's path, defaults to [1]'s root folder**

"`ruby Mokuro2Pdf.rb -i "[ばらスィー] 苺ましまろ 第01巻" -n "苺ましまろ 第01巻" -f 0.1 -g 0.5`"
 
 This will generate a `[2] - MKR2PDF.pdf` pdf file

### Multiple Volumes conversion
Create a parent folder containing all the volumes you want to convert, one for the images and another for the jsons

`ruby Mokuro2Pdf.rb -p "[1]" -q "[2]" -g [3] -f [4] -w "[5]"`
  - **[1] - Parent images folder's path, must be absolute**
  - **[2] - Parent jsons folder's path, must be absolute**
  - **[3] (Optional) - Gamma value to be used on all pages, defaults to 0.8**
  - **[4] (Optional) - Selectable text's font transparency, defaults to 0.2**
  - **[5] (Optional) - Output folder's path, defaults to Mokuro2Pdf.rb's root folder**

"`ruby Mokuro2Pdf.rb -p "C:/Users/Ghabriel/Desktop/Manga" -q "C:/Users/Ghabriel/Documents/
Mokuro2Pdf/_ocr" -g 1 -w "C:/Users/Ghabriel/Desktop/Manga/PDF"`"

This will generate a `[foldername] - MKR2PDF.pdf` pdf file for each folder inside [1]

# Mining
[Memo2Anki](https://github.com/Kartoffel0/Memo2Anki)

#### A [20 page demo](https://github.com/Kartoffel0/Mokuro2Pdf/blob/master/Mokuro2Pdf-Demo%20-%20MKR2PDF.pdf) is avaiable, to read it on your kindle simply drag and drop "Mokuro2Pdf-Demo - MKR2PDF.pdf" to your kindle's documents folder
