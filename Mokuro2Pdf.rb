require 'prawn'
require 'nokogiri'
require 'cgi'
require 'mini_magick'
require 'fileutils'

FileUtils.mkdir_p "tmp"

puts "Mokuro2Pdf"
puts "Converting #{ARGV[0]} to #{ARGV[1]}.pdf"
if ARGV.length >= 3
    puts "Using #{ARGV[2]} as the gamma value"
    gammaValue = ARGV[2]
else
    puts "Using the default(0.8) gamma value"
    gammaValue = 0.8
end
filename = ARGV[1]

info = {
    Title: filename,
    Language: 'ja'
}

mokuroHtml = Nokogiri::HTML(File.read(ARGV[0]))
mokuroPages = mokuroHtml.css('div[class="pageContainer"]')

for page in 0...mokuroPages.length do
    pageStyle = mokuroPages[page]["style"]
    pageWidth = pageStyle.match /(?<=width\:).+?(?=;)/
    pageWidth = Integer(pageWidth[0])
    pageHeight = pageStyle.match /(?<=height\:).+?(?=;)/
    pageHeight = Integer(pageHeight[0])
    pageBg = pageStyle.match /(?<=background\-image\:url\(\").+?(?=\"\)\;)/
    pageBg = CGI::unescape(pageBg[0])
    pageBgMagick = MiniMagick::Image.open(pageBg)
    pageBgMagick.gamma gammaValue
    pageBgMagick.write "tmp/page-#{page}"
    pageBgMagickPath = "tmp/page-#{page}"
    if page == 0
        pdf = Prawn::Document.new(page_size: [pageWidth, pageHeight], margin: [0, 0, 0, 0], info: info)
    else
        pdf.start_new_page(size: [pageWidth, pageHeight], margin: [0, 0, 0, 0])
    end
    pdf.image pageBgMagickPath, height: pageHeight, width: pageWidth, at: [0, pageHeight]
    pageText = mokuroPages[page].css('div[class="textBox"]')
    pdf.transparent(0.2) do
        pdf.font("ipaexg.ttf")
        for box in 0...pageText.length do
            boxStyle = pageText[box]["style"]
            boxLeft = boxStyle.match /(?<=left\:).+?(?=;)/
            boxLeft = Integer(boxLeft[0])
            boxTop = boxStyle.match /(?<=top\:).+?(?=;)/
            boxTop = Integer(boxTop[0])
            boxFSize = boxStyle.match /(?<=font-size\:).+?(?=\.\d*px;|px)/
            boxFSize = Integer(boxFSize[0])
            if boxStyle.match(/vertical/)
                isBoxVert = true
            else
                isBoxVert = false
            end
            textBox = []
            boxText = pageText[box].css('p')
            for p in boxText do
                textBox.append(p.text)
            end
            if isBoxVert
                boxWidth = boxStyle.match /(?<=width\:).+?(?=;)/
                boxWidth = Integer(boxWidth[0])
                linesWidth = boxFSize * textBox.length
                lineSpace = boxFSize + ((boxWidth - linesWidth)/textBox.length)
            else
                boxHeight = boxStyle.match /(?<=height\:).+?(?=;)/ 
                boxHeight = Integer(boxHeight[0])
                linesHeight = boxFSize * textBox.length
                lineSpace = boxFSize + ((boxHeight - linesHeight)/textBox.length)
            end
            horBoxUp = (pageHeight - boxTop) - boxFSize
            for lineBef in textBox.reverse do
                boxUp = (pageHeight - boxTop) - boxFSize
                line = lineBef.gsub(/(．．．)/, "…")
                if isBoxVert
                    for char in 0...line.length do
                        if line[char] == "ー" || line[char] == "…" || line[char] == "〜"
                            pdf.draw_text line[char], size: boxFSize, rotate: -90, at: [boxLeft, boxUp + boxFSize]
                        else
                            pdf.draw_text line[char], size: boxFSize, at: [boxLeft, boxUp]
                        end
                        boxUp -= boxFSize - 2
                    end
                    boxLeft += lineSpace
                else
                    pdf.draw_text line, size: boxFSize, at:[boxLeft, horBoxUp]
                    horBoxUp -= lineSpace
                end
            end
        end
    end
end    

FileUtils.remove_dir("tmp")
pdf.render_file("#{filename} - MKR2PDF.pdf")
puts "Done!"