# Mokuro2Pdf
Create pdf files with selectable text from [Mokuro](https://github.com/kha-white/mokuro)'s html overlay

<img src="img/Mokuro2Pdf on Kindle.png" width=auto heigth=auto>

#### You can use [Memo2Anki](https://github.com/Kartoffel0/Memo2Anki) to mine from the pdfs

# Requirements
- Prawn `gem install prawn`
- MiniMagick `gem install mini_magick`

- [Image Magick](https://imagemagick.org/script/download.php)

# Usage
### Use [TheRealDynamo's Colab Notebook](https://colab.research.google.com/drive/1sxjIyupBhCBpHHZZk6CPrZ61noeJO-8o?usp=sharing) 
Follow the instructions in order to Mokuro and convert your manga volumes to pdf, completely online no setup required

or

Process your manga volume(s) using [Mokuro](https://github.com/kha-white/mokuro)

### Arguments
```
Mandatory

Single volume
-i path     - Path to volume's images folder, relative/absolute
-o path     - Path to volume's mokuro _ocr folder, defaults to Mokuro2Pdf/_ocr/-i if -i is relative

Multiple volumes
-p path     - Parent images folder's path, must be absolute
-q path     - Parent jsons folder's path, must be absolute
```

```
Optional
-n filename - Generated pdf's filename, defaults to volume's images folder's name
-w path     - Output folder's path, defaults to volume/Mokuro2Pdf's root folder
-g value    - Gamma value to be used on all pages, ranges from 0.0 to 1.0, defaults to 1
-f value    - Selectable text's font transparency, ranges from 0.0 to 1.0, defaults to 0
-u          - Turns on upscaling to Kindle's pdf viewport resolution, improves image quality on Kindle
-c          - Converts all images to JPG(92) for a smaller file size
-s          - Use Natural Sorting for filenames, might break properly named files so use only when pages get placed out of order
```

### Single Volume conversion
`ruby Mokuro2Pdf.rb -i "image path" -o "ocr path"`

"`ruby Mokuro2Pdf.rb -i "[ばらスィー] 苺ましまろ 第01巻" -n "苺ましまろ 第01巻" -f 0.1 -g 0.5 -u`"

will generate a `苺ましまろ 第01巻 - MKR2PDF.pdf` pdf file

### Multiple Volumes conversion
Create a parent folder containing all the volumes you want to convert, one for the images and another for the jsons

`ruby Mokuro2Pdf.rb -p "parent folder path" -q "parent json path"`

"`ruby Mokuro2Pdf.rb -p "C:/Users/Ghabriel/Desktop/Manga" -q "C:/Users/Ghabriel/Documents/
Mokuro2Pdf/_ocr" -g 1 -w "C:/Users/Ghabriel/Desktop/Manga/PDF" -u`"

will generate a `[foldername] - MKR2PDF.pdf` pdf file for each folder inside `-p`

# Kindle usage
Use `-g 0.8` for better contrast, `-u` for [better image quality](https://github.com/Kartoffel0/Mokuro2Pdf/blob/master/img/upscale_demo.png)

You can mine from the pdfs using [Memo2Anki](https://github.com/Kartoffel0/Memo2Anki)

#### A [20 page demo](https://github.com/Kartoffel0/Mokuro2Pdf/blob/master/Mokuro2Pdf-Demo%20-%20MKR2PDF.pdf) is avaiable, to read it on your kindle simply drag and drop "Mokuro2Pdf-Demo - MKR2PDF.pdf" to your kindle's documents folder
