This directory is for contributed code. It doesn't have to be perfect, but I
think a few guidelines are in order:

Please include comments at the top of the program, stating at least:
1) what the program does
2) say if you think the code is considered to be a one-off tool, a demo or
   prototype that should be improved upon, or a general purpose tool, ready
   for wider use
3) a full example command-line would be welcome
4) include your name, so we can contact you for more information
5) include the date you wrote it, so we can have an idea if it is obsolete

as code gets modified, the comments at the top should be updated accordingly.

- I don't care what language stuff is written in, we'll take anything.
- please please please give your program a meaningful name. If you need to
  add more than one file (e.g a config file as well as the tool), please
  name them coherently (tool-to-do-X, tool-to-do-X.config...). It makes it
  easier to find things if they are all grouped together by name-prefix.
- Do make sure that your program is not dangerous. It should not assume
  that the person running it will have only low-level privileges, if it is
  run by someone with global admin privileges it should be safe.
  E.g. don't attempt to delete all CMS data by default, you may succeed!
- Likewise, either don't provide default values, or provide extremely safe
  ones!
- Don't include sensitive information (passwords, certificates, DBParam
  entries, whatever)

In general, anything that gets to 'production quality' will probably be moved
to the Utilities directory, and become a supported tool. So it's likely that
stuff kept here will not be production quality, and should be understood before
you attempt to use it.
