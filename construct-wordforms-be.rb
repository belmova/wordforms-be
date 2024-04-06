#!/usr/bin/env ruby
# Copyright © 2024, Siarhei Siamashka
# Creative Commons Attribution-ShareAlike 4.0 International License

require "rexml/document"
require "date"
include REXML

VERBOSE = false

def normalize(word)
  # Certain single syllable prepositions are actually unstressed, see
  #    https://be.wikisource.org/wiki/Page:Беларускі_правапіс_(1927).pdf/39
  return word.gsub("+", "") if ["у+", "не+", "бе+з"].include?(word)
  # U+301 for stress and U+2BC for apostrophe
  return word.strip.gsub("+", "\xCC\x81").gsub("'", "\xCA\xBC")
end

def spellings(word)
  # generate different possible spelling variants of the word
  result = [word]
  if word =~ /^у/ && !(word =~ /^у́/)
    result.push(word.gsub(/^у/, "ў"))
  end
  if word =~ /ʼ/
    tmp1 = result.map {|word| word.gsub("ʼ", "'") }
    tmp2 = result.map {|word| word.gsub("ʼ", "’") }
    result = result + tmp1 + tmp2
  end
  return result
end

def parse_xml_file(fname, results_modern, results_all, alt)
  file = File.new(fname)
  doc = Document.new(file)

  doc.elements["Wordlist"].each do |paradigm|
    next unless paradigm.to_s =~ /^\<Paradigm/
    abort "error 1\n" unless paradigm.attributes.has_key?("lemma")
    paradigm_lemma = normalize(paradigm.attributes["lemma"].to_s)
    paradigm.each do |variant|
      next unless variant.to_s =~ /^\<Variant/
      abort "error 2\n" unless variant.attributes.has_key?("lemma")
      modern_pravapis = variant.attributes.has_key?("pravapis") && variant.attributes["pravapis"].to_s =~ /A2008/
      modern_pravapis = false if variant.attributes["type"].to_s =~ /(nonstandard)|(potential)/
      lemma = normalize(variant.attributes["lemma"].to_s)
      abort "error 3\n" if lemma =~ /\|/
      next if lemma =~ /[\-\.]/ || lemma =~ /\s/
      alt.push([paradigm_lemma, lemma]) if paradigm_lemma != lemma
      results_all[lemma] = {} unless results_all.has_key?(lemma)
      if modern_pravapis
        results_modern[lemma] = {} unless results_modern.has_key?(lemma)
      end
      tags = {}
      variant.each do |form|
        next unless form.to_s =~ /^\<Form/
        word = normalize(form[0].to_s)
        if word == "" || word =~ /\|/ || word =~ /\-/
          STDERR.printf("== skipping bad form: ==\n") if VERBOSE
          STDERR.puts variant.to_s if VERBOSE
          next
        end
        spellings(word).each do |wordvar|
          results_all[lemma][wordvar] = true
          unless form.attributes["type"].to_s =~ /(nonstandard)|(potential)/
            results_modern[lemma][wordvar] = true if modern_pravapis
          end
        end
      end
    end
  end
end

xml_list = "A1.xml  A2.xml  C.xml  E.xml  I.xml  K.xml  M.xml  N1.xml  N2.xml  N3.xml  NP.xml  P.xml  R.xml  S.xml  V.xml  W.xml  Y.xml Z.xml"
tagname = "RELEASE-202309"

unless File.exists?("GrammarDB/data/")
  STDERR.print("Please run 'git clone -b #{tagname} https://github.com/Belarus/GrammarDB.git'\n")
  exit 1
end

results_modern = {}
results_all = {}
alt = []

xml_list.split.each do |fname|
  STDERR.printf("Processing: %s\n", fname)
  parse_xml_file("GrammarDB/data/" + fname, results_modern, results_all, alt)
end

STDERR.printf("Generating: wordforms-be-2008.txt\n")
fh = File.open("wordforms-be-2008.txt", "w")
fh.printf("# This file was automatically generated from the https://github.com/Belarus/GrammarDB\n")
fh.printf("# data (Grammar Database of Belarusian language) using the #{tagname} tag.\n")
fh.printf("# Creative Commons Attribution-ShareAlike 4.0 International License.\n")
fh.printf("#\n")
fh.printf("# Uses UTF-8 format with U+0301 stress marks and U+2BC apostrophes. Each line starts\n")
fh.printf("# with a single lemma, followed by the '|' delimited list of all its possible forms.\n")
fh.printf("# The ў/у variants and different apostrophe types are also present in the list.\n")
fh.printf("#\n")
fh.printf("# Official Belarusian orthography (be-1959acad) adhering to the latest 2008 reform.\n")
fh.printf("# Intended to be used by spellcheckers, which need to be strict.\n")
fh.printf("#\n")
results_modern.to_a.sort {|x, y| x[0] <=> y[0] }.each {|x| fh.printf("%s\n", ([x[0]] + x[1].keys.sort.select {|y| y != x[0] }).join("|")) }
fh.close

STDERR.printf("Generating: wordforms-be-all.txt\n")
fh = File.open("wordforms-be-all.txt", "w")
fh.printf("# This file was automatically generated from the https://github.com/Belarus/GrammarDB\n")
fh.printf("# data (Grammar Database of Belarusian language) using the #{tagname} tag.\n")
fh.printf("# Creative Commons Attribution-ShareAlike 4.0 International License.\n")
fh.printf("#\n")
fh.printf("# Uses UTF-8 format with U+0301 stress marks and U+2BC apostrophes. Each line starts\n")
fh.printf("# with a single lemma, followed by the '|' delimited list of all its possible forms.\n")
fh.printf("# The ў/у variants and different apostrophe types are also present in the list.\n")
fh.printf("#\n")
fh.printf("# Official Belarusian orthography (be-1959acad), but deprecated Narkamaŭka spelling\n")
fh.printf("# forms are also included. Intended to be used by ebook dictionaries to 'catch them all'.\n")
fh.printf("#\n")
results_all.to_a.sort {|x, y| x[0] <=> y[0] }.each {|x| fh.printf("%s\n", ([x[0]] + x[1].keys.sort.select {|y| y != x[0] }).join("|")) }
fh.close

STDERR.printf("Generating: wordforms-be-altpairs.txt\n")
fh = File.open("wordforms-be-altpairs.txt", "w")
fh.printf("# This file was automatically generated from the https://github.com/Belarus/GrammarDB\n")
fh.printf("# data (Grammar Database of Belarusian language) using the #{tagname} tag.\n")
fh.printf("# Creative Commons Attribution-ShareAlike 4.0 International License.\n")
fh.printf("#\n")
fh.printf("# Uses UTF-8 format with U+0301 stress marks and U+2BC apostrophes. Each line lists\n")
fh.printf("# a pair of alternative spelling variants of the same word delimited by '|'.\n")
fh.printf("# Intended to be used by ebook dictionaries. If these two are not separate headwords\n")
fh.printf("# in a dictionary, then it makes sense to link them together.\n")
fh.printf("#\n")
alt.sort.uniq.map {|x| fh.printf("%s|%s\n", x[0], x[1]) }
fh.close
