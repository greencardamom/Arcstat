function loadtrans(Hostname,Domain,  a,b,i,bookn,journaln,newsn,magazinen,language) {

  # Literal name of template listed first, redirects after

  if(Hostname == "als" && Domain == "wikipedia.org") {
    bookn = "Literatur|Cite[ -]?book"
  }
  else if(Hostname == "alt" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "ar" && Domain == "wikipedia.org") {
    bookn = "استشهاد بكتاب|Book cite|Citebook|Cite[ -]?book|مرجع كتاب|Cite publication|يستشهد كتاب|Book reference|Cite work|Cita libro"
  }
  else if(Hostname == "arz" && Domain == "wikipedia.org") {
    bookn = "مرجع كتاب|Cite[ -]?book"
  }
  else if(Hostname == "az" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "azb" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book|کیتاب قایناقلاما|قایناق کیتاب"
  }
  else if(Hostname == "bar" && Domain == "wikipedia.org") {
    bookn = "Literatur"
  }
  else if(Hostname == "be" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book|Citation"
  }
  else if(Hostname == "be-tarask" && Domain == "wikipedia.org") {
    bookn = "Кніга|Cite book|Cite[ -]?book"
  }
  else if(Hostname == "bg" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book|Цитат книга"
  }
  else if(Hostname == "bn" && Domain == "wikipedia.org") {
    bookn = "বই উদ্ধৃতি|গ্রন্থ উদ্ধৃতি|Cite work|Cite publication|Citebook|Cite chapter|Book reference|Cite book"
  }
  else if(Hostname == "br" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "bs" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "ca" && Domain == "wikiquote.org") {
    bookn = "Ref-llibre|Ref[ -]?llibre|Citar llibre"
  }
  else if(Hostname == "ce" && Domain == "wikiquote.org") {
    bookn = "Книга|Cite[ -]?book"
  }
  else if(Hostname == "ceb" && Domain == "wikiquote.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "ckb" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "cs" && Domain == "wikipedia.org") {
    bookn = "Citace monografie|Citace knihy|Cite[ -]?book"
  }
  else if(Hostname == "cy" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "da" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "de" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book|Literatur"
  }
  else if(Hostname == "en" && Domain == "wikipedia.org") { 
    bookn = "Cite book|Cite[ -]?book|Ref-llibre|Cite publication|Cite-book|C book|Book reference url|Citace monografie|Bokref|Cite books|Cite chapter|Cit book|Citar livro|Cite work|Citeer boek|Cite manual|Book cite|Cite ebook|Citebook|Book reference"
    journaln = "Cite journal|Citace periodika|저널 인용|Cytuj pismo|Citar publicació|Навод из стручног часописа|Tidskriftsref|Citejournal|Citar jornal|Cite abstract|Cite journal zh|Cita pubblicazione|Cite document|Citepaper|Cite paper|Citation journal|Vcite2 journal|Cite Journal|C journal|Cit journal"
    newsn = "Cite news|استشهاد بخبر|Cite News|뉴스 인용|Cit news|Cute news|Cite news2|Cite news-q|Tidningsref|Cite article|Chú thích báo|Cite newspaper|Citar notícia|Citation news|Citenewsauthor|Citenews|Haber kaynağı|Cite new|Cite-news|Cite n|C news"
    magazinen = "Cite magazine|Cite newsletter|Cite magazine article|Cite periodical|Cite mag"
    language = "English"
  }
  else if(Hostname == "en" && Domain == "wiktionary.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "el" && Domain == "wikipedia.org"){
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "es" && Domain == "wikipedia.org") {
    bookn = "Ref libro|Ouvrage|Ref-libro|Citalibro|Cita libro|Cite[ -]?book"
  }
  else if(Hostname == "eu" && Domain == "wikipedia.org"){
    bookn = "Erreferentzia|Cite book|Cite journal|Liburu erref|Cite aldizkari|Citation|Web erref|Txikipedia-Erreferentzia|Cite news|Cite web|Albiste erref"
  }
  else if(Hostname == "fa" && Domain == "wikipedia.org"){
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "fi" && Domain == "wikipedia.org"){
    bookn = "Kirjaviite|Cite book|Cite[ -]?book"
  }
  else if(Hostname == "fr" && Domain == "wiktionary.org"){ 
    bookn = "ouvrage|Cite[ -]?book"
  }
  else if(Hostname == "fr" && Domain == "wikipedia.org") {
    bookn = "Ouvrage|Cite[ -]?document|Cite[ -]?book"
  }
  else if(Hostname == "gl" && Domain == "wikipedia.org") {
    bookn = "Cita libro|Cite[ -]?book"
  }
  else if(Hostname == "he" && Domain == "wikipedia.org"){
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "hi" && Domain == "wikipedia.org"){
    bookn = "Cite book|Cite[ -]?book|पुस्तक सन्दर्भ"
  }
  else if(Hostname == "hu" && Domain == "wikipedia.org") {
    bookn = "Hivatkozás/Könyv|Cite[ -]?book|Cite magazine"
  }
  else if(Hostname == "hy" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "is" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "id" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite work|Referensi buku|Cite publication|Citebook|Book reference"
  }
  else if(Hostname == "it" && Domain == "wikipedia.org") {
    bookn = "Cita libro"
  }
  else if(Hostname == "ka" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "ko" && Domain == "wikipedia.org") {
    bookn = "서적 인용|도서 인용|책 인용|서적인용|Cite manual|Cite[ -]?book"
  }
  else if(Hostname == "ku" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "lt" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "lv" && Domain == "wikipedia.org") {
    bookn = "Grāmatas atsauce|Cite[ -]?book"
  }
  else if(Hostname == "my" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "nl" && Domain == "wikipedia.org") {
    bookn = "Citeer boek|Cite[ -]?book"
  }
  else if(Hostname == "nl" && Domain == "wikinews.org") {
    bookn = "Citeer boek|Cite[ -]?book"
  }
  else if(Hostname == "no" && Domain == "wikipedia.org") {
    bookn = "Kilde bok|bok|Cite[ -]?book"
  }
  else if(Hostname == "pl" && Domain == "wikipedia.org") {
    bookn = "Cytuj książkę|Cite[ -]?book"
  }
  else if(Hostname == "pt" && Domain == "wikipedia.org") {
    bookn = "Citar livro|Citar manual|Cita libro|Ouvrage|Cite manual|Literatur|Ref-livro|Referência a livro|Cite[ -]?book"
  }
  else if(Hostname == "ru" && Domain == "wikipedia.org") {
    bookn = "Учебник|Книга|Cite[ -]?book"
  }
  else if(Hostname == "sco" && Domain == "wikipedia.org"){
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "simple" && Domain == "wikipedia.org"){ 
    bookn = "Cite book|Cite[ -]?book|Citebooks|Cite manual"
  }
  else if(Hostname == "sh" && Domain == "wikipedia.org"){
    bookn = "Knjiga (SR)|Book reference|Knjiga|Cite book|Cite[ -]?book"
  }
  else if(Hostname == "species" && Domain == "wikimedia.org"){
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "sq" && Domain == "wikipedia.org"){
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "sr" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book|Cite manual"
  }
  else if(Hostname == "sv" && Domain == "wikipedia.org") { # See also bokref for similar local templ
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "sw" && Domain == "wikipedia.org"){
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "tay" && Domain == "wikipedia.org"){
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "te" && Domain == "wikipedia.org"){
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "tr" && Domain == "wikipedia.org") {
    bookn = "Kitap kaynağı|Kitap[ -]?kayna[ğg]ı|Cite[ -]?book"
    journaln = "Akademik dergi kaynağı|Cite document|Cite science|Cite journal"
    newsn = "Haber kaynağı|Cite news|Haberkaynağı|Citenewspaper|Citenews|Gazetekaynağı|Gazete kaynağı|Cite newspaper|Haber belirt"
    magazinen = "Dergi kaynağı|Cite magazine|Citejournal|Cite paper"
    language = "Turkish"
  }
  else if(Hostname == "uk" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book|КнигаАПА|Cite книга|Cite manual"
  }
  else if(Hostname == "ur" && Domain == "wikipedia.org") {
    bookn = "حوالہ کتاب|Cite کتاب|Cite[ -]?book|استشهاد بكتاب|Citebook|یادکرد کتاب|حوالہ-کتاب|مرجع كتاب|"
  }
  else if(Hostname == "uz" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "vi" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "war" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book"
  }
  else if(Hostname == "zh-yue" && Domain == "wikipedia.org"){ 
    bookn = "引書|Cite[ -]?book"
  }
  else if(Hostname == "zh" && Domain == "wikipedia.org") {
    bookn = "Cite book|Cite[ -]?book|Cite book en|Cite book zh|Ouvrage|来源-书籍|Cite work|Cite article|Cite book/en|Book reference 3|Cite manual|Citebook|Book reference"
  }
  else {
    bookn = "Cite book"
  }

  for(i = 1; i <= splitn("book\njournal\nnews\nmagazine", a, i); i++) {
    if(a[i] == "book") {
      R[a[i] "re"] = "[{]{2}[[:space:]]*(" bookn ")[[:space:]]*[|][^}]+[}]{2}"
      split(bookn, b, "|")
      R[a[i] "tlname"] = strip(b[1])
    }
    else if(a[i] == "journal") {
      R[a[i] "re"] = "[{]{2}[[:space:]]*(" journaln ")[[:space:]]*[|][^}]+[}]{2}"
      split(journaln, b, "|")
      R[a[i] "tlname"] = strip(b[1])
    }
    else if(a[i] == "news") {
      R[a[i] "re"] = "[{]{2}[[:space:]]*(" newsn ")[[:space:]]*[|][^}]+[}]{2}"
      split(newsn, b, "|")
      R[a[i] "tlname"] = strip(b[1])
    }
    else if(a[i] == "magazine") {
      R[a[i] "re"] = "[{]{2}[[:space:]]*(" magazinen ")[[:space:]]*[|][^}]+[}]{2}"
      split(magazinen, b, "|")
      R[a[i] "tlname"] = strip(b[1])
    }
  }  

  R["plainlang"] = language

  return 1

}

