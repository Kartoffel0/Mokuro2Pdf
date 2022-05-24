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
        options[:gamma] = g.to_f
    end
    opt.on("-o OCRFOLDER", "--ocr OCRFOLDER", "Folder containing all manga pages's ocr data, default = _ocr/#{options[:imageFolder]}") do |o|
        options[:ocrFolder] = o
    end
    opt.on("-p PARENTimgFOLDER", "--parent_img_folder PARENTimgFOLDER", "Folder containing all volumes's images folders") do |p|
        options[:parentImg] = p
    end
    opt.on("-q PARENTocrFOLDER", "--parent_ocr_folder PARENTocrFOLDER", "Folder containing all volumes's ocr data folders") do |q|
        options[:parentOcr] = q
    end
    opt.on("-f FONT_TRANSPARENCY", "--font_transparency FONT_TRANSPARENCY", "Selectable text's transparency, default = 0.2") do |f|
        options[:fontTransparency] = f.to_f
    end
end.parse!
puts ""
puts "Mokuro2Pdf"
if options.key?(:gamma)
    puts "Using the defined #{options[:gamma]} gamma value"
else
    puts "Using the default(0.8) gamma value"
    options[:gamma] = 0.8
end
if options.key?(:fontTransparency)
    puts "Using the defined #{options[:fontTransparency]} font transparency"
else
    puts "Using the default(0.2) font transparency"
    options[:fontTransparency] = 0.2
end
folders = []
if !options.key?(:parentImg)
    if !options.key?(:filename) || options[:filename] == ''
        options[:filename] = options[:imageFolder]
    end
    folder = []
    puts "Converting '#{options[:imageFolder]}/' to '#{options[:filename]} - MKR2PDF.pdf'"
    if !options.key?(:ocrFolder)
        puts "Using the default '_ocr/#{options[:imageFolder]}/' ocr folder path"
        options[:ocrFolder] = "_ocr/#{options[:imageFolder]}"
    else
        puts "Using the defined '#{options[:ocrFolder]}/' ocr folder path"
    end
    pages = Dir.glob(["*.jpg", "*.jpeg", "*.jpe", "*.jif", "*.jfif", "*.jfi", "*.png", "*.gif", "*.webp", "*.tiff", "*.tif", "*.psd", "*.raw", "*.arw", "*.cr2", "*.nrw", "*.k25", "*.bmp", "*.dib", "*.jp2", "*.j2k", "*.jpf", "*.jpx", "*.jpm", "*.mj2"], base: options[:imageFolder]).sort
    ocrs = Dir.glob("*.json", base: options[:ocrFolder]).sort
    pages = pages.select {|item| File.file?("#{options[:imageFolder]}/#{item}")}
    ocrs = ocrs.select {|item| File.file?("#{options[:ocrFolder]}/#{item}")}
    puts "#{pages.length} Pages found"
    puts "#{ocrs.length} Jsons found"
    info = {
        Title: options[:filename],
        Language: 'ja'
    }
    folder.append(pages)
    folder.append(ocrs)
    folder.append(info)
    folder.append(options[:imageFolder])
    folder.append(options[:ocrFolder])
    folder.append(options[:imageFolder])
    folders.append(folder)
else
    volumesImg = Dir.glob("*", base: options[:parentImg]).sort
    volumesImg = volumesImg.select {|item| File.directory?("#{options[:parentImg]}/#{item}")}
    puts "#{volumesImg.length} folders found on '#{options[:parentImg]}/'\n"
    for volume in volumesImg do
        folder = []
        info = {
            Title: volume,
            Language: 'ja'
        }
        pages = Dir.glob(["*.jpg", "*.jpeg", "*.jpe", "*.jif", "*.jfif", "*.jfi", "*.png", "*.gif", "*.webp", "*.tiff", "*.tif", "*.psd", "*.raw", "*.arw", "*.cr2", "*.nrw", "*.k25", "*.bmp", "*.dib", "*.jp2", "*.j2k", "*.jpf", "*.jpx", "*.jpm", "*.mj2"], base: "#{options[:parentImg]}/#{volume}").sort
        ocrs = Dir.glob("*.json", base: "#{options[:parentOcr]}/#{volume}").sort
        pages = pages.select {|item| File.file?("#{options[:parentImg]}/#{volume}/#{item}")}
        ocrs = ocrs.select {|item| File.file?("#{options[:parentOcr]}/#{volume}/#{item}")}
        puts "\t#{volume} - #{pages.length} Pages found, #{ocrs.length} Jsons found\n"
        folder.append(pages)
        folder.append(ocrs)
        folder.append(info)
        folder.append("#{options[:parentImg]}/#{volume}")
        folder.append("#{options[:parentOcr]}/#{volume}")
        folder.append(volume)
        folders.append(folder)
    end
