function loadarcs() {

  R["https"] = "https?[:][/]{2}"
  R["ports"] = "[:]?[8]?[04]?[48]?[30]?"  # :8080 or :443 etc
  R["stamp"] = "([0-9]{4,14}([a-z_*]{1,4})?|[*])[/]"

  # archive.org
  # web, wayback, liveweb, www, www.web
  # classic-web, web-beta, replay, replay.web, web.wayback, wik
  #
  R["iahre"] = "(web|wayback|www|liveweb|www[.]web|classic[-]web|web[-]beta|replay|replay[.]web|web[.]wayback|wik)"
  R["iare"] = R["iahre"] "[.]archive[.]org" R["ports"] "([/]web)?[/]" R["stamp"]

  # webcitation.org
  R["wcre"] = "(www[.])?webcitation[.]org" R["ports"] "[/]"

  # archive.is, .fo, .li, .today, .vn, .md, .ph
  R["isre"] = "(www[.])?archive[.](today|is|fo|li|vn|md|ph)" 

  # LOC - http://webarchive.loc.gov/all/20111109051100/http
  #       http://webarchive.loc.gov/lcwa0010/20111109051100/http
  R["locgovre"] = "webarchive[.]loc[.]gov" R["ports"] "[/](web|all|lcwa[0-9]{1,6})[/]" 

  # Portugal - http://arquivo.pt/wayback/20091010102944/http..
  #          - http://arquivo.pt/wayback/wayback/20091010102944/http.
  R["portore"] = "(www[.])?arquivo[.]pt" R["ports"] "[/](wayback|wayback[/]wayback|wayback[/]all|wayback[/]web|all|web)[/]" 

  # Stanford - https://swap.stanford.edu/20091122200123/http
  R["stanfordre"] = "(swap|sul[-]swap[-]prod)[.]stanford[.]edu" R["ports"] "([/]web)?[/]" 

  # Archive-it.org - http://wayback.archive-it.org/all/20130420084626/http
  R["archiveitre"] = R["iahre"] "[.]archive[-]it[.]org" 

  # BibAlex - http://web.archive.bibalex.org:80/web/20011007083709/http
  #           http://web.petabox.bibalex.org/web/20060521125008/http://developmentgap.org/rmalenvi.html
  R["bibalexre"] = "(web[.])?(petabox|archive)[.]bibalex[.]org" R["ports"] "([/][wa][el][bl])?[/]" 

  # National Archives UK - http://webarchive.nationalarchives.gov.uk/20091204115554/http
  R["natarchiveukre"] = "(webarchives?|yourarchives?)[.]nationalarchives[.]gov[.]uk"

  # National Archives Iceland - http://wayback.vefsafn.is/wayback/20060413000000/http
  R["vefsafnre"] = "wayback[.]vefsafn[.]is" R["ports"] "[/]wayback[/]"

  # Europa Archives (Ireland) - http://collection.europarchive.org/nli/20160525150342/http
  # DEFUNCT
  R["europare"] = "collections?[.]europarchive[.]org" R["ports"] "[/]nli[/]" 

  # Perma.CC Archives - http://perma-archives.org/warc/20140729143852/http
  #                     http://perma.cc/F9NT-22AK
  R["permaccre"] = "perma([-]archives)?[.](org|cc)"

  # Proni Web Archives - http://webarchive.proni.gov.uk/20111213123846/http
  # DEFUNCT
  R["pronire"] = "webarchive[.]proni[.]gov[.]uk" 

  # UK Parliament - http://webarchive.parliament.uk/20110714070703/http
  R["parliamentre"] = "webarchive[.]parliament[.]uk" 

  # UK Web Archive (British Library) - http://www.webarchive.org.uk/wayback/archive/20110324230020/http
  R["ukwebre"] = "www[.]webarchive[.]org[.]uk" R["ports"] "[/]wayback[/]archive[/]" 

  # Canada - http://www.collectionscanada.gc.ca/webarchives/20060209004933/http
  # DEFUNCT
  R["canadare"] = "www[.]collectionscanada[.]gc[.]ca" R["ports"] "[/](webarchives|archivesweb)[/]"

  # Catalonian Archive - http://www.padi.cat:8080/wayback/20140404212712/http
  R["catalonre"] = "www[.]padi[.]cat" R["ports"] "[/]wayback[/]" 

  # Singapore Archives - http://eresources.nlb.gov.sg/webarchives/wayback/20100708034526/http
  R["singaporere"] = "eresources[.]nlb[.]gov[.]sg" "[/]webarchives[/]wayback[/]"

  # Estonia Archives - http://veebiarhiiv.digar.ee/a/20131014091520/http://rakvere.kovtp.ee/en_GB/twin-cities
  R["estoniare"] = "veebiarhiiv[.]digar[.]ee"

  # Bavaria Archives - http://langzeitarchivierung.bib-bvb.de/wayback/20121004142737/http://www.schwabenkrieg.historicum-archiv.net/
  R["bavariare"] = "langzeitarchivierung[.]bib[-]bvb[.]de[/]wayback[/]"

  # Slovenian Archives - http://nukrobi2.nuk.uni-lj.si:8080/wayback/20160203130917/http
  R["slovenere"] = "nukrobi2[.]nuk[.]uni[-]lj[.]si" R["ports"] "[/]wayback[/]" 

  # Freezepage - http://www.freezepage.com/1249681324ZHFROBOEGE
  R["freezepagere"] = "(www[.])?freezepage[.]com"

  # National Archives US - http://webharvest.gov/peth04/20041022004143/http
  R["webharvestre"] = "(www[.])?webharvest[.]gov" R["ports"] "[/][^/]*[/]" R["stamp"]

  # NLA Australia (Pandora, Trove etc)
  #  http://pandora.nla.gov.au/pan/14231/20120727-0512/www.howlspace.com.au/en2/inxs/inxs.htm
  #  http://pandora.nla.gov.au/pan/128344/20110810-1451/www.theaureview.com/guide/festivals/bam-festival-2010-ivorys-rock-qld.html
  #  http://pandora.nla.gov.au/nph-wb/20010328130000/http://www.howlspace.com.au/en2/arenatina/arenatina.htm
  #  http://pandora.nla.gov.au/nph-arch/2000/S2000-Dec-5/http://www.paralympic.org.au/athletes/athleteprofile60da.html
  #  http://webarchive.nla.gov.au/gov/20120326012340/http://news.defence.gov.au/2011/09/09/army-airborne-insertion-capability/
  #  http://content.webarchive.nla.gov.au/gov/wayback/20120326012340/http://news.defence.gov.au/2011/09/09/army-airborne-insertion-capability
  R["nlaaure"] = "(pandora|webarchive|content[.]webarchive)[.]nla[.]gov[.]au" R["ports"] 
  R["nlaaure"] = R["nlaaure"] "[/](pan|nph[-]wb|nph[-]arch|gov|gov[/]wayback)[/]([0-9]{14}|[0-9]{4,7}[/][0-9]{8}[-][0-9]{4}|[0-9]{4}[/][A-Z][0-9]{4}[-][A-Z][a-z]{2}[-][0-9]{1,2})[/]"

  # WikiWix - http://archive.wikiwix.com/cache/20180329074145/http://www.linterweb.fr
  R["wikiwixre"] = "archive[.]wikiwix[.]com"

  # York University Archives
  # https://digital.library.yorku.ca/wayback/20160129214328/http
  R["yorkre"] = "digital[.]library[.]yorku[.]ca" R["ports"] "[/]wayback[/]" 

  # Internet Memory Foundation (Netherlands) - http://collections.internetmemory.org/nli/20160525150342/http
  # DEFUNCT
  R["memoryre"] = "collections[.]internetmemory[.]org" R["ports"] "[/]nli[/]" 

  # Library and Archives Canada - http://webarchive.bac-lac.gc.ca:8080/wayback/20080116045132/http
  R["lacre"] = "webarchive[.]bac[-]lac[.]gc[.]ca" R["ports"] "[/]wayback[/]" 

  # Special archive templates that might hide archive URLs

  # als: {{Toter Link
  # bar: {{Toter Link
  # de:  {{Webarchiv[:space:]*[|]  -- note this includes webcite and archive.is
  # en:  {{Webarchive (full archive URL)
  # es:  {{Wayback
  # fr:  {{Lien archive
  # it:  {{Webarchive (full archive URL)
  # ja:  {{Webarchive (full archive URL)
  # no:  {{Wayback
  # ru:  {{Webarchive (full archive URL)
  # sv:  {{Wayback             
  # zh:  {{Webarchive (full archive URL)
  # ko:
  # lv:
  # zh-yue:                         
  # hu:
  # sr:              
  # ca:
  # gl:
  # cs:
  # az:
  # bn:
  # ur:
  # uk:
  # ar:
  # fa:
  # pt:
  # vi:
  # pl:

  # Templates that don't contain a full archive URL
  DEFINEARCS__es = "|[{]{2}[[:space:]]*wayback[[:space:]]*[|]"

  if( Hostname ~ "^(de|als|bar)$")
    DEFINEARCS__es = DEFINEARCS__es "|[{]{2}[[:space:]]*webarchiv[[:space:]]*[|]"
  else if( Hostname == "fr")
    DEFINEARCS__es = DEFINEARCS__es "|[{]{2}[[:space:]]*lien archive[[:space:]]*[|]"

  # Search for IA links
  R["iasearchre"] = R["https"] "(" R["iare"] ")" DEFINEARCS__es
  # Search for IS links
  R["issearchre"] = R["https"] "(" R["isre"] ")"
  # Search for WebCite links
  R["wcsearchre"] = R["https"] "(" R["wcre"] ")"
  # Search for everything but IA/IS/WebCite links
  R["noiasearchre"] = R["https"] "(" R["parliamentre"] "|" R["ukwebre"] "|" R["canadare"] "|" R["catalonre"] "|" R["singaporere"] "|" R["slovenere"] "|" R["europare"] "|" R["bibalexre"] "|" R["archiveitre"] "|" R["stanfordre"] "|" R["vefsafnre"] "|" R["portore"] "|" R["locgovre"] "|" R["nlaaure"] "|" R["permaccre"] "|" R["pronire"] "|" R["wikiwixre"] "|" R["webharvestre"] "|" R["natarchiveukre"] "|" R["freezepagere"] "|" R["yorkre"] "|" R["memoryre"] "|" R["lacre"] "|" R["estoniare"] "|" R["bavariare"] ")"
  
}

