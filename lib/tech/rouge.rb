# frozen_string_literal: true

require 'rouge'

# Mostly Solaris-specific extensions to the Rouge syntax-colouring library.
# These are crude first attempts, hacked into working as I find more edge
# cases.
#
module Rouge
  module Lexers
    #
    # Highlight DTrace scripts
    #
    class DTrace < RegexLexer
      title 'DTrace'
      desc 'The DTrace dynamic tracing language'
      tag 'dtrace'
      attr_accessor :keywords, :keywords_type

      keywords = %w[
        auto goto sizeof break if static case import string char inline
        stringof const int struct continue long switch counter offsetof
        default probe translator do provider typedef double register union
        else restrict unsigned enum return void extern volatile float
        short system while for signed xlate printf printa trace
      ]

      keywords_type = %w[
        char short int long int8_t int16_t int32_t int64_t intptr_t
        uint8_t uint16_t uint32_t uinit64_t uiniptr_t float double
      ]

      helpers = %w[alloca bcopy copin copyinto copyinstr count self this]

      builtin_vars = %w[curthread tid pid ppid uid gid execname zonename
                        walltimestamp timestamp cpu]

      state :root do
        rule(/\s+/, Text::Whitespace)
        rule(/%(s|d)/, Str::Interpol)
        rule(%r{[~^*!%&\[\](){}<>|+=:;,./?-]}, Operator)
        rule(/^(\S*)(:)(\S*)(:)(\S*)(:)(\S*)$/) do |_m|
          groups Name::Class, Punctuation, Name::Class, Punctuation,
                 Name::Class, Punctuation, Name::Class, Punctuation
        end
        rule(/[0-9]+/, Num::Integer)
        rule(/#.*?$/, Comment::Single)
        rule(/#{keywords.join('|')}/, Keyword)
        rule(/#{helpers.join('|')}/, Keyword::Reserved)
        rule(/#{keywords_type.join('|')}/, Keyword::Type)
        rule(/#{builtin_vars.join('|')}/, Name::Builtin)
        rule(/@\w+/, Name::Variable::Instance) # Aggregate
        rule(/arg\d+/, Name::Variable)
        rule(/\$\w+/, Name::Variable)
        rule(/\$\$\w+/, Name::Variable::Instance) # cast variables
        rule(/".*"/, Str)
      end
    end

    # Highlighting for Solaris Jumpstart profiles
    #
    class JumpstartProfile < RegexLexer
      title 'Jumpstart Profile'
      desc 'profiles for Solaris Jumpstarts'
      tag 'jsprof'

      state :root do
        rule(%r{/\w*$|swap$}, Name::Constant)
        rule(/^\w+/, Keyword)
        rule(/SUNW\w+/, Str)
        rule(/c\d+t\d+d\d+s\d+/, Str)
        rule(/\d+/, Num)
        rule(/delete|add|free/, Keyword::Reserved)
        rule(%r{[\w#"'/]+}, Text)
        rule(/:/, Punctuation)
        rule(/\s/, Text)
      end
    end

    # Highlighting for Solaris sysidcfg files
    #
    class SysIdCfg < RegexLexer
      title 'Solaris sysidcfg'
      tag 'sysidcfg'
      id = /[^\s$;{}()#]+/

      state :basic do
        rule(/PRIMARY/, Keyword::Reserved)
        rule(/=/, Punctuation)
        rule(/^\w+/, Keyword)
        rule(/[\d.]+/, Num)
        rule(/[\w-]+/, Str)
        rule(/\s/, Text)
      end

      open_brace_regex = Regexp.new('{')
      close_brace_regex = Regexp.new('}')

      state :root do
        mixin :basic
        rule open_brace_regex do
          token Punctuation
          push :block
        end
        rule id, Keyword::Namespace
      end

      state :block do
        rule(/^\s*\w+/, Keyword)
        mixin :basic
        rule(close_brace_regex, Punctuation, :pop!)
      end
    end

    # I want to bold commands. I don't want any other colouring, just bold for
    # things you type in and normal for things the machine outputs
    #
    class Command < RegexLexer
      title 'Unix CLI'
      tag 'cmd'
      desc 'put commands in bold. Assumes you begin a command line with a hash
            or dollar, but handles \ escaped continuations, PS2 sub-prompts.
            Also works for Sun OBP "ok" prompts, interactive use of Solaris
            zonecfg, Janet REPL, and SCCLI prompts'
      numbered_ok_prompt_regex = Regexp.new('^{\d+}\s+ok.*')
      ok_prompt_regex = Regexp.new('^ok .*')

      state :root do
        rule(/\n/, Text)
        rule(/^[#$] .*\\/, Generic::Strong, :long)
        rule(/^\w+@manta # .*\\/, Generic::Strong, :long)
        rule(/^\w+@manta # .*/, Generic::Strong)
        rule(/^[>#$] .*/, Generic::Strong)
        rule(/^zonecfg.*>.*/, Generic::Strong)
        rule(/^root@.*# .*/, Generic::Strong)
        rule(/^repl:.*:> .*/, Generic::Strong)
        rule(/^\[[\w-]+\][#$] .*/, Generic::Strong)
        rule(numbered_ok_prompt_regex, Generic::Strong)
        rule(ok_prompt_regex, Generic::Strong)
        rule(/^sccli>.*/, Generic::Strong)
        rule(/^\[[-\w]+\]$/, Comment)
        rule(/\.\.\./, Comment)
      end

      state :long do
        rule(/.*[^\\]$/, Generic::Strong, :pop!)
      end
    end
  end
end
