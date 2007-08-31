from reports import PhEDEXSiteReport, ReportTemplate, Report
from reports.ReportLabExtensions import HypenatedParagraph

from reportlab.lib.pagesizes import A4, A0
from reportlab.platypus.tables import Table
from reportlab.platypus import Paragraph
from reportlab.lib import colors 

report = PhEDEXSiteReport(site='RAL', instance='Production')
report.makeReport()

#print A0
#
#rep = Report()
#pdf = ReportTemplate("test.pdf", pagesize = A4)
#style = rep.getStyle()
#
#
#
#data = [
#        [HypenatedParagraph("Averyveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryverylongstringindeed", style["TableHeader"], width=((4*A4[0])/8 - 200)), 
#           Paragraph("Thing", style["TableHeader"])]
#        ]
#
#t = Table(data,
#           colWidths=((4*A4[0])/8 ,A4[0]/8),
#           style=[('BACKGROUND',(0,0),(-1, 0),'#dddddd'),
#             ('INNERGRID', (0,0), (-1,-1), 0.25, colors.grey),
#             ('BOX', (0,0), (-1,-1), 0.5, colors.black),
#             ('VALIGN', (0,0), (-1,-1),'MIDDLE')])
#
#story = []
#
#story.append(t)
#hp1 = HypenatedParagraph("Averyveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryverylongstringindeed", style["TableHeader"], width=200)
#story.append(hp1)
#
#hp2 = HypenatedParagraph("Averyveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryveryverylongstringindeed", style["TableHeader"], width=400)
#story.append(hp2)
#
#pdf.build(story)