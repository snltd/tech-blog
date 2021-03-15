#!/usr/bin/env ruby
# frozen_string_literal: true

require 'addressable'
require 'sinatra/base'
require 'slim'
require 'logger'
require 'pathname'
require_relative '../lib/sysdef'

ROOT          = Pathname.new(__dir__).parent.realpath.freeze
POST_DIR      = ROOT + 'posts'
DRAFT_DIR     = ROOT + 'drafts'
ARTICLE_DIR   = ROOT + 'articles'
POST_INDEX    = Sysdef::IndexPosts.new(POST_DIR)
ARTICLE_INDEX = Sysdef::IndexArticles.new(ARTICLE_DIR)
LOG           = Logger.new($stdout)
KRAMDOWN_OPTS = { input: 'GFM',
                  syntax_highlighter: 'rouge',
                  hard_wrap: false }.freeze

Slim::Engine.set_options(pretty: true, sort_attrs: false)

module Sysdef
  # Modularized application
  #
  class WebApp < Sinatra::Base
    helpers SlimHelpers
    set :root, ROOT

    get '/' do
      slim :front_page
    end

    # Some blog posts have been promoted to permanent articles
    #
    get '/post/2017-07-26-wavefront-cli' do
      redirect 'https://sysdef.xyz/article/wavefront-cli'
    end

    get '/post/2018-04-08-wavefront-writer' do
      redirect 'https://sysdef.xyz/article/wavefront-writer'
    end

    get '/post/:ident' do
      @page = Sysdef::RenderPost.new(params[:ident]).render
      slim :post
    end

    get '/article/:ident' do
      @page = Sysdef::RenderArticle.new(params[:ident]).render
      slim :article
    end

    get '/_health' do # render a random page
      @page = Sysdef::RenderPost.new(POST_INDEX.random_post).render
      slim :post
    end

    get '/tag/:tag' do
      @posts = POST_INDEX.by_tag(params[:tag])
      slim :post_list
    end

    get '/privacy' do
      slim :privacy
    end

    get '/drafts/:ident' do
      @page = Sysdef::RenderDraft.new(params[:ident]).render
      slim :article
    end

    #
    #     get '/:year/?:month?/?:day?' do
    #       @posts = POSTS.by_date(params[:year], params[:month], params[:day])
    #       slim :post_list
    #     end

    not_found do
      slim :'404'
    end

    run! if $PROGRAM_NAME == __FILE__
  end
end
