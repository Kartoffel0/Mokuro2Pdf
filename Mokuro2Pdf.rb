require 'prawn'
require 'json'
require 'mini_magick'
require 'fileutils'
require 'optparse'

options = {}
OptionParser.new do |opt|
    opt.banner = "Usage: Mokuro2Kindle.rb [options]"
    opt.on("-i IMAGES", "--imageFolder IMAGES", "Folder containing all manga pages") do |i|
        options[:imageFolder] = i
    end
    opt.on("-n NAME", "--name NAME", "Filename the created pdf will have") do |n|
        options[:filename] = n
    end
    opt.on("-g GAMMA", "--gamma GAMMA", "Gamma value to be used on all images, default = 0.8") do |g|
        options[:gamma] = g
    end
    opt.on("-o OCRFOLDER", "--ocr OCRFOLDER", "Folder containing all manga pages's ocr data, default = _ocr/#{options[:imageFolder]}") do |o|
        options[:ocrFolder] = o
    end
end.parse!

FileUtils.mkdir_p "tmp"

if !options.key?(:filename) || options[:filename] == ''
    options[:filename] = options[:imageFolder]
end

puts "Mokuro2Pdf"
puts "Converting '#{options[:imageFolder]}/' to '#{options[:filename]} - MKR2PDF.pdf'"
if options.key?(:gamma)
    puts "Using #{options[:gamma]} as the gamma value"
else
    puts "Using the default(0.8) gamma value"
    options[:gamma] = 0.8
end
if !options.key?(:ocrFolder)
    puts "Using the default '_ocr/#{options[:imageFolder]}/' ocr folder path"
    options[:ocrFolder] = "_ocr/#{options[:imageFolder]}"
else
    puts "Using the defined '#{options[:ocrFolder]}/' ocr folder path"
end

pages = Dir.glob("*", base: options[:imageFolder]).sort
ocrs = Dir.glob("*.json", base: options[:ocrFolder]).sort
puts "#{pages.length} Pages found"
puts "#{ocrs.length} Jsons found"

pagesJson = {}

info = {
    Title: options[:filename],
    Language: 'ja'
}

