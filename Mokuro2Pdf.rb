require 'prawn'
require 'json'
require 'mini_magick'
require 'fileutils'
require 'optparse'
require 'find'

options = {}
OptionParser.new do |opt|
    opt.banner = "Usage: Mokuro2Kindle.rb [options]"
    opt.on("-i IMAGES", "--imageFolder IMAGES", "Folder containing all manga pages") do |i|
        options[:imageFolder] = i
    end
    opt.on("-n NAME", "--name NAME", "Filename the created pdf will have") do |n|
        options[:filename] = n
    end
    opt.on("-g GAMMA", "--gamma GAMMA", "Gamma value to be used on all images, default = 1") do |g|
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
    opt.on("-w OUTPUT_FOLDER", "--write_to OUTPUT_FOLDER", "Output folder") do |w|
        options[:outputFolder] = w
    end
    opt.on("-u", "--upscale_on", "Turn on image upscaling if image resolution < Kindle's resolution") do |u|
        options[:upscale] = true
    end
end.parse!
puts ""
puts "Mokuro2Pdf"
if options.key?(:gamma)
    puts "Using the defined #{options[:gamma]} gamma value"
else
    puts "Using the default(1) gamma value"
    options[:gamma] = 1
end
if options.key?(:fontTransparency)
    puts "Using the defined #{options[:fontTransparency]} font transparency"
else
    puts "Using the default(0.2) font transparency"
    options[:fontTransparency] = 0.2
end
if options.key?(:outputFolder)
    puts "Using the defined #{options[:outputFolder]} output folder"
    if !(options[:outputFolder] =~ /[\\\/]$/)
        options[:outputFolder] += '/'
    end
else
    options[:outputFolder] = ""
end
if options.key?(:upscale)
    puts "Upscale on"
else
    options[:upscale] = false