end
for folder in folders do
    pages = folder[0]
    ocrs = folder[1]
    info = folder[2]
    imgFolder = folder[3]
    ocrFolder = folder[4]
    jsonFolderPath = folder[5]
    pagesJson = {}
    puts "\nProcessing #{info[:Title]}..."
    for i in 0...pages.length do
        page = JSON.parse(File.read("#{ocrFolder}/#{ocrs[i]}"))
        pageWidth = page["img_width"]
        pageHeight = page["img_height"]
        pageImg = "#{imgFolder}/#{pages[i]}"
        pagesJson[i+1] = "#{jsonFolderPath}/#{pages[i]}"
        if options[:gamma] == 1
            pageBgMagickPath = pageImg
        else
            FileUtils.mkdir_p "tmp"
            pageBgMagick = MiniMagick::Image.open(pageImg)
            pageBgMagick.gamma options[:gamma]
            pageBgMagick.write "tmp/page-#{i}"
            pageBgMagickPath = "tmp/page-#{i}"
        end
        if i == 0
            pdf = Prawn::Document.new(page_size: [pageWidth, pageHeight], margin: [0, 0, 0, 0], info: info)
        else
            pdf.start_new_page(size: [pageWidth, pageHeight], margin: [0, 0, 0, 0])
        end
        pdf.image pageBgMagickPath, height: pageHeight, width: pageWidth, at: [0, pageHeight]
        pageText = page["blocks"]
        pdf.transparent(options[:fontTransparency]) do
            pdf.font("ipaexg.ttf")
            for b in 0...pageText.length do
                heightTreshold = pageHeight * 0.0075
                widthThreshold =pageWidth * 0.0075
                isBoxVert = pageText[b]["vertical"]
                yAxisMed = pageText[b]["lines_coords"].reduce(0) {|total, line| total + (line[0][1] <= line[1][1] ? line[0][1] : line[1][1])}/pageText[b]["lines"].length
                yAxisBox = pageText[b]["box"][1]
                rightBox = pageText[b]["box"][2]
                leftBox = pageText[b]["box"][0]
                linesLeft = pageText[b]["lines_coords"].reduce(pageWidth) {|lefttest, line| (line[0][0] <= line[3][0] ? line[0][0] : line[3][0]) < lefttest ? (line[0][0] <= line[3][0] ? line[0][0] : line[3][0]) : lefttest}
                linesRight = pageText[b]["lines_coords"].reduce(0) {|righttest, line| (line[1][0] <= line[2][0] ? line[1][0] : line[2][0]) > righttest ? (line[1][0] <= line[2][0] ? line[1][0] : line[2][0]) : righttest}
                yAxisMatch = (yAxisMed >= (yAxisBox - heightTreshold) && yAxisMed <= (yAxisBox + heightTreshold))
                sidesMatch = ((linesLeft >= (leftBox - widthThreshold) && linesLeft <= (leftBox + widthThreshold)) && (linesRight >= (rightBox - widthThreshold) && linesRight <= (rightBox + widthThreshold)))
                hasNumbers = /(?<![０-９0-9])[０-９0-9]{2,}(?![０-９0-9])/.match?(pageText[b]["lines"].join(" "))
                fontSize = 0
                if !isBoxVert
                    for l in 0...pageText[b]["lines"].length do
                        line = pageText[b]["lines"][l].gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/(．)/, "").gsub(/\s/, "").gsub(/[。\.．、，,]+$/, "")
                        lineLeft = pageText[b]["lines_coords"][l][3][0]
                        lineRight = pageText[b]["lines_coords"][l][2][0]
                        lineBottom = pageText[b]["lines_coords"][l][3][1] <= pageText[b]["lines_coords"][l][2][1] ? pageText[b]["lines_coords"][l][3][1] : pageText[b]["lines_coords"][l][2][1]
                        lineTop = pageText[b]["lines_coords"][l][0][1] <= pageText[b]["lines_coords"][l][1][1] ? pageText[b]["lines_coords"][l][0][1] : pageText[b]["lines_coords"][l][1][1]
                        lineWidth = pageText[b]["lines_coords"][l][2][0] - lineLeft
                        lineHeight = lineBottom - lineTop
                        fontSize = (lineWidth / line.length) <= (lineHeight * 2) ? (lineWidth / line.length) : (lineHeight * 2)
                        next if fontSize <= (pageText[b]["font_size"] * 0.15)
                        line = pageText[b]["lines"][l].strip.gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/(．)/, "").gsub(/\s/, "").gsub(/[。\.．、，,…‥!！?？：～~]+$/, "")
                        pdf.draw_text line, size: fontSize, at:[lineLeft, pageHeight - lineBottom]
                    end
                elsif !(yAxisMatch && sidesMatch) || hasNumbers
                    textLevels = pageText[b]["lines_coords"].map{|line| (line[0][1] <= line[1][1] ? line[0][1] : line[1][1])}.sort.uniq
                    textLevels = textLevels.each_with_index {|y, idx| while idx + 1 < textLevels.length && (y >= (textLevels[idx + 1] - heightTreshold) && y <= (textLevels[idx + 1] + heightTreshold)) do textLevels.delete_at(idx + 1) end} 
                    levelLeft = []
                    levelRight = []
                    levelLine = {}
                    for level in 0...textLevels.length do
                        levelLeft << pageText[b]["lines_coords"].reduce(pageWidth) {|lefttest, line| (line[0][1] <= line[1][1] ? line[0][1] : line[1][1]) >= (textLevels[level] - heightTreshold) && (line[0][1] <= line[1][1] ? line[0][1] : line[1][1]) <= (textLevels[level] + heightTreshold) ? (line[0][0] <= line[3][0] ? line[0][0] : line[3][0]) < lefttest ? (line[0][0] <= line[3][0] ? line[0][0] : line[3][0]) : lefttest : lefttest}
                        levelRight << pageText[b]["lines_coords"].reduce(0) {|righttest, line| (line[0][1] <= line[1][1] ? line[0][1] : line[1][1]) >= (textLevels[level] - heightTreshold) && (line[0][1] <= line[1][1] ? line[0][1] : line[1][1]) <= (textLevels[level] + heightTreshold) ? (line[1][0] >= line[2][0] ? line[1][0] : line[2][0]) > righttest ? (line[1][0] >= line[2][0] ? line[1][0] : line[2][0]) : righttest : righttest}
                    end
                    levelWidth = textLevels.map.with_index {|level, idx| [level, levelRight[idx], levelLeft[idx]]}
                    for l in 0...pageText[b]["lines"].length do
                        lineTmp = pageText[b]["lines"][l].gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/(．)/, "").gsub(/\s/, "")
                        if /[!！?？]+$/.match?(lineTmp)
                            lineTmp = lineTmp.gsub(/[!！?？]+$/, "!")
                        end
                        if /[０-９0-9]{2,3}/.match?(lineTmp)
                            lineTmp = lineTmp.gsub(/(?<![０-９0-9])[０-９0-9]{2,3}(?![０-９0-9])/, "!")
                        end
                        if /[a-zA-Zａ-ｚＡ-Ｚ]{2,3}/.match?(lineTmp)
                            lineTmp = lineTmp.gsub(/[a-zA-Zａ-ｚＡ-Ｚ]{2,3}/, "!")
                        end
                        scanPar = lineTmp.scan(/[《『「(\[\{（〔［｛〈【＜≪”"“゛″〝〟＂≫＞】〉｝］〕）\}\])」』》]/)
                        scanPt = lineTmp.scan(/[。\.．、，,]+$/)
                        lineTmp = lineTmp.gsub(/[《『「(\[\{（〔［｛〈【＜≪”"“゛″〝〟＂≫＞】〉｝］〕）\}\])」』》]/, "")
                        lineTmp = lineTmp.gsub(/[。\.．、，,]+$/, "")
                        lineLength = lineTmp.length + (scanPar.length > 0 ? scanPar.length * 0.8 : 0) + (scanPt.length > 0 ? scanPt.length * 0.5 : 0)
                        heigthLeft = (pageText[b]["lines_coords"][l][3][1] - pageText[b]["lines_coords"][l][0][1])
                        heigthRight = (pageText[b]["lines_coords"][l][2][1] - pageText[b]["lines_coords"][l][1][1])
                        boxHeight = (pageText[b]["box"][3] - pageText[b]["box"][1])
                        widthTop = (pageText[b]["lines_coords"][l][1][0] - pageText[b]["lines_coords"][l][0][0])
                        widthBottom = (pageText[b]["lines_coords"][l][2][0] - pageText[b]["lines_coords"][l][3][0])
                        ocrFSize = pageText[b]["font_size"]
                        lineHeight = heigthLeft <= heigthRight ? heigthLeft : heigthRight
                        lineHeight = boxHeight <= lineHeight ? boxHeight : lineHeight
                        lineWidth = (widthTop <= widthBottom) ? widthTop : widthBottom
                        fontSize = (lineHeight / lineLength) <= (lineWidth * 1.75) ? (lineHeight / lineLength) : (lineWidth * 1.75)
                        for level in textLevels do
                            levelLine[level] = [] if !(levelLine.key?(level))
                            lineTop = (pageText[b]["lines_coords"][l][0][1] <= pageText[b]["lines_coords"][l][1][1] ? pageText[b]["lines_coords"][l][0][1] : pageText[b]["lines_coords"][l][1][1])
                            lineLevelThreshLow = lineTop >= (level - heightTreshold)
                            lineLevelThreshHigh = lineTop <= (level + heightTreshold)
                            if lineLevelThreshLow && lineLevelThreshHigh
                                levelLine[level] << [pageText[b]["lines"][l], fontSize, ocrFSize]
                            end
                        end
                    end
                    for level in 0...textLevels.length do
                        boxWidth = levelWidth[level][1] - levelWidth[level][2]
                        boxLength = levelLine[textLevels[level]].length
                        boxLeft = levelWidth[level][2]
                        boxFSize = levelLine[textLevels[level]].reduce(99999) {|smallest, line| (line[1] < smallest) && (line[1] > (line[2] * 0.3)) ? line[1] : smallest}
                        lineSpace = 1.1
                        if boxLength > 1
                            lineSpace = ((boxWidth - (boxLength * boxFSize)) / (boxLength - 1)) + boxFSize
                        end
                        for line in levelLine[textLevels[level]].reverse do
                            next if line[1] <= (line[2] * 0.5)
                            line = line[0].strip.gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/(．)/, "").gsub(/\s/, "").gsub(/[。\.．、，,…‥!！?？：～~]+$/, "")
                            boxUp = (pageHeight - textLevels[level]) - boxFSize
                            numberComp = ''
                            ponctComp = ''
                            romComp = ''
                            for char in 0...line.length do
                                if /[《『「\(\[\{（〔［｛〈【＜≪≫＞】〉｝］〕）\}\]\)」』》]/.match?(line[char])
                                    boxUp -= boxFSize * 0.8
                                elsif /[。\.．、，,…‥!！?？：～~]/.match?(line[char])
                                    boxUp -= boxFSize
                                elsif /[０-９0-9]/.match?(line[char])
                                    numberComp += line[char]
                                    if (char + 1) > line.length || !/[０-９0-9]/.match?(line[char + 1])
                                        if numberComp.length == 2
                                            tmpFSize = boxFSize * 0.5
                                            pdf.draw_text numberComp, size: tmpFSize, at: [boxLeft, boxUp + (tmpFSize/2)]
                                            boxUp -= boxFSize
                                        elsif numberComp.length == 3
                                            tmpFSize = boxFSize * 0.35
                                            pdf.draw_text numberComp, size: tmpFSize, at: [boxLeft, boxUp + (tmpFSize/3)]
                                            boxUp -= boxFSize
                                        else
                                            for n in 0...numberComp.length
                                                pdf.draw_text numberComp[n], size: boxFSize, at: [boxLeft, boxUp]
                                                boxUp -= boxFSize
                                            end
                                        end
                                        numberComp = ''
                                    end
                                elsif /[!！?？]/.match?(line[char])
                                    ponctComp += line[char]
                                    if (char + 1) > line.length || !/[!！?？]/.match?(line[char + 1])
                                        tmpFSize = boxFSize / ponctComp.length
                                        pdf.draw_text ponctComp, size: tmpFSize, at: [boxLeft, boxUp]
                                        boxUp -= boxFSize
                                        ponctComp = ''
                                    end
                                elsif /[a-zA-Zａ-ｚＡ-Ｚ]/.match?(line[char])
                                    romComp += line[char]
                                    if (char + 1) > line.length || !/[a-zA-Zａ-ｚＡ-Ｚ]/.match?(line[char + 1])
                                        if romComp.length <= 3
                                            tmpFSize = boxFSize / romComp.length
                                            pdf.draw_text romComp, size: tmpFSize, at: [boxLeft, boxUp]
                                            boxUp -= boxFSize
                                        else
                                            for l in 0...romComp.length
                                                pdf.draw_text romComp[l], size: boxFSize, at: [boxLeft, boxUp]
                                                boxUp -= boxFSize
                                            end
                                        end
                                        romComp = ''
                                    end
                                else
                                    pdf.draw_text line[char], size: boxFSize, at: [boxLeft, boxUp]
                                    boxUp -= boxFSize
                                end
                            end
                            boxLeft += lineSpace
                        end
                    end
                else
                    boxLeft = pageText[b]["box"][0]
                    boxTop = pageText[b]["box"][1]
                    boxWidth = pageText[b]["box"][2] - pageText[b]["box"][0]
                    boxHeight = pageText[b]["box"][3] - pageText[b]["box"][1]
                    isBoxVert = pageText[b]["vertical"]
                    textBox = pageText[b]["lines"]
                    ocrFSize = pageText[b]["font_size"]
                    boxFSize = 0
                    longest = 1
                    lineSpace = 1.1
                    for l in textBox do
                        lineTmp = l.gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/(．)/, "").gsub(/\s/, "")
                        if /[!！?？]+$/.match?(lineTmp)
                            lineTmp = lineTmp.gsub(/[!！?？]+$/, "!")
                        end
                        if /[０-９0-9]{2,3}/.match?(lineTmp)
                            lineTmp = lineTmp.gsub(/(?<![０-９0-9])[０-９0-9]{2,3}(?![０-９0-9])/, "!")
                        end
                        if /[a-zA-Zａ-ｚＡ-Ｚ]{2,3}/.match?(lineTmp)
                            lineTmp = lineTmp.gsub(/[a-zA-Zａ-ｚＡ-Ｚ]{2,3}/, "!")
                        end
                        scanPar = lineTmp.scan(/[《『「(\[\{（〔［｛〈【＜≪”"“゛″〝〟＂≫＞】〉｝］〕）\}\])」』》]/)
                        scanPt = lineTmp.scan(/[。\.．、，,]+$/)
                        lineTmp = lineTmp.gsub(/[《『「(\[\{（〔［｛〈【＜≪”"“゛″〝〟＂≫＞】〉｝］〕）\}\])」』》]/, "")
                        lineTmp = lineTmp.gsub(/[。\.．、，,]+$/, "")
                        lineLength = lineTmp.length + (scanPar.length > 0 ? scanPar.length * 0.8 : 0) + (scanPt.length > 0 ? scanPt.length * 0.5 : 0)
                        if lineLength > longest
                            longest = lineLength
                        end
                    end
                    if textBox.length == 1
                        boxFSize = (boxHeight / longest) <= boxWidth ? (boxHeight / longest) : boxWidth
                    else
                        boxFSize = (boxHeight / longest) <= (boxWidth / textBox.length) ? (boxHeight / longest) : (boxWidth / textBox.length)
                        lineSpace = ((boxWidth - (textBox.length * boxFSize)) / (textBox.length - 1)) + boxFSize
                    end
                    horBoxUp = (pageHeight - boxTop) - boxFSize
                    for lineBef in textBox.reverse do
                        next if boxFSize <= (ocrFSize * 0.5)
                        boxUp = (pageHeight - boxTop) - boxFSize
                        line = lineBef.strip.gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/(．)/, "").gsub(/\s/, "").gsub(/[。\.．、，,…‥!！?？：～~]+$/, "")
                        numberComp = ''
                        ponctComp = ''
                        romComp = ''
                        for char in 0...line.length do
                            if /[《『「\(\[\{（〔［｛〈【＜≪≫＞】〉｝］〕）\}\]\)」』》]/.match?(line[char])
                                boxUp -= boxFSize * 0.8
                            elsif /[。\.．、，,…‥!！?？：～~]/.match?(line[char])
                                boxUp -= boxFSize
                            elsif /[０-９0-9]/.match?(line[char])
                                numberComp += line[char]
                                if (char + 1) > line.length || !/[０-９0-9]/.match?(line[char + 1])
                                    if numberComp.length == 2
                                        tmpFSize = boxFSize * 0.5
                                        pdf.draw_text numberComp, size: tmpFSize, at: [boxLeft, boxUp + (tmpFSize/2)]
                                        boxUp -= boxFSize
                                    elsif numberComp.length == 3
                                        tmpFSize = boxFSize * 0.35
                                        pdf.draw_text numberComp, size: tmpFSize, at: [boxLeft, boxUp + (tmpFSize/3)]
                                        boxUp -= boxFSize
                                    else
                                        for n in 0...numberComp.length
                                            pdf.draw_text numberComp[n], size: boxFSize, at: [boxLeft, boxUp]
                                            boxUp -= boxFSize
                                        end
                                    end
                                    numberComp = ''
                                end
                            elsif /[!！?？]/.match?(line[char])
                                ponctComp += line[char]
                                if (char + 1) > line.length || !/[!！?？]/.match?(line[char + 1])
                                    tmpFSize = boxFSize / ponctComp.length
                                    pdf.draw_text ponctComp, size: tmpFSize, at: [boxLeft, boxUp]
                                    boxUp -= boxFSize
                                    ponctComp = ''
                                end
                            elsif /[a-zA-Zａ-ｚＡ-Ｚ]/.match?(line[char])
                                romComp += line[char]
                                if (char + 1) > line.length || !/[a-zA-Zａ-ｚＡ-Ｚ]/.match?(line[char + 1])
                                    if romComp.length <= 3
                                        tmpFSize = boxFSize / romComp.length
                                        pdf.draw_text romComp, size: tmpFSize, at: [boxLeft, boxUp]
                                        boxUp -= boxFSize
                                    else
                                        for l in 0...romComp.length
                                            pdf.draw_text romComp[l], size: boxFSize, at: [boxLeft, boxUp]
                                            boxUp -= boxFSize
                                        end
                                    end
                                    romComp = ''
                                end
                            else
                                pdf.draw_text line[char], size: boxFSize, at: [boxLeft, boxUp]
                                boxUp -= boxFSize
                            end
                        end
                        boxLeft += lineSpace
                    end
                end
            end
        end
    end
    File.write("#{info[:Title]} - MKR2PDF.json", JSON.dump(pagesJson))
    if options[:gamma] != 1
        FileUtils.remove_dir("tmp")
    end
    pdf.render_file("#{info[:Title]} - MKR2PDF.pdf")
    puts "Done!"
end
