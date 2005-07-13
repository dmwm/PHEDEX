/*

ROOT macro to read GUIDs from POOL files
From Markus Frank of POOL

Execute the above script from the root prompt, then check the section
"Shapes".
The script does not have any POOL dependencies - it's plain root.


J:\LCG\POOL\POOL_2_2_0\src\config\cmt\PoolRelease\cmt>root.exe
  *******************************************
  *                                         *
  *        W E L C O M E  to  R O O T       *
  *                                         *
  *   Version  4.04/02b       3 June 2005   *
  *                                         *
  *  You are welcome to visit our Web site  *
  *          http://root.cern.ch            *
  *                                         *
  *******************************************

Compiled on 29 June 2005 for win32.

CINT/ROOT C/C++ Interpreter version 5.15.169, Mar 14 2005
Type ? for help. Commands must be C++ statements.
Enclose multiple statements between { }.

root [0] .L dumpFile.C+
root [1]
dumpFile("rfio:/castor/cern.ch/lhcb/DC04/00000541_00000001_9.dst")


================= Parameters ============
Param: FID                             :
6A784897-27A5-D811-9C25-0002B3AFAF46
Param: PFN                             : 00000541_00000001_9.dst
Param: POOL_VSN                        : 1.1
Param: FORMAT_VSN                      : 1.1


================= Links =================
Link:  Dbase=<localDB>  Container=##Params
       CLID=DA8F479C-09BC-49D4-94BC-99D025A23A3B Technology=00000200
OID=00000002-FFFFFFFF
Link:  Dbase=<localDB>  Container=/Event
       CLID=00000001-0000-0000-0000-000000000000 Technology=00000202
OID=00000003-FFFFFFFF
....

================= Shapes ================
Shape: GUID= 00000001-0000-0000-0000-000000000000
       CLASS=DataObject
       NCOL =3
       COL[0]=NAME=DataObject
              TYPE=DataObject
              TYPN=21 OPTS=0 OFFS=0 SIZE=0 ELEM=1
       COL[1]=NAME=Links
              TYPE=LinkManager
              TYPN=21 OPTS=0 OFFS=0 SIZE=0 ELEM=1
       COL[2]=NAME=Refs
              TYPE=PoolDbLinkManager
              TYPN=21 OPTS=0 OFFS=0 SIZE=0 ELEM=1

*/

#include "TFile.h"
#include "TTree.h"
#include "TBranch.h"

void printText(const char* text)  {
    printf("%s\n\n",text);
}

void printLink(const char* text)  {
  for(char* p1 = (char*)text; p1; p1 = ::strchr(++p1,'[')) {
    char* p2 = ::strchr(p1, '=');
    char* p3 = ::strchr(p1, ']');
    if ( p2 && p3 )   {
      char* val = p2+1;
      if ( ::strncmp("[DB=", p1, 4) == 0 )  {
        *p3 = 0;
        printf("Link:  Dbase=%s  ", p1+4);
      }
      else if ( ::strncmp("[CNT=", p1, 5) == 0 )  {
        *p3 = 0;
        printf("Container=%s \n", p1+5);
      }
      else if ( ::strncmp("[OID=", p1, 5) == 0 )  {
        *p3 = 0;
        printf(" OID=%s", p1+5);
      }
      else if ( ::strncmp("[CLID=", p1, 6) == 0 )  {
        *p3 = 0;
        printf("       CLID=%s", p1+6);
      }
      else if ( ::strncmp("[TECH=", p1, 6) == 0 )  {
        *p3 = 0;
        printf(" Technology=%s", p1+6);
      }
      else    {
        *p3 = *p2 = 0;
      }
      *p3 = ']';
      *p2 = '=';
    }
  }
  printf("\n");
}

