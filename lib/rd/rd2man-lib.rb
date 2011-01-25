=begin
= rd/rd2man-lib.rb
=end

require "rd/rdvisitor"

unless [].respond_to? :collect!
  class Array
    alias collect! filter
  end
end

module RD
  class RD2MANVisitor < RDVisitor
    include AutoLabel
    include MethodParse

    SYSTEM_NAME = "RDtool -- RD2ManVisitor"
    SYSTEM_VERSION = "$Version: 0.6.21$" #"
    VERSION = Version.new_from_version_string(SYSTEM_NAME, SYSTEM_VERSION)

    def self.version
      VERSION
    end

    # must-have constants
    OUTPUT_SUFFIX = "1"
    INCLUDE_SUFFIX = ["1"]

    def initialize
      @enumcounter = 0
      @index = {}
      @filename = nil
    end

    def visit(tree)
      prepare_labels(tree, "")
      super(tree)
    end

    def apply_to_DocumentElement(element, content)
      content = content.join
      title = @filename || ARGF.filename || "Untitled"
      title = File.basename title
      title = title.sub(/\.rd$/i, '')
      <<"EOT"
.\\" DO NOT MODIFY THIS FILE! it was generated by rd2
.TH #{title} 1 "#{Time.now.strftime '%B %Y'}"
#{content}
EOT
    end # "

    def apply_to_Headline(element, title)
      element.level <= 1 ? ".SH #{title}\n" : ".SS #{title}\n"
    end

    # RDVisitor#apply_to_Include

    def apply_to_TextBlock(element, content)
      if RD::DescListItem === element.parent ||
	 RD::ItemListItem === element.parent ||
	 RD::EnumListItem === element.parent
	return content.join
      else
	return ".PP\n" + content.join
      end
    end

    def apply_to_Verbatim(element)
      content = []
      element.each_line do |i|
	content.push(apply_to_String(i))
      end
      # Can we use BLOCKQUOTE such like?
      %Q[.nf\n\\&    #{content.join("\\&    ")}.fi\n]
    end

    def apply_to_ItemList(element, items)
      items.collect! do |x| x.sub(/\n\n/, "\n") end
      items = items.join(".IP\n.B\n\\(bu\n")  # "\\(bu" -> "" ?
      ".IP\n.B\n\\(bu\n" + items
    end

    def apply_to_EnumList(element, items)
      @enumcounter = 0
      items.join
    end

    def apply_to_DescList(element, items)
      items.map{ |i| i =~ /\n$/ ? i : i + "\n" }.join("")
    end

    def apply_to_MethodList(element, items)
      items.map{ |i| i =~ /\n$/ ? i : i + "\n" }.join("")
    end

    def apply_to_ItemListItem(element, content)
      content.map{ |c| c =~ /\n$/ ? c : c + "\n" }.join("")
    end

    def apply_to_EnumListItem(element, content)
      @enumcounter += 1
      %Q[.TP\n#{@enumcounter}.\n#{content.join("\n")}]
    end

    def apply_to_DescListItem(element, term, description)
      anchor = refer(element)
      if description.empty?
	".TP\n.fi\n.B\n#{term}"
      else
        %[.TP\n.fi\n.B\n#{term}\n#{description.join("\n")}].chomp
      end
    end

    def apply_to_MethodListItem(element, term, description)
      term = parse_method(term)  # maybe: term -> element.term
      anchor = refer(element)
      if description.empty?
	".TP\n.fi\n.B\n#{term}"
      else
        %[.TP\n.fi\n.B\n#{term}\n#{description.join("\n")}]
      end
    end

    def parse_method(method)
      klass, kind, method, args = MethodParse.analize_method(method)
      
      if kind == :function
	klass = kind = nil
      else
	kind = MethodParse.kind2str(kind)
      end
      
      case method
      when "[]"
	args.strip!
	args.sub!(/^\((.*)\)$/, '\\1')
	"#{klass}#{kind}[#{args}]"
      when "[]="
	args.strip!
	args.sub!(/^\((.*)\)$/, '\\1')
	args, val = /^(.*),([^,]*)$/.match(args)[1,2]
	args.strip!
	val.strip!

	"#{klass}#{kind}[#{args}] = #{val}"
      else
	"#{klass}#{kind}#{method}#{args}"
      end
    end
    private :parse_method

    def apply_to_StringElement(element)
      apply_to_String(element.content)
    end

    def apply_to_Emphasis(element, content)
      %Q[\\fI#{content.join}\\fP]
    end

    def apply_to_Code(element, content)
      %{\\&\\fB#{content.join.sub(/\./, '\\.')}\\fP}
    end

    def apply_to_Var(element, content)
      content.join
    end

    def apply_to_Keyboard(element, content)
      content.join
    end

    def apply_to_Index(element, content)
      tmp = []
      element.each do |i|
	tmp.push(i) if i.is_a?(String)
      end
      key = meta_char_escape(tmp.join)
      if @index.has_key?(key)
	# warning?
	""
      else
	num = @index[key] = @index.size
        %{\\&\\fB#{content.join.sub(/\./, '\\.')}\\fP}
      end
    end

    def apply_to_Reference(element, content)
      case element.label
      when Reference::URL
	apply_to_RefToURL(element, content)
      when Reference::RDLabel
	if element.label.filename
	  apply_to_RefToOtherFile(element, content)
	else
	  apply_to_RefToElement(element, content)
	end
      end
    end

    def apply_to_RefToElement(element, content)
      content = content.join
      content.sub(/^function#/, "")
    end

    def apply_to_RefToOtherFile(element, content)
      content.join
    end
  
    def apply_to_RefToURL(element, content)
      content.join
    end

    def apply_to_Footnote(element, content)
      ""
    end

    def apply_to_Verb(element)
      apply_to_String(element.content)
    end

    def apply_to_String(element)
      meta_char_escape(element)
    end

    def meta_char_escape(str)
      str.gsub(/[-\\]/, '\\\\\\&').gsub(/^[.']/, '\\&') # '
    end
    private :meta_char_escape

  end # RD2MANVisitor
end # RD

$Visitor_Class = RD::RD2MANVisitor

=begin
== script info.
 RD to MAN translate library for rdfmt.rb
 $Id$
 copyright WATANABE Hirofumi <eban@os.rim.or.jp>, 2000
=end
