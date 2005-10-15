# Obtained from www.crummy.com under the python license.

"""Beautiful Soup
Elixir and Tonic
"The Screen-Scraper's Friend"

The BeautifulSoup class turns arbitrarily bad HTML into a tree-like
nested tag-soup list of Tag objects and text snippets. A Tag object
corresponds to an HTML tag.  It knows about the HTML tag's attributes,
and contains a representation of everything contained between the
original tag and its closing tag (if any). It's easy to extract Tags
that meet certain criteria.

A well-formed HTML document will yield a well-formed data
structure. An ill-formed HTML document will yield a correspondingly
ill-formed data structure. If your document is only locally
well-formed, you can use this to process the well-formed part of it.

#Example:
#--------
from BeautifulSoup import BeautifulSoup
text = '''<html>
<head><title>The Title</title></head>
<body>
<a class="foo" href="http://www.crummy.com/">Link <i>text (italicized)</i></a>
<a href="http://www.foo.com/">Link text 2</a>
</body>
</html>'''
soup = BeautifulSoup()
soup.feed(text)
print soup("a") #Returns a list of 2 Tag objects, one for each link in
                #the source
print soup.first("a", {'class':'foo'})['href'] #Returns http://www.crummy.com/
print soup.first("title").contents[0] #Returns "The title"
print soup.first("a", {'href':'http://www.crummy.com/'}).first("i").contents[0]
#Returns "text (italicized)"

#Example of SQL-style attribute wildcards -- all four 'find' calls will
#find the link.
#----------------------------------------------------------------------
soup = BeautifulSoup()
soup.feed('''<a href="http://foo.com/">bla</a>''')
print soup.fetch('a', {'href': 'http://foo.com/'})
print soup.fetch('a', {'href': 'http://%'})
print soup.fetch('a', {'href': '%.com/'})
print soup.fetch('a', {'href': '%o.c%'})

#Example with horrible HTML:
#---------------------------
soup = BeautifulSoup()
soup.feed('''<body>
Go <a class="that" href="here.html"><i>here</i></a>
or <i>go <b><a href="index.html">Home</a>
</html>''')
print soup.fetch('a') #Returns a list of 2 Tag objects.
print soup.first(attrs={'href': 'here.html'})['class'] #Returns "that"
print soup.first(attrs={'class': 'that'}).first('i').contents[0] #returns "here"

This library has no external dependencies. It works with Python 1.5.2
and up. If you can install a Python extension, you might want to use
the ElementTree Tidy HTML Tree Builder instead:
  http://www.effbot.org/zone/element-tidylib.htm

You can use BeautifulSoup on any SGML-like substance, such as XML or a
domain-specific language that looks like HTML but has different tag
names. For such purposes you may want to use the BeautifulStoneSoup
class, which knows nothing at all about HTML per se.
"""

__author__ = "Leonard Richardson (leonardr@segfault.org)"
__version__ = "1.0 $Revision: 1.1 $"
__date__ = "$Date: 2005/03/04 06:08:48 $"
__copyright__ = "Copyright (c) 2004 Leonard Richardson"
__license__ = "Python"

from sgmllib import SGMLParser
import string

class PageElement:
    """Contains the navigational information for some part of the page
    (either a tag or a piece of text)"""

    def __init__(self, parent=None, previous=None):
        self.parent = parent
        self.previous = previous
        self.next = None

class NavigableText(PageElement):

    """A simple wrapper around a string that keeps track of where in
    the document the string was found. Doesn't implement all the
    string methods because I'm lazy. You could have this extend
    UserString if you were using 2.2."""

    def __init__(self, string, parent=None, previous=None):
        PageElement.__init__(self, parent, previous)
        self.string = string

    def __eq__(self, other):
        return self.string == str(other)

    def __str__(self):
        return self.string

    def strip(self):
        return self.string.strip()