void printParam(const char* text)  {
  char* id1 = strstr(text,"[NAME=");
  char* id2 = strstr(text,"[VALUE=");
  if ( id1 && id2 )  {
    id1 += 6;
    id2 += 7;
    char* id11 = strstr(id1, "]");
    char* id22 = strstr(id2, "]");
    if ( id11 && id22 )  {
      *id11 = 0;
      *id22 = 0;
      printf("Param: %-32s: %s\n", id1, id2);
    }
  }
}

void printColumn(const char* prefix, char* text)  {
  const char* itm[7] = { "{NAME=", "{CLASS=", "{TYP=", "{OPT=", "{OFF=", "{SIZ=","{CNT=" };
  char* p1 = text;
  int nread = 0;
  for(int i = 0; i < sizeof(itm)/sizeof(itm[0]); ++i)   {
    p1 = strstr(p1, itm[i]);
    const char* pp1 = p1+strlen(itm[i]);
    if ( p1 )    {
      char* p2 = ::strstr(pp1, "}");
      if ( p2 )   {
        *p1 = 0;
        *p2 = 0;
        switch(i)   {
        case 0:
          printf("NAME=%s\n", pp1);
          break;
        case 1:
          printf("%sTYPE=%s\n", prefix, pp1);
          break;
        case 2:
          printf("%sTYPN=%s ", prefix, pp1);
          break;
        case 3:
          printf("OPTS=%s ", pp1);
          break;
        case 4:
          printf("OFFS=%s ", pp1);
          break;
        case 5:
          printf("SIZE=%s ", pp1);
          break;
        case 6:
          printf("ELEM=%s ", pp1);
          break;
        default:
          break;
        }
        *p1 = '{';
        *p2 = '}';
      }
    }
  }
}

void printShape(char* p1)  {
  const char* itp[] = { "{ID=", "{CL=", "{NCOL=", "{COL={"};
  const char* itq[] = { "}",    "}",    "}",      "}}"    };
  int ncol=-1;
  int num_col = 0;
  for(int i = 0; i < 4; ++i)   {
Again:
    const char* pp2 = p1;
    p1 = strstr(pp2, itp[i]);
    if ( p1 )    {
      const char* pp1 = p1+strlen(itp[i]);
      char* p2 = strstr(pp1, itq[i]);
      if ( p2 )   {
        p2 += strlen(itq[i])-1;
        *p1 = 0;
        *p2 = 0;
        switch(i) {
        case 0:
          printf("\nShape: GUID= %s\n", pp1);
          break;
        case 1:
          printf("       CLASS=%s\n", pp1);
          break;
        case 2:
          printf("       NCOL =%s\n", pp1);
          sscanf(pp1, "%d", &ncol);
          break;
        case 3:
          printf("       COL[%d]=",num_col);
          printColumn("              ", (char*)pp1);
          printf("\n");
          num_col++;
          break;
        default:
          break;
        }
        *p1 = '{';
        *p2 = '}';
        if ( i > 2 && num_col < ncol )  {
          p1++;
          goto Again;
        }
      }
    }
  }  
}

void dumpFile(char* fname, bool dbg=false) {
  TFile* f=TFile::Open(fname);
  char text[16000];
  TBranch* b=0;
  int i;
  printf("\n\n================= Parameters ============\n");
  b = ((TTree*)f->Get("##Params"))->GetBranch("db_string");
  for(i=0,b->SetAddress(text); i < b->GetEntries();++i) {
    b->GetEvent(i);
    if ( dbg ) printText(text);
    printParam(text);
  }
  printf("\n\n================= Links =================\n");
  b = ((TTree*)f->Get("##Links"))->GetBranch("db_string");
  for(i=0,b->SetAddress(text); i < b->GetEntries(); ++i) {
    b->GetEvent(i);
    if ( dbg ) printText(text);
    printLink(text);
  }
  printf("\n\n================= Shapes ================\n");
  b = ((TTree*)f->Get("##Shapes"))->GetBranch("db_string");
  for(i=0,b->SetAddress(text);i<b->GetEntries();++i) {
    b->GetEvent(i);
    if ( dbg ) printText(text);
    printShape(text);
  }
  delete f;
}

