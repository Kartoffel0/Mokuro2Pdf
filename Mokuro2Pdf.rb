require 'prawn'
require 'nokogiri'
require 'cgi'
require 'mini_magick'
require 'fileutils'
require 'json'

FileUtils.mkdir_p "tmp"

puts "Mokuro2Pdf"
puts "Converting #{ARGV[0]} to #{ARGV[1]} - MKR2PDF.pdf"
filename = ARGV[1]

if ARGV.length >= 3
    puts "Using #{ARGV[2]} as the gamma value"
    gammaValue = ARGV[2]
else
    puts "Using the default(0.8) gamma value"
    gammaValue = 0.8
end

info = {
    Title: filename,
    Language: 'ja'
}

mokuroHtml = Nokogiri::HTML(File.read(ARGV[0]))
mokuroPages = mokuroHtml.css('div[class="pageContainer"]')

pages = {}

for page in 0...mokuroPages.length do
    pageStyle = mokuroPages[page]["style"]
    pageWidth = pageStyle.match /(?<=width\:).+?(?=;)/
    pageWidth = Integer(pageWidth[0])
    pageHeight = pageStyle.match /(?<=height\:).+?(?=;)/
    pageHeight = Integer(pageHeight[0])
    pageBg = pageStyle.match /(?<=background\-image\:url\(\").+?(?=\"\)\;)/
    pageBg = CGI::unescape(pageBg[0])
    pages[page+1] = pageBg
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
            boxWidth = boxStyle.match /(?<=width\:).+?(?=;)/
            boxWidth = Integer(boxWidth[0])
            boxHeight = boxStyle.match /(?<=height\:).+?(?=;)/
            boxHeight = Integer(boxHeight[0])
            boxFSizeMk = boxStyle.match /(?<=font-size\:).+?(?=\.\d*px;|px)/
            boxFSizeMk = Integer(boxFSizeMk[0])
            boxFSize = 0
            if boxStyle.match(/vertical/)
                isBoxVert = true
            else
                isBoxVert = false
            end
            textBox = []
            longest = 1
            boxText = pageText[box].css('p')
            for p in boxText do
                if p.text.gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/[《『「(\[\{（〔［｛〈【＜≪≫＞】〉｝］〕）\}\])」』》]/, "").length > longest
                    if /[!！?？]+$/.match?(p.text)
                        longest = p.text.gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/[《『「(\[\{（〔［｛〈【＜≪．≫＞】〉｝］〕）\}\])」』》]/, "").gsub(/[!！?？]+$/, "").length + 1
                    else
                        longest = p.text.gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/[《『「(\[\{（〔［｛〈【＜≪．≫＞】〉｝］〕）\}\])」』》]/, "").length
                    end
                end
                textBox.append(p.text)
            end
            
            if isBoxVert
                while ((boxFSize + 0.1) * longest) <= boxHeight
                    boxFSize += 0.1
                end
                if textBox.length > 1 && ((boxFSize * 1) * textBox.length) > boxWidth
                    boxFSize = boxFSizeMk
                end
            else
                while ((boxFSize + 0.1) * longest) <= boxWidth
                    boxFSize += 0.1
                end
                if textBox.length > 1 && ((boxFSize * 1) * textBox.length) > boxHeight
                    boxFSize = boxFSizeMk
                end
            end

            lineSpace = 1.1

            if isBoxVert
                if textBox.length > 1 && (((boxFSize * 1.1) * textBox.length) - (boxFSize * 0.1)) < (boxWidth)
                    while (((boxFSize * lineSpace) * textBox.length) - (boxFSize * (lineSpace - 1))) < (boxWidth)
                        lineSpace += 0.05
                    end
                end
            else
                if textBox.length > 1 && (((boxFSize * 1.1) * textBox.length) - (boxFSize * 0.1)) < (boxHeight)
                    while (((boxFSize * lineSpace) * textBox.length) - (boxFSize * (lineSpace - 1))) < (boxHeight)
                        lineSpace += 0.05
                    end
                end
            end

            horBoxUp = (pageHeight - boxTop) - boxFSize
            if isBoxVert
                for lineBef in textBox.reverse do
                    boxUp = (pageHeight - boxTop) - boxFSize
                    line = lineBef.gsub(/(．．．)/, "…")
                    for char in 0...line.length do
                        if /[ー…〜〜《『「\(\[\{（〔［｛〈【＜≪≫＞】〉｝］〕）\}\]\)」』》]/.match?(line[char])
                            if /[《『「\(\[\{（〔［｛〈【＜≪≫＞】〉｝］〕）\}\]\)」』》]/.match?(line[char])
                                if /[《『「\(\[\{（〔［｛〈【＜≪]/.match?(line[char])
                                    pdf.draw_text line[char], size: boxFSize, rotate: -90, at: [boxLeft, boxUp + boxFSize + (boxFSize * 0.5)]
                                    boxUp -= boxFSize * 0.5
                                else
                                    pdf.draw_text line[char], size: boxFSize, rotate: -90, at: [boxLeft, boxUp + boxFSize]
                                    boxUp -= boxFSize * 0.5
                                end
                            else
                                pdf.draw_text line[char], size: boxFSize, rotate: -90, at: [boxLeft, boxUp + boxFSize]
                                boxUp -= boxFSize
                            end
                        else
                            if /[ぁァぇェぃィぉォぅゥゃャょョっッ]/.match?(line[char])
                                pdf.draw_text line[char], size: boxFSize, at: [boxLeft, boxUp]
                                boxUp -= boxFSize * 0.8
                            else
                                pdf.draw_text line[char], size: boxFSize, at: [boxLeft, boxUp]
                                boxUp -= boxFSize
                            end
                        end
                    end
                    boxLeft += boxFSize * lineSpace
                end
            else
                for lineBef in textBox do
                    line = lineBef.gsub(/(．．．)/, "…")
                    pdf.draw_text line, size: boxFSize, at:[boxLeft, horBoxUp]
                    horBoxUp -= boxFSize * lineSpace
                end
            end
        end
    end
end    

File.write("#{filename} - MKR2PDF.json", JSON.dump(pages))
FileUtils.remove_dir("tmp")
pdf.render_file("#{filename} - MKR2PDF.pdf")
puts "Done!"