end
folders = []
if !options.key?(:parentImg)
    if !options.key?(:filename) || options[:filename] == ''
        options[:filename] = options[:imageFolder] =~ /(?<=\\|\/)[^\\\/]{1,}?(?=$|[\\\/]$)/ ? options[:imageFolder].match(/(?<=\\|\/)[^\\\/]{1,}?(?=$|[\\\/]$)/)[0] : options[:imageFolder]
    end
    folder = []
    puts "Converting '#{options[:imageFolder]}/' to '#{options[:filename]} - MKR2PDF.pdf'"
    begin
        volumeImg = options[:imageFolder] =~ /(?<=\\|\/)[^\\\/]{1,}?(?=$|[\\\/]$)/ ? options[:imageFolder].match(/(?<=\\|\/)[^\\\/]{1,}?(?=$|[\\\/]$)/)[0] : options[:imageFolder]
        if !options.key?(:ocrFolder)
            puts "Using the default '_ocr/#{volumeImg}/' ocr folder path"
            options[:ocrFolder] = "_ocr/#{volumeImg}"
            volumeOcr = volumeImg
        else
            puts "Using the defined '#{options[:ocrFolder]}/' ocr folder path"
            volumeOcr = options[:ocrFolder] =~ /(?<=\\|\/)[^\\\/]{1,}?(?=$|[\\\/]$)/ ? options[:ocrFolder].match(/(?<=\\|\/)[^\\\/]{1,}?(?=$|[\\\/]$)/)[0] : options[:ocrFolder]
        end
        pages = []
        Find.find(options[:imageFolder]) do |path|
            pages << path if path =~ /.*\.(jpg|jpeg|jpe|jif|jfif|jfi|png|gif|webp|tiff|tif|psd|raw|arw|cr2|nrw|k25|bmp|dib|jp2|j2k|jpf|jpx|jpm|mj2)$/i
        end
        jsons = {}
        Find.find(options[:ocrFolder]) do |path|
            jsons[path.match(/#{Regexp.escape(volumeOcr)}.*?(?=\.json$)/i)[0].gsub(/^.*?(?=[\\\/])/, volumeImg)] = path if path =~ /.*\.json$/i
        end
        puts "#{pages.length} Pages found"
        puts "#{jsons.length} Jsons found"
        info = {
            Title: options[:filename],
            Language: 'ja'
        }
        folder.append(pages.sort)
        folder.append(jsons)
        folder.append(info)
        folder.append(volumeImg)
        folders.append(folder)
    rescue
        puts "No Pages/Jsons found"
    end
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
        begin
            pages = []
            Find.find("#{options[:parentImg]}/#{volume}") do |path|
                pages << path if path =~ /.*\.(jpg|jpeg|jpe|jif|jfif|jfi|png|gif|webp|tiff|tif|psd|raw|arw|cr2|nrw|k25|bmp|dib|jp2|j2k|jpf|jpx|jpm|mj2)$/i
            end
            jsons = {}
            Find.find("#{options[:parentOcr]}/#{volume}") do |path|
                jsons[path.match(/#{Regexp.escape(volume)}.*?(?=\.json$)/i)[0]] = path if path =~ /.*\.json$/i
            end
            if pages.length > 0 && jsons.length > 0
                puts "\t#{volume} - #{pages.length} Pages found, #{jsons.length} Jsons found\n"
                folder.append(pages.sort)
                folder.append(jsons)
                folder.append(info)
                folder.append(volume)
                folders.append(folder)
            else
                puts "\t#{volume} - #{pages.length} Pages found, #{jsons.length} Jsons found. Skipping folder\n"
            end
        rescue
            puts "\t#{volume} - No Pages/Jsons found, skipping folder"
        end
    end
end
for folder in folders do
    begin
        pages = folder[0]
        jsons = folder[1]
        info = folder[2]
        puts "\nProcessing #{info[:Title]}..."
        for i in 0...pages.length do
            imagePath = pages[i].match(/(#{Regexp.escape(folder[3])}).*?(?=\.(jpg|jpeg|jpe|jif|jfif|jfi|png|gif|webp|tiff|tif|psd|raw|arw|cr2|nrw|k25|bmp|dib|jp2|j2k|jpf|jpx|jpm|mj2)$)/i)[0]
            if jsons.include? imagePath
                has_Json = true
                page = JSON.parse(File.read(jsons[imagePath]))
                pageWidth = page["img_width"]
                pageHeight = page["img_height"]
            else
                puts "!!No ocr data found for page #{i+1}!!"
                has_Json = false
                page = MiniMagick::Image.open(pages[i])
                pageWidth = page[:width]
                pageHeight = page[:height]
            end
            if options[:upscale] || options[:gamma] != 1
                FileUtils.mkdir_p "tmp"
                pageBgMagick = MiniMagick::Image.open(pages[i])
                if options[:gamma] != 1
                    pageBgMagick.gamma options[:gamma]
                end
                if options[:upscale]
                    pageRes = [pageBgMagick[:width], pageBgMagick[:height]]
                    if pageRes[0] < 1016 || pageRes[1] < 1358
                        upscale = 1
                        while (pageRes[0] * upscale).to_i < 1016 || (pageRes[1] * upscale).to_i < 1358
                            upscale += 0.25
                        end
                    else
                        upscale = 1
                    end
                    pageBgMagick.scale "#{(pageRes[0] * upscale).to_i}x#{(pageRes[1] * upscale).to_i}"
                end
                pageBgMagick.write "tmp/page-#{i}"
                pageBgMagickPath = "tmp/page-#{i}"
                pageWidth = pageBgMagick[:width]
                pageHeight = pageBgMagick[:height]
            else
                pageBgMagickPath = pages[i]
                upscale = 1
            end
            if i == 0
                pdf = Prawn::Document.new(page_size: [pageWidth, pageHeight], margin: [0, 0, 0, 0], info: info)
            else
                pdf.start_new_page(size: [pageWidth, pageHeight], margin: [0, 0, 0, 0])
            end
            pdf.image pageBgMagickPath, height: pageHeight, width: pageWidth, at: [0, pageHeight]
            next if !has_Json
            if upscale > 1
                pageText = page["blocks"].map{ |x| 
                    x["box"].map!{ |y| 
                        (y * upscale).to_i
                        }
                    x["lines_coords"].map!{ |l| 
                        l.map!{ |c| 
                            c.map!{ |d|
                                ((d * upscale).to_i).to_f
                            }
                            }
                        }
                    x["font_size"] = (x["font_size"] * upscale).to_i
                    x
                    }
            else
                pageText = page["blocks"]
            end
            pdf.transparent(options[:fontTransparency]) do
                pdf.font("ipaexg.ttf")
                for b in 0...pageText.length do
                    heightTreshold = pageHeight * 0.0075
                    widthThreshold = pageWidth * 0.0075
                    isBoxVert = pageText[b]["vertical"]
                    fontSize = 0
                    if !isBoxVert
                        for l in 0...pageText[b]["lines"].length do
                            line = pageText[b]["lines"][l].gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/(．)/, "").gsub(/\s/, "").gsub(/[。\.．、，,]+$/, "")
                            if !(line.to_s == '' || line.nil?)
                                lineLeft = pageText[b]["lines_coords"][l][3][0]
                                lineRight = pageText[b]["lines_coords"][l][2][0]
                                lineBottom = pageText[b]["lines_coords"][l][3][1] <= pageText[b]["lines_coords"][l][2][1] ? pageText[b]["lines_coords"][l][3][1] : pageText[b]["lines_coords"][l][2][1]
                                lineTop = pageText[b]["lines_coords"][l][0][1] <= pageText[b]["lines_coords"][l][1][1] ? pageText[b]["lines_coords"][l][0][1] : pageText[b]["lines_coords"][l][1][1]
                                lineWidth = lineRight - lineLeft
                                lineHeight = lineBottom - lineTop
                                fontSize = (lineWidth / line.length) <= (lineHeight * 2) ? (lineWidth / line.length) : (lineHeight * 2)
                                next if fontSize <= (pageText[b]["font_size"] * 0.15)
                                line = pageText[b]["lines"][l].strip.gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/(．)/, "").gsub(/\s/, "").gsub(/[。\.．、，,…‥!！?？：～~]+$/, "")
                                pdf.draw_text line, size: fontSize, at:[lineLeft, pageHeight - lineBottom]
                            end
                        end
                    else
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
                            minTop = pageText[b]["lines_coords"][l][0][1] >= pageText[b]["lines_coords"][l][1][1] ? pageText[b]["lines_coords"][l][0][1] : pageText[b]["lines_coords"][l][1][1]
                            minBottom = pageText[b]["lines_coords"][l][3][1] <= pageText[b]["lines_coords"][l][2][1] ? pageText[b]["lines_coords"][l][3][1] : pageText[b]["lines_coords"][l][2][1]
                            widthTop = pageText[b]["lines_coords"][l][1][0] - pageText[b]["lines_coords"][l][0][0]
                            widthBottom = pageText[b]["lines_coords"][l][2][0] - pageText[b]["lines_coords"][l][3][0]
                            boxHeight = pageText[b]["box"][3] - pageText[b]["box"][1]
                            ocrFSize = pageText[b]["font_size"]
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
                            lineHeight = minBottom - minTop
                            lineHeight = boxHeight <= lineHeight ? boxHeight : lineHeight
                            lineWidth = widthTop <= widthBottom ? widthTop : widthBottom
                            if !(lineLength.nil? || lineLength == 0 || lineLength.to_s == '')
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
                        end
                        for level in 0...textLevels.length do
                            next if (levelLine[textLevels[level]].nil? || levelLine[textLevels[level]] == 0 || levelLine[textLevels[level]].to_s == '')
                            boxWidth = levelWidth[level][1] - levelWidth[level][2]
                            boxLength = levelLine[textLevels[level]].length
                            boxFSize = levelLine[textLevels[level]].reduce(99999) {|smallest, line| (line[1] < smallest) && (line[1] > (line[2] * 0.3)) ? line[1] : smallest}
                            lineSpace = 1.1
                            if boxLength > 1
                                lineSpace = ((boxWidth - (boxLength * boxFSize)) / (boxLength - 1)) + boxFSize
                            end
                            boxLeft = levelWidth[level][2] + lineSpace * (boxLength - 1)
                            for line in levelLine[textLevels[level]] do
                                next if line[1] <= (line[2] * 0.5)
                                fontSize = line[1]
                                line = line[0].strip.gsub(/(．．．)/, "…").gsub(/(．．)/, "‥").gsub(/(．)/, "").gsub(/\s/, "").gsub(/[。\.．、，,…‥!！?？：～~]+$/, "")
                                boxUp = (pageHeight - textLevels[level]) - fontSize
                                numberComp = ''
                                ponctComp = ''
                                romComp = ''
                                for char in 0...line.length do
                                    if /[《『「\(\[\{（〔［｛〈【＜≪≫＞】〉｝］〕）\}\]\)」』》]/.match?(line[char])
                                        boxUp -= fontSize * 0.8
                                    elsif /[。\.．、，,…‥!！?？：～~]/.match?(line[char])
                                        boxUp -= fontSize
                                    elsif /[０-９0-9]/.match?(line[char])
                                        numberComp += line[char]
                                        if (char + 1) > line.length || !/[０-９0-9]/.match?(line[char + 1])
                                            if numberComp.length == 2
                                                tmpFSize = fontSize * 0.5
                                                pdf.draw_text numberComp, size: tmpFSize, at: [boxLeft, boxUp + (tmpFSize/2)]
                                                boxUp -= fontSize
                                            elsif numberComp.length == 3
                                                tmpFSize = fontSize * 0.35
                                                pdf.draw_text numberComp, size: tmpFSize, at: [boxLeft, boxUp + (tmpFSize/3)]
                                                boxUp -= fontSize
                                            else
                                                for n in 0...numberComp.length
                                                    pdf.draw_text numberComp[n], size: fontSize, at: [boxLeft, boxUp]
                                                    boxUp -= fontSize
                                                end
                                            end
                                            numberComp = ''
                                        end
                                    elsif /[!！?？]/.match?(line[char])
                                        ponctComp += line[char]
                                        if (char + 1) > line.length || !/[!！?？]/.match?(line[char + 1])
                                            tmpFSize = fontSize / ponctComp.length
                                            pdf.draw_text ponctComp, size: tmpFSize, at: [boxLeft, boxUp]
                                            boxUp -= fontSize
                                            ponctComp = ''
                                        end
                                    elsif /[a-zA-Zａ-ｚＡ-Ｚ]/.match?(line[char])
                                        romComp += line[char]
                                        if (char + 1) > line.length || !/[a-zA-Zａ-ｚＡ-Ｚ]/.match?(line[char + 1])
                                            if romComp.length <= 3
                                                tmpFSize = fontSize / romComp.length
                                                pdf.draw_text romComp, size: tmpFSize, at: [boxLeft, boxUp]
                                                boxUp -= fontSize
                                            else
                                                for l in 0...romComp.length
                                                    pdf.draw_text romComp[l], size: fontSize, at: [boxLeft, boxUp]
                                                    boxUp -= fontSize
                                                end
                                            end
                                            romComp = ''
                                        end
                                    else
                                        pdf.draw_text line[char], size: fontSize, at: [boxLeft, boxUp]
                                        boxUp -= fontSize
                                    end
                                end
                                boxLeft -= lineSpace
                            end
                        end
                    end
                end
            end
        end
        if options[:gamma] != 1 || upscale != 1
            FileUtils.remove_dir("tmp")
        end
        pdf.render_file("#{options[:outputFolder]}#{info[:Title]} - MKR2PDF.pdf")
        puts "Done!"
    rescue => e
        puts e.full_message
    end
end