for i in 0...pages.length do
    puts i + 1
    page = JSON.parse(File.read("#{options[:ocrFolder]}/#{ocrs[i]}"))
    pageWidth = page["img_width"]
    pageHeight = page["img_height"]
    pageImg = "#{options[:imageFolder]}/#{pages[i]}"
    pagesJson[i+1] = pageImg
    pageBgMagick = MiniMagick::Image.open(pageImg)
    pageBgMagick.gamma options[:gamma]
    pageBgMagick.write "tmp/page-#{i}"
    pageBgMagickPath = "tmp/page-#{i}"
    if i == 0
        pdf = Prawn::Document.new(page_size: [pageWidth, pageHeight], margin: [0, 0, 0, 0], info: info)
    else
        pdf.start_new_page(size: [pageWidth, pageHeight], margin: [0, 0, 0, 0])
    end
    pdf.image pageBgMagickPath, height: pageHeight, width: pageWidth, at: [0, pageHeight]
    pageText = page["blocks"]
    pdf.transparent(0.2) do
        pdf.font("ipaexg.ttf")
        for b in 0...pageText.length do
            isBoxVert = pageText[b]["vertical"]
            yAxisMed = pageText[b]["lines_coords"].reduce(0) {|total, line| total + (line[0][1] <= line[1][1] ? line[0][1] : line[1][1])}/pageText[b]["lines"].length
            yAxisBox = pageText[b]["box"][1]
            rightBox = pageText[b]["box"][2]
            leftBox = pageText[b]["box"][0]
            linesLeft = pageText[b]["lines_coords"].reduce(pageWidth) {|lefttest, line| (line[0][0] <= line[3][0] ? line[0][0] : line[3][0]) < lefttest ? (line[0][0] <= line[3][0] ? line[0][0] : line[3][0]) : lefttest}
            linesRight = pageText[b]["lines_coords"].reduce(0) {|righttest, line| (line[1][0] <= line[2][0] ? line[1][0] : line[2][0]) > righttest ? (line[1][0] <= line[2][0] ? line[1][0] : line[2][0]) : righttest}
            yAxisMatch = (yAxisMed >= (yAxisBox - 10) && yAxisMed <= (yAxisBox + 10))
            sidesMatch = ((linesLeft >= (leftBox - 10) && linesLeft <= (leftBox + 10)) && (linesRight >= (rightBox - 10) && linesRight <= (rightBox + 10)))
            fontSize = 0
            if !isBoxVert
                for l in 0...pageText[b]["lines"].length do
                    line = pageText[b]["lines"][l].gsub(/(．．．)/, "…")
                    lineLeft = pageText[b]["lines_coords"][l][3][0]
                    lineRight = pageText[b]["lines_coords"][l][2][0]
                    lineBottom = pageText[b]["lines_coords"][l][3][1]
                    lineWidth = pageText[b]["lines_coords"][l][2][0] - lineLeft
                    lineHeight = lineBottom - pageText[b]["lines_coords"][l][0][1]
                    fontSize = 0
                    while ((fontSize + 0.1) * line.length) <= lineWidth && fontSize <= lineHeight
                        fontSize += 0.1
                    end
                    pdf.draw_text line, size: fontSize, at:[lineLeft, pageHeight - lineBottom]
                end
            elsif !(yAxisMatch && sidesMatch) && isBoxVert
                textLevels = pageText[b]["lines_coords"].map{|line| line[0][1]}.sort.uniq
                textLevels = textLevels.each_with_index {|y, idx| while idx + 1 < textLevels.length && (y >= (textLevels[idx + 1] - 10) && y <= (textLevels[idx + 1] + 10)) do textLevels.delete_at(idx + 1) end} 
                levelLeft = []
                levelRight = []
                levelLine = {}
                for level in 0...textLevels.length do
                    levelLeft << pageText[b]["lines_coords"].reduce(pageWidth) {|lefttest, line| (line[0][1] <= line[1][1] ? line[0][1] : line[1][1]) >= (textLevels[level] - 10) && (line[0][1] <= line[1][1] ? line[0][1] : line[1][1]) <= (textLevels[level] + 10) ? (line[0][0] <= line[3][0] ? line[0][0] : line[3][0]) < lefttest ? (line[0][0] <= line[3][0] ? line[0][0] : line[3][0]) : lefttest : lefttest}
                    levelRight << pageText[b]["lines_coords"].reduce(0) {|righttest, line| (line[0][1] <= line[1][1] ? line[0][1] : line[1][1]) >= (textLevels[level] - 10) && (line[0][1] <= line[1][1] ? line[0][1] : line[1][1]) <= (textLevels[level] + 10) ? (line[1][0] <= line[2][0] ? line[1][0] : line[2][0]) > righttest ? (line[1][0] <= line[2][0] ? line[1][0] : line[2][0]) : righttest : righttest}
                end
                levelWidth = textLevels.map.with_index {|level, idx| [level, levelRight[idx], levelLeft[idx]]}
                for l in 0...pageText[b]["lines"].length do
                    lineTmp = pageText[b]["lines"][l].gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/(．)/, "").gsub(/\s/, "")
                    if /[!！?？]+$/.match?(lineTmp)
                        lineTmp = lineTmp.gsub(/[!！?？]+$/, "") + "！"
                    end
                    scanPar = lineTmp.scan(/[《『「(\[\{（〔［｛〈【＜≪≫＞】〉｝］〕）\}\])」』》]/)
                    lineLength = lineTmp.length + (scanPar.length > 0 ? scanPar.length * 0.25 : 0)
                    heigthLeft = (pageText[b]["lines_coords"][l][3][1] - pageText[b]["lines_coords"][l][0][1])
                    heigthRight = (pageText[b]["lines_coords"][l][2][1] - pageText[b]["lines_coords"][l][1][1])
                    boxHeight = (pageText[b]["box"][3] - pageText[b]["box"][1])
                    widthTop = (pageText[b]["lines_coords"][l][1][0] - pageText[b]["lines_coords"][l][0][0])
                    widthBottom = (pageText[b]["lines_coords"][l][2][0] - pageText[b]["lines_coords"][l][3][0])
                    lineHeight = heigthLeft <= heigthRight ? heigthLeft : heigthRight
                    lineHeight = boxHeight <= lineHeight ? boxHeight : lineHeight
                    lineWidth = (widthTop <= widthBottom) ? widthTop : widthBottom
                    if isBoxVert
                        while (((fontSize + 0.1) * lineLength) <= lineHeight) && fontSize <= lineWidth
                            fontSize += 0.1
                        end
                    else
                        while (((fontSize + 0.1) * lineLength) <= lineWidth) && fontSize <= lineHeight
                            fontSize += 0.1
                        end
                    end
                    for level in textLevels do
                        levelLine[level] = [] if !(levelLine.key?(level))
                        lineLevelThreshLow = (pageText[b]["lines_coords"][l][0][1] >= (level - 10) || pageText[b]["lines_coords"][l][1][1] >= (level - 10))
                        lineLevelThreshHigh = (pageText[b]["lines_coords"][l][0][1] <= (level + 10) || pageText[b]["lines_coords"][l][1][1] <= (level + 10))
                        if lineLevelThreshLow && lineLevelThreshHigh
                            levelLine[level] << [pageText[b]["lines"][l].gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/．/, "").gsub(/\s/, ""), fontSize]
                        end
                    end
                end
                for level in 0...textLevels.length do
                    boxWidth = levelWidth[level][1] - levelWidth[level][2]
                    boxLength = levelLine[textLevels[level]].length
                    boxLeft = levelWidth[level][2]
                    boxFSize = levelLine[textLevels[level]].reduce(99999) {|smallest, line| line[1] < smallest ? line[1] : smallest}
                    lineSpace = 1.1
                    if boxLength > 1 && (((boxFSize * 1.1) * boxLength) - (boxFSize * 0.1)) < (boxWidth)
                        while (((boxFSize * lineSpace) * boxLength) - (boxFSize * (lineSpace - 1))) < (boxWidth)
                            lineSpace += 0.05
                        end
                    end
                    for line in levelLine[textLevels[level]].reverse do
                        line = line[0]
                        boxUp = (pageHeight - textLevels[level]) - boxFSize
                        numberComp = ''
                        for char in 0...line.length do
                            if /[ー…‥～~《『「\(\[\{（〔［｛〈【＜≪≫＞】〉｝］〕）\}\]\)」』》]/.match?(line[char])
                                if /[《『「\(\[\{（〔［｛〈【＜≪≫＞】〉｝］〕）\}\]\)」』》]/.match?(line[char])
                                    if /[《『「\(\[\{（〔［｛〈【＜≪]/.match?(line[char])
                                        pdf.draw_text line[char], size: boxFSize, rotate: -90, at: [boxLeft, boxUp + boxFSize + (boxFSize * 0.2)]
                                        boxUp -= boxFSize * 0.8
                                    elsif /[≫＞】〉｝］〕）\}\]\)」』》]/.match?(line[char])
                                        pdf.draw_text line[char], size: boxFSize, rotate: -90, at: [boxLeft, boxUp + boxFSize - (boxFSize * 0.2)]
                                        boxUp -= boxFSize * 0.8
                                    else
                                        pdf.draw_text line[char], size: boxFSize, rotate: -90, at: [boxLeft, boxUp + boxFSize]
                                        boxUp -= boxFSize * 0.8
                                    end
                                else
                                    pdf.draw_text line[char], size: boxFSize, rotate: -90, at: [boxLeft, boxUp + boxFSize]
                                    boxUp -= boxFSize
                                end
                            elsif /[０-９0-9]/.match?(line[char])
                                numberComp += line[char]
                                if !/[０-９0-9]/.match?(line[char + 1])
                                    if numberComp.length == 2
                                        tmpFSize = boxFSize * 0.4
                                        pdf.draw_text numberComp, size: tmpFSize, at: [boxLeft, boxUp + (tmpFSize/2)]
                                        boxUp -= boxFSize
                                    else
                                        for n in 0...numberComp.length
                                            pdf.draw_text numberComp[n], size: boxFSize, at: [boxLeft, boxUp]
                                            boxUp -= boxFSize
                                        end
                                    end
                                    numberComp = ''
                                end
                            else
                                if /[ぁァぇェぃィぉォぅゥゃャょョっッ]/.match?(line[char])
                                    pdf.draw_text line[char], size: boxFSize, at: [boxLeft, boxUp - (boxFSize * 0.1)]
                                    boxUp -= boxFSize
                                else
                                    pdf.draw_text line[char], size: boxFSize, at: [boxLeft, boxUp]
                                    boxUp -= boxFSize
                                end
                            end
                        end
                        boxLeft += boxFSize * lineSpace
                    end
                end
            else
                boxLeft = pageText[b]["box"][0]
                boxTop = pageText[b]["box"][1]
                boxWidth = pageText[b]["box"][2] - pageText[b]["box"][0]
                boxHeight = pageText[b]["box"][3] - pageText[b]["box"][1]
                isBoxVert = pageText[b]["vertical"]
                textBox = pageText[b]["lines"]
                boxFSize = 0
                longest = 1
                lineSpace = 1.1
                for l in textBox do
                    lineTmp = l.gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/(．)/, "").gsub(/\s/, "")
                    if /[!！?？]+$/.match?(lineTmp)
                        lineTmp = lineTmp.gsub(/[!！?？]+$/, "") + "！"
                    end
                    scanPar = lineTmp.scan(/[《『「(\[\{（〔［｛〈【＜≪≫＞】〉｝］〕）\}\])」』》]/)
                    lineLength = lineTmp.length + (scanPar.length > 0 ? scanPar.length * 0.25 : 0)
                    if lineLength > longest
                        longest = lineLength
                    end
                end
                if isBoxVert
                    if textBox.length == 1
                        while ((boxFSize + 0.1) * longest) <= boxHeight && boxFSize <= boxWidth
                            boxFSize += 0.1
                        end
                    else
                        while ((boxFSize + 0.1) * longest) <= boxHeight
                            boxFSize += 0.1
                        end
                    end
                else
                    if textBox.length == 1
                        while boxFSize <= boxHeight && ((boxFSize + 0.1) * longest) <= boxWidth
                            boxFSize += 0.1
                        end
                    else
                        while ((boxFSize + 0.1) * longest) <= boxWidth
                            boxFSize += 0.1
                        end
                    end
                end
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
                for lineBef in textBox.reverse do
                    boxUp = (pageHeight - boxTop) - boxFSize
                    line = lineBef.gsub(/(．．．)/, "…")
                    numberComp = ''
                    for char in 0...line.length do
                        if /[ー…‥～~《『「\(\[\{（〔［｛〈【＜≪≫＞】〉｝］〕）\}\]\)」』》]/.match?(line[char])
                            if /[《『「\(\[\{（〔［｛〈【＜≪≫＞】〉｝］〕）\}\]\)」』》]/.match?(line[char])
                                if /[《『「\(\[\{（〔［｛〈【＜≪]/.match?(line[char])
                                    pdf.draw_text line[char], size: boxFSize, rotate: -90, at: [boxLeft, boxUp + boxFSize + (boxFSize * 0.2)]
                                    boxUp -= boxFSize * 0.8
                                elsif /[≫＞】〉｝］〕）\}\]\)」』》]/.match?(line[char])
                                    pdf.draw_text line[char], size: boxFSize, rotate: -90, at: [boxLeft, boxUp + boxFSize - (boxFSize * 0.2)]
                                    boxUp -= boxFSize * 0.8
                                else
                                    pdf.draw_text line[char], size: boxFSize, rotate: -90, at: [boxLeft, boxUp + boxFSize]
                                    boxUp -= boxFSize * 0.8
                                end
                            else
                                pdf.draw_text line[char], size: boxFSize, rotate: -90, at: [boxLeft, boxUp + boxFSize]
                                boxUp -= boxFSize
                            end
                        elsif /[０-９0-9]/.match?(line[char])
                            numberComp += line[char]
                            if !/[０-９0-9]/.match?(line[char + 1])
                                if numberComp.length == 2
                                    tmpFSize = boxFSize * 0.4
                                    pdf.draw_text numberComp, size: tmpFSize, at: [boxLeft, boxUp + (tmpFSize/2)]
                                    boxUp -= boxFSize
                                else
                                    for n in 0...numberComp.length
                                        pdf.draw_text numberComp[n], size: boxFSize, at: [boxLeft, boxUp]
                                        boxUp -= boxFSize
                                    end
                                end
                                numberComp = ''
                            end
                        else
                            if /[ぁァぇェぃィぉォぅゥゃャょョっッ]/.match?(line[char])
                                pdf.draw_text line[char], size: boxFSize, at: [boxLeft, boxUp - (boxFSize * 0.1)]
                                boxUp -= boxFSize
                            else
                                pdf.draw_text line[char], size: boxFSize, at: [boxLeft, boxUp]
                                boxUp -= boxFSize
                            end
                        end
                    end
                    boxLeft += boxFSize * lineSpace
                end
            end
        end
    end
end
File.write("#{options[:filename]} - MKR2PDF.json", JSON.dump(pagesJson))
FileUtils.remove_dir("tmp")
pdf.render_file("#{options[:filename]} - MKR2PDF.pdf")
puts "Done!"