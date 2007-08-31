from reportlab.pdfgen.canvas import Canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm, mm, inch, pica
from reportlab.platypus import Paragraph, SimpleDocTemplate, BaseDocTemplate, Spacer, PageTemplate
from reportlab.platypus.frames import Frame
from reportlab.platypus.flowables import ImageAndFlowables, Image, KeepTogether, Preformatted
from reportlab.platypus.doctemplate import FrameBreak, PageBreak
from reportlab.platypus.tables import Table
from reportlab.lib.styles import ParagraphStyle, StyleSheet1
from reportlab.lib.enums import TA_LEFT, TA_RIGHT, TA_CENTER, TA_JUSTIFY
from reportlab.lib import colors 

from reports.ReportLabExtensions import HypenatedParagraph

import os
import datetime
import time

def _doNothing(canvas, doc):
    "Dummy callback for onPage"
    pass

class ReportTemplate(SimpleDocTemplate):
    _invalidInitArgs = ('pageTemplates',)

    def __init__(self, filename, **kw):
        SimpleDocTemplate.__init__(self, filename, **kw)
    
    def build(self, flowables, onFirstPage=_doNothing, onLaterPages=_doNothing, canvasmaker=Canvas):
        #Override the build method
        self._calc()    #in case we changed margins sizes etc
        self.canvas = canvasmaker
        firstFrame = Frame(10,        # X
                       0,            # Y
                       A4[0]-20,     # width
                       A4[1]-106,     # height
                       id='normal')

        secondFrame = Frame(10,          # X
                       0,            # Y
                       A4[0]-20,     # width
                       A4[1]-46,     # height
                       #showBoundary=True,
                       id='normal')        
        
        self.addPageTemplates([PageTemplate(id='First',
                                            frames=[firstFrame],
                                            pagesize=self.pagesize,
                                            onPage=onFirstPage),
                                PageTemplate(id='Later',
                                            frames=[secondFrame],
                                            pagesize=self.pagesize,
                                            onPage=onLaterPages),
                                ]
        )
        if onFirstPage is _doNothing and hasattr(self,'onFirstPage'):
            self.pageTemplates[0].beforeDrawPage = self.onFirstPage
        if onLaterPages is _doNothing and hasattr(self,'onLaterPages'):
            self.pageTemplates[1].beforeDrawPage = self.onLaterPages
        BaseDocTemplate.build(self,flowables, canvasmaker=canvasmaker)        
        
class Report:
    def __init__(self, date=None, path=None):
        self.date = self.getMonday(date)
        
    def getMonday(self, date=None):
        #Work out the Monday for the week containing date. If full week hasn't passed show previous week.
        today = ''
        if date == None:
            today = datetime.date.today()
        else:
            today = datetime.datetime(*time.strptime(date, "%Y-%m-%d")[0:5])
        if today.weekday() == 0:
            return today - datetime.timedelta(weeks=1)
        else:
            return today - datetime.timedelta(weeks=1, days=today.weekday())
        
    def getStyle(self):
        style = StyleSheet1()
        
        style.add(ParagraphStyle(name='ReportTitle',
                 spaceBefore = 0,
                 fontName='Helvetica',
                 fontSize=30,
                 leading=36,
                 textColor='#0A5000',
                 alignment=TA_CENTER)
        )
    
        style.add(ParagraphStyle(name='ReportTitleDate',
                 fontName='Helvetica',
                 fontSize=16,
                 leading=20,
                 textColor='#4467DB',
                 alignment=TA_CENTER)
        )
    
        style.add(ParagraphStyle(name='ReportSubTitle',
                 fontName='Helvetica',
                 fontSize=24,
                 leading=30,
                 textColor='#CA431E',
                 alignment=TA_CENTER)
        )

        style.add(ParagraphStyle(name='SectionTitle',
                 parent=style['ReportSubTitle'],
                 fontSize=18,
                 leading=24,
                 alignment=TA_LEFT)
        )    
            
        style.add(ParagraphStyle(name='Normal',
                 fontName='Helvetica',
                 fontSize=14,
                 leading=16,
                 textColor='#000000',
                 alignment=TA_LEFT)
        )
        
        style.add(ParagraphStyle(name='TableHeader',
                 fontName='Helvetica',
                 fontSize=14,
                 leading=16,
                 textColor='#000000',
                 alignment=TA_CENTER)
        )
                   
        style.add(ParagraphStyle(name='TableMain',
                 fontName='Helvetica',
                 fontSize=12,
                 leading=14,
                 wordWrap = 'para',
                 textColor='#000000',
                 alignment=TA_JUSTIFY)
        )
                   
        style.add(ParagraphStyle(name='TableMain_cent',
                 fontName='Helvetica',
                 fontSize=12,
                 leading=14,
                 wordWrap = 'para',
                 textColor='#000000',
                 alignment=TA_CENTER)
        )
         
        style.add(ParagraphStyle(name='Preformatted',
                 fontName='Courier',
                 fontSize=12,
                 leading=14,
                 textColor='#3d3d3d',
                 alignment=TA_LEFT)
        )
        
        style.add(ParagraphStyle(name='Footer',
                 fontName='Helvetica-Oblique',    # Fonts on page 24
                 fontSize=12,
                 leading=12,
                 textColor='#000000',
                 alignment=TA_RIGHT)
        )
        
        style.add(ParagraphStyle(name='Normal_just',
                                 parent=style['Normal'],
                                 alignment=TA_JUSTIFY))
        
        style.add(ParagraphStyle(name='Normal_cent',
                                 parent=style['Normal'],
                                 alignment=TA_CENTER))
        
        style.add(ParagraphStyle(name='Normal_just_rind',
                                 parent=style['Normal_just'],
                                 rightIndent=20))
        
        return style

    def getDate(self):
        day = self.date.strftime('%d')
        stndrdth = 'th'
        if day > 3 and day < 21:
            stndrdth = 'th'
        elif day[-1] == 1:
            stndrdth = 'st'
        elif day[-1] == 2:
            stndrdth = 'nd'
        elif day[-1] == 3:
            stndrdth = 'rd' 
        return "".join([self.date.strftime("%A %d<sup>"), stndrdth, self.date.strftime("</sup> %B, %Y")])

class PhEDEXSiteReport(Report):
    def __init__(self, site=None, instance=None, date=None, path=None):
        Report.__init__(self, date, path)
        if site:
            self.site = site
        else:
            self.site = "Test Site"
        self.pdf = ReportTemplate("%s_phedexreport.pdf" % self.site.replace(" ", ""), pagesize = A4)
        if instance:
            self.instance = instance
        else:
            self.instance = "Production"
        
    def doExport(self):
        style = self.getStyle()
        # return a Paragraph object
        text = '''Export transfer rates and quality for %s. 
        Maximum daily rate is 237MB/s, minimum rate is 100MB/s, 
        average 169/MB/s. Average quality for the week is 30 percent.''' % self.site
        exportPara = [Spacer(inch * .25, inch * .25),
                      Paragraph('Data Export',style['SectionTitle']), 
                      Paragraph(text,style=style["Normal_just_rind"])]
        png = 'Picture 1.png'
        exportImg = ImageAndFlowables(Image(png,width=340,height=240),
                             exportPara,
                             imageLeftPadding=0,
                             imageRightPadding=0,
                             imageSide='right')
        return KeepTogether([exportImg, Spacer(inch * .125, inch * .125)])
    
    def doImport(self):
        style = self.getStyle()
        text = '''Import transfer rates and quality for %s. 
        Maximum daily rate is 237MB/s, minimum rate is 100MB/s, 
        average 169/MB/s. Average quality for the week is 30 percent.''' % self.site
        importPara = [Spacer(inch * .25, inch * .25),
                      Paragraph('Data Import',style['SectionTitle']), 
                      Paragraph(text,style=style["Normal_just"])]
        png = 'Picture 1.png'
        importImg = ImageAndFlowables(Image(png,width=340,height=240),
                             importPara,
                             imageLeftPadding=0,
                             imageRightPadding=20,
                             imageSide='left')
        return KeepTogether([importImg, Spacer(inch * .125, inch * .125)])        
    
    def doSubscriptions(self): 
        style = self.getStyle()   
        text = """There have been 21 subscription requests this week. 
        All have been approved| X were approved, Y rejected, 
        Z are still to be considered. """

        png = 'Picture 1.png'
        
        subscriptionsPara = [Spacer(inch * .25, inch * .25),
                             Paragraph('Subscriptions',style['SectionTitle']), 
                    Paragraph(text,style=style["Normal_just_rind"]), 
                    Spacer(inch * .125, inch * .125), 
                    Paragraph(self.doRequests(),style=style["Normal_just_rind"]),
                    Spacer(inch * .25, inch * .25)]
        subscriptionsImg = ImageAndFlowables(Image(png,width=180,height=180),
                             subscriptionsPara,
                             imageLeftPadding=0,
                             imageRightPadding=0,
                             imageSide='right')
        
        return KeepTogether([subscriptionsImg, Spacer(inch * .125, inch * .125)])
    
    def doRequests(self):
        return """%s has XXXTB of data on site, and XXXTB pending 
        transfer. You have pledged XXXTB of storage to CMS.""" % self.site
    
    def doErrors(self):
        style = self.getStyle()
        title = "Error Summary"
        text = """Below is a summary of the top errors to and from %s
        for the week beginning %s.""" % (self.site, self.getDate())
        errors = """*** ERRORS from T2_Estonia_Buffer:***
    942   transfer expired in the download agent queue
    777   Canceled (null)
    140   transfer timed out after 3630 seconds with signal 15
     77   transfer timed out after 3645 seconds with signal 9
     53   Failed on SRM put: SRM getRequestStatus timed out on put
     50   no detail - validate failed: [unknown reason - inspect log]
      7   the gridFTP transfer timed out"""
      
        return KeepTogether([Paragraph(title, style=style['SectionTitle']), 
                             Paragraph(text, style=style["Normal_just"]),
                             Spacer(inch * .125, inch * .125),
                             Preformatted(errors,style=style["Preformatted"])])
        
    def doOutstanding(self):
        style = self.getStyle()
        title = "Outstanding Transfer Requests"
        text = """The following transfer requests are older than a week and 
have not been completed. Please investigate and resolve the failing transfers, 
or remove the subscriptions if the data is no longer required."""
        data = [
                [Paragraph("Data set/File Block", style["TableHeader"]), Paragraph("Age", style["TableHeader"])],
                [HypenatedParagraph("/LaserSim/CMSSW_1_4_4-CSA07-2075/GEN-SIM", 
                                    style["TableMain"], 
                                    width=((6*A4[0])/8)),
                Paragraph("5 weeks", style["TableMain_cent"])],
                [HypenatedParagraph("/RelVal160pre410MuonsPt10/CMSSW_1_6_0_pre4-RelVal-1184752200/GEN-SIM-DIGI-RECO", 
                                    style["TableMain"],
                                    width=((6*A4[0])/8)), 
                Paragraph("2 weeks", style["TableMain_cent"])]
                ]
        return KeepTogether([Paragraph(title,style=style['SectionTitle']), 
                             Paragraph(text,style=style["Normal_just"]),
                             Spacer(inch * .125, inch * .125),
                             Table(data,colWidths=((6*A4[0])/8 ,A4[0]/8),style=[('BACKGROUND',(0,0),(-1, 0),'#dddddd'),
                               ('INNERGRID', (0,0), (-1,-1), 0.25, colors.grey),
                               ('BOX', (0,0), (-1,-1), 0.5, colors.black),
                               ('VALIGN', (0,0), (-1,-1),'MIDDLE')]),
                             Spacer(inch * .125, inch * .125)])
        
    # Methods for masthead and footer
    def myFirstPage(self, canvas, doc):
        Image('PhEDEx-banner.png', width=A4[0], height=100).drawOn(canvas, 0, (A4[1]-100))
        self.allPages(canvas, doc)

        style = self.getStyle() 
        date = self.getDate()
        P = Paragraph("%s PhEDEx Report" % self.site, style["ReportTitle"])
        size = P.wrap(A4[0], 200)
        #Because we're drawing 'raw' paragraphs need to wrap them
        P.wrapOn(canvas, A4[0], size[1])
        top = 10 + size[1]
        P.drawOn(canvas, 0, A4[1]-top)
        
        P = Paragraph("Week beginning %s" % date, style["ReportTitleDate"])
        size = P.wrap(A4[0], 200)
        P.wrapOn(canvas, A4[0], size[1])
        top = top + size[1]
        P.drawOn(canvas, 0, A4[1]-top)
        
        P = Paragraph("%s Instance" % self.instance, style["ReportSubTitle"])
        size = P.wrap(A4[0], 200)
        P.wrapOn(canvas, A4[0], size[1])
        top = top + size[1]
        P.drawOn(canvas, 0, A4[1]-top)
    
    def myLaterPages(self, canvas, doc):
        Image('PhEDEx-banner.png', width=A4[0], height=75).drawOn(canvas, 0, (A4[1]-75))
        self.allPages(canvas, doc)

        style = self.getStyle() 
        date = self.getDate()
        P = Paragraph("%s PhEDEx Report" % self.site, style["ReportTitle"])
        size = P.wrap(A4[0], 200)
        P.wrapOn(canvas, A4[0], size[1])
        top = 10 + size[1]
        P.drawOn(canvas, 0, A4[1]-top)
        
    def allPages(self, canvas, doc):
        #Background images
        Image('phedex_outline.png', width=A4[0]-50, height=A4[0]-50).drawOn(canvas, 25, (A4[1]/2) - (A4[0]/2))
        
        #Footer text
        style = self.getStyle() 
        date = self.getDate()
        P = Paragraph("%s PhEDEx Report for week beginning %s  - Page %d" % (self.site, date, doc.page), style["Footer"])
        size = P.wrap(A4[0], 200)
        P.wrapOn(canvas, A4[0]-20, size[1])
        top = 10 + size[1]
        P.drawOn(canvas, 0, top)
                
    def makeReport(self):
        style = self.getStyle()
        story = []
        
        story.append(self.doExport())
        
        story.append(self.doImport())
        
        story.append(self.doSubscriptions())
    
        story.append(PageBreak())

        story.append(self.doOutstanding())
        
        story.append(self.doErrors())
        
        self.pdf.build(story, onFirstPage=self.myFirstPage, onLaterPages=self.myLaterPages)

 
        
        
        
        
        
        
        
        
        