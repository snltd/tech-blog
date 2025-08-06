#!/usr/bin/env ruby
# frozen_string_literal: true

require 'addressable'
require 'sinatra/base'
require 'slim'
require 'logger'
require_relative '../lib/tech'

ROOT          = Pathname.new(__dir__).parent.realpath.freeze
POST_DIR      = ROOT.join('posts')
DRAFT_DIR     = ROOT.join('drafts')
ARTICLE_DIR   = ROOT.join('articles')
POST_INDEX    = Tech::IndexPosts.new(POST_DIR)
ARTICLE_INDEX = Tech::IndexArticles.new(ARTICLE_DIR)
LOG           = Logger.new($stdout)
KRAMDOWN_OPTS = { input: 'GFM',
                  syntax_highlighter: 'rouge',
                  hard_wrap: false }.freeze

Slim::Engine.set_options(pretty: true, sort_attrs: false)

module Tech
  # Modularized application
  #
  class WebApp < Sinatra::Base
    helpers SlimHelpers
    set :root, ROOT

    get '/' do
      slim :front_page
    end

    get '/post/:ident' do
      @page = Tech::RenderPost.new(params[:ident]).render
      slim :post
    end

    get '/article/:ident' do
      @page = Tech::RenderArticle.new(params[:ident]).render
      slim :article
    end

    get '/_health' do # render a random page
      @page = Tech::RenderPost.new(POST_INDEX.random_post).render
      slim :post
    end

    get '/tag/:tag' do
      tag = Addressable::URI.unencode(params[:tag])
      @tag = tag
      @posts = POST_INDEX.by_tag(tag)
      slim :post_list
    end

    get '/drafts/:ident' do
      @page = Tech::RenderDraft.new(params[:ident]).render
      slim :article
    end

    not_found do
      slim :'404'
    end

    run! if $PROGRAM_NAME == __FILE__
  end
end
