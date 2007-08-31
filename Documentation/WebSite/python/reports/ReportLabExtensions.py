from reportlab.platypus import Paragraph
from reportlab.pdfgen.canvas import Canvas


from types import ListType
from reportlab.pdfbase.pdfmetrics import stringWidth

from reportlab.platypus.paragraph import split, strip, _handleBulletWidth
from math import floor, ceil, fabs

class HypenatedParagraph(Paragraph):
    def __init__(self, text, style, bulletText = None, frags=None, width=100, splitter=['-','/'], caseSensitive=1, encoding='utf8'):
        self.blockwidth = width 
        self.splitter = splitter       
        Paragraph.__init__(self, text, style, bulletText = None, frags=None, caseSensitive=1, encoding='utf8')

    def breakLines(self, width):
        if type(width) <> ListType: maxWidths = [width]
        else: maxWidths = width
        
        lines = []
        lineno = 0
        style = self.style
        fFontSize = float(style.fontSize)

        #for bullets, work out width and ensure we wrap the right amount onto line one
        _handleBulletWidth(self.bulletText,style,maxWidths)

        maxWidth = maxWidths[0]

        self.height = 0
        frags = self.frags
        nFrags= len(frags)
        if nFrags==1 and not hasattr(frags[0],'cbDefn'):
            f = frags[0]
            fontSize = f.fontSize
            fontName = f.fontName
            
            words = hasattr(f,'text') and split(f.text, ' ') or f.words
            
            spaceWidth = stringWidth(' ', fontName, fontSize, self.encoding)
            cLine = []
            currentWidth = - spaceWidth   # hack to get around extra space for word 1
            newwords = []
            for word in words:

                #this underscores my feeling that Unicode throughout would be easier!
                wordWidth = stringWidth(word, fontName, fontSize, self.encoding)
                
                #Hyphenate long words in the paragraph to fit an area of width self.blockwidth

                charwidth = int(ceil(wordWidth / len(word)))
                charinline = int(floor(self.blockwidth / charwidth))
#                print word
#                print 'wordWidth', wordWidth
#                print 'self.blockwidth', self.blockwidth
#                print 'len(word)', len(word)
#                print 'charwidth', charwidth
#                print 'charinline', charinline
#                print range(0, int(ceil(wordWidth / self.blockwidth)))                
                newtext = ''
                diff = 0
                for i in range(0, 1 + int(ceil(wordWidth / self.blockwidth))):
#                    print 'i = ', i
#                    print i * charinline
#                    print (i + 1) * charinline
#                    print self.text[i * charinline:(i + 1) * charinline]
#                    newtext = '%s%s ' % (newtext, word[i * charinline:(i + 1) * charinline])
                    max = (i + 1) * charinline
                    min = (i * charinline) - diff
                    for s in self.splitter:
                        p = word.find(s, max - 10, max)
                        
                        if p < max and p > 0: 
                            diff = max - p - 1
                            max = p + 1
                        else:
                            diff = 0
                    newwords.append(word[min:max])
#                    print stringWidth(word[i * charinline:(i + 1) * charinline], 
#                                      fontName, fontSize, self.encoding)
#                    print len(word[i * charinline:(i + 1) * charinline])
#                print newwords

            for word in newwords:                
                newWidth = currentWidth + spaceWidth + wordWidth
                if newWidth <= maxWidth or not len(cLine):
                    # fit one more on this line
                    cLine.append(word)
                    currentWidth = newWidth
                else:
                    if currentWidth > self.width: self.width = currentWidth
                    #end of line
                    lines.append((maxWidth - currentWidth, cLine))
                    cLine = [word]
                    currentWidth = wordWidth
                    lineno += 1
                    try:
                        maxWidth = maxWidths[lineno]
                    except IndexError:
                        maxWidth = maxWidths[-1]  # use the last one

            #deal with any leftovers on the final line
            if cLine!=[]:
                if currentWidth>self.width: self.width = currentWidth
                lines.append((maxWidth - currentWidth, cLine))
            return f.clone(kind=0, lines=lines)
        elif nFrags<=0:
            return ParaLines(kind=0, fontSize=style.fontSize, fontName=style.fontName,
                            textColor=style.textColor, lines=[])
        else:
            if hasattr(self,'blPara') and getattr(self,'_splitpara',0):
                #NB this is an utter hack that awaits the proper information
                #preserving splitting algorithm
                return self.blPara
            n = 0
            words = []
            for w in _getFragWords(frags):
                spaceWidth = stringWidth(' ',w[-1][0].fontName, w[-1][0].fontSize)
                print '133', w
                if n==0:
                    currentWidth = -spaceWidth   # hack to get around extra space for word 1
                    maxSize = 0

                wordWidth = w[0]
                f = w[1][0]
                if wordWidth>0:
                    newWidth = currentWidth + spaceWidth + wordWidth
                else:
                    newWidth = currentWidth

                #test to see if this frag is a line break. If it is we will only act on it
                #if the current width is non-negative or the previous thing was a deliberate lineBreak
                lineBreak = hasattr(f,'lineBreak')
                endLine = (newWidth>maxWidth and n>0) or lineBreak
                if not endLine:
                    if lineBreak: continue      #throw it away
                    nText = w[1][1]
                    if nText: n += 1
                    maxSize = max(maxSize,f.fontSize)
                    if words==[]:
                        g = f.clone()
                        words = [g]
                        g.text = nText
                    elif not _sameFrag(g,f):
                        if currentWidth>0 and ((nText!='' and nText[0]!=' ') or hasattr(f,'cbDefn')):
                            if hasattr(g,'cbDefn'):
                                i = len(words)-1
                                while hasattr(words[i],'cbDefn'): i -= 1
                                words[i].text += ' '
                            else:
                                g.text += ' '
                        g = f.clone()
                        words.append(g)
                        g.text = nText
                    else:
                        if nText!='' and nText[0]!=' ':
                            g.text += ' ' + nText

                    for i in w[2:]:
                        g = i[0].clone()
                        g.text=i[1]
                        words.append(g)
                        maxSize = max(maxSize,g.fontSize)

                    currentWidth = newWidth
                else:  #either it won't fit, or it's a lineBreak tag
                    if lineBreak:
                        g = f.clone()
                        #del g.lineBreak
                        words.append(g)

                    if currentWidth>self.width: self.width = currentWidth
                    #end of line
                    lines.append(FragLine(extraSpace=(maxWidth - currentWidth),wordCount=n,
                                        words=words, fontSize=maxSize))

                    #start new line
                    lineno += 1
                    try:
                        maxWidth = maxWidths[lineno]
                    except IndexError:
                        maxWidth = maxWidths[-1]  # use the last one

                    if lineBreak:
                        n = 0
                        words = []
                        continue

                    currentWidth = wordWidth
                    n = 1
                    maxSize = f.fontSize
                    g = f.clone()
                    words = [g]
                    g.text = w[1][1]

                    for i in w[2:]:
                        g = i[0].clone()
                        g.text=i[1]
                        words.append(g)
                        maxSize = max(maxSize,g.fontSize)

            #deal with any leftovers on the final line
            if words!=[]:
                if currentWidth>self.width: self.width = currentWidth
                lines.append(ParaLines(extraSpace=(maxWidth - currentWidth),wordCount=n,
                                    words=words, fontSize=maxSize))  
            return ParaLines(kind=1, lines=lines)

        
        return lines