class Tag(PageElement):

    """Represents a found HTML tag with its attributes and contents."""

    def __init__(self, name, attrs={}, parent=None, previous=None):
        PageElement.__init__(self, parent, previous)
        self.name = name
        self.attrs = attrs
        self.contents = []

    def get(self, key, default=None):
        return self._getAttrMap().get(key, default)

    def __call__(self, *args):
        return apply(self.fetch, args)

    def __getitem__(self, key):
        return self._getAttrMap()[key]

    def __setitem__(self, key, value):
        self._getAttrMap()
        self.attrMap[key] = value
        for i in range(0, len(self.attrs)):
            if self.attrs[i][0] == key:
                self.attrs[i] = (key, value)

    def _getAttrMap(self):
        if not hasattr(self, 'attrMap'):
            self.attrMap = {}
            for (key, value) in self.attrs:
                self.attrMap[key] = value
        return self.attrMap

    def __repr__(self):
        return str(self)

    def __ne__(self, other):
        return not self == other

    def __eq__(self, other):
        if not isinstance(other, Tag) or self.name != other.name or self.attrs != other.attrs or len(self.contents) != len(other.contents):
            return 0
        for i in range(0, len(self.contents)):
            if self.contents[i] != other.contents[i]:
                return 0
        return 1

    def __str__(self):
        attrs = ''
        if self.attrs:
            for key, val in self.attrs:
                attrs = attrs + ' %s="%s"' % (key, val)
        close = ''
        closeTag = ''
        if self.isSelfClosing():
            close = ' /'
        else:
            closeTag = '</%s>' % self.name
        s = self.renderContents()
        if not hasattr(self, 'hideTag'):
            s = '<%s%s%s>' % (self.name, attrs, close) + s + closeTag
        return s

    def renderContents(self):
        return string.join(map(str, self.contents), '')

    def isSelfClosing(self):
        return self.name in BeautifulSoup.SELF_CLOSING_TAGS

    def append(self, tag):
        self.contents.append(tag)

    def first(self, name=None, attrs={}, contents=None, recursive=1):
        r = None
        l = self.fetch(name, attrs, contents, recursive)
        if l:
            r = l[0]
        return r

    def fetch(self, name=None, attrs={}, contents=None, recursive=1):
        """Extracts Tag objects that match the given criteria.  You
        can specify the name of the Tag, any attributes you want the
        Tag to have, and what text and Tags you want to see inside the
        Tag."""
        if contents and type(contents) != type([]):
            contents = [contents]
        results = []
        for i in self.contents:
            if isinstance(i, Tag):
                if not name or i.name == name:
                    match = 1
                    for attr, value in attrs.items():
                        check = i.get(attr)
                        #By default, find the specific value called for.
                        #Use SQL-style wildcards to find substrings, prefix,
                        #suffix, etc.
                        result = (check == value)
                        if check and value:
                            if len(value) > 1 and value[0] == '%' and value[-1] == '%' and value[-2] != '\\':
                                result = (check.find(value[1:-1]) != -1)
                            elif value[0] == '%':
                                result = check.rfind(value[1:]) == len(check)-len(value)+1
                            elif value[-1] == '%':
                                result = check.find(value[:-1]) == 0
                        if not result:
                            match = 0
                            break
                    match = match and (not contents or i.contents == contents)
                    if match:
                        results.append(i)
                if recursive:
                    results.extend(i.fetch(name, attrs, contents, recursive))
        return results

