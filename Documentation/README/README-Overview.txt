* Documentation overview

The PHEDEX system consists of several components:
 1) Transfer management database (TMDB), currently version is 2.5.
 2) Transfer agents that move files from site to site.
 3) Management agents, in particular the allocator agent which assigns
    files to destinations based on site data subscriptions, and
    routing agent to maintains file transfer routing information.
 4) Tools to manage transfer requests; CMS/DBS/DLS specific.
 5) Drop box agents for managing files locally, for instance as files
    arrive from a transfer request or a production farm, including any
    processing that needs to be done before they can be made available
    for transfer: massaging information, staging in files, calculating
    missing checksums, registering files into the catalogues, injecting
    into TMDB.

** Overview documentation

WhitePapers/overview.tex describes the whole system.

WhitePapers/routing.tex describes the file routing.

WhitePapers/schema.tex describes TMDB schema and how transfer agents
should interpret and maintain the information.

** Management documentation

README/README-Deployment.txt describes how to set up a new site.

README/README-Auth.txt describes how to authenticate to database.

README/README-Operations.txt describes current operations practises for
CMS transfers; currently only for CERN, but hopelly more later on.

README/README-DeveloperTestbed.txt describes how to set up a testbed.

README/README-Managers.txt describes the management agents.

** Detailed documentation

README/README-Agents.txt describes the drop box agents.

Tesbed/RLSTest/README.txt describes a stand-alone test-bed setup for
catalogue performance benchmarking.

** Support

If you have any questions or comments, please contact the developers
at <hn-cms-phedex@cern.ch>.  You are welcome to file bug reports
and support requests at our Savannah site at
  http://savannah.cern.ch/projects/phedex