class BeautifulSoup(SGMLParser, Tag):

    """The actual parser. It knows the following facts about HTML, and
    not much else:

    * Some tags have no closing tag and should be interpreted as being
      closed as soon as they are encountered.

    * Most tags can't be nested; encountering an open tag when there's
      already an open tag of that type in the stack means that the
      previous tag of that type should be implicitly closed. However,
      some tags can be nested.

    * The text inside some tags (ie. 'script') may contain tags which
      are not really part of the document and which should be parsed
      as text, not tags. If you want to parse the text as tags, you can
      always get it and parse it explicitly."""

    SELF_CLOSING_TAGS = ['br', 'hr', 'input', 'img', 'meta', 'spacer']
    NESTABLE_TAGS = ['font', 'table',]
    QUOTE_TAGS = ['script']

    def __init__(self, text=None):
        Tag.__init__(self, '[document]')
        SGMLParser.__init__(self)
        self.quoteStack = []
        self.hideTag = 1
        self.reset()
        if text:
            self.feed(text)

    def feed(self, text):
        SGMLParser.feed(self, text)
        self.endData()

    def reset(self):
        SGMLParser.reset(self)
        self.currentData = ''
        self.currentTag = None
        self.tagStack = []
        self.pushTag(self)

    def popTag(self):
        tag = self.tagStack.pop()
        #print "Pop", tag.name, ' '.join([x.name for x in self.tagStack])
        #if tag.name ==  'hr': print "XXX"
        self.currentTag = self.tagStack[-1]
        return self.currentTag

    def pushTag(self, tag):
        #print "Push", tag.name, ' '.join([x.name for x in self.tagStack])
        if self.currentTag:
            self.currentTag.append(tag)
        self.tagStack.append(tag)
        self.currentTag = self.tagStack[-1]

    def endData(self):
        if self.currentData:
            if not string.strip(self.currentData):
                if '\n' in self.currentData:
                    self.currentData = '\n'
                else:
                    self.currentData = ' '
            o = NavigableText(self.currentData, self.currentTag, self.previous)
            if self.previous:
                self.previous.next = o
            self.previous = o
            self.currentTag.contents.append(o)
        self.currentData = ''

    def _pop_to_tag(self, name):
        """Pops the tag stack up to and including the most recent instance
        of the given tag."""
        numPops = 0
        mostRecentTag = None
        for i in range(len(self.tagStack)-1, 0, -1):
            if self.tagStack[i].name == name:
                numPops = len(self.tagStack)-i
                break
        for i in range(0, numPops):
            mostRecentTag = self.popTag()
        return mostRecentTag

    def unknown_starttag(self, name, attrs):
        if self.quoteStack:
            #This is not a real tag.
            #print "<%s> is not real!" % name
            attrs = map(lambda(x, y): '%s="%s"' % (x, y), attrs)
            self.handle_data('<%s %s>' % (name, attrs))
            return
        self.endData()
        tag = Tag(name, attrs, self.currentTag, self.previous)
        if self.previous:
            self.previous.next = tag
        self.previous = tag
        if not name in self.SELF_CLOSING_TAGS and not name in self.NESTABLE_TAGS:
            self._pop_to_tag(name)
        self.pushTag(tag)
        if name in self.SELF_CLOSING_TAGS:
            self.popTag()
        if name in self.QUOTE_TAGS:
            #print "Beginning quote (%s)" % name
            self.quoteStack.append(name)

    def unknown_endtag(self, name):
        if self.quoteStack and self.quoteStack[-1] != name:
            #This is not a real end tag.
            #print "</%s> is not real!" % name
            self.handle_data('</%s>' % name)
            return
        self.endData()
        self._pop_to_tag(name)
        if self.quoteStack and self.quoteStack[-1] == name:
            #print "That's the end of %s!" % self.quoteStack[-1]
            self.quoteStack.pop()

    def handle_data(self, data):
        self.currentData = self.currentData + data

    def handle_comment(self, text):
        "Propagate comments right through."
        self.handle_data("<!--%s-->" % text)

    def handle_charref(self, ref):
        "Propagate char refs right through."
        self.handle_data('&#%s;' % ref)

    def handle_entityref(self, ref):
        "Propagate entity refs right through."
        self.handle_data('&%s;' % ref)

    def handle_decl(self, data):
        "Propagate DOCTYPEs right through."
        self.handle_data('<!%s>' % data)

class BeautifulStoneSoup(BeautifulSoup):

    """A version of BeautifulSoup that doesn't know anything at all
    about what HTML tags have special behavior. Useful for parsing
    things that aren't HTML, or when BeautifulSoup makes an assumption
    counter to what you were expecting."""

    SELF_CLOSING_TAGS = []
    NESTABLE_TAGS = []
    QUOTE_TAGS = []
