#!/usr/bin/env ruby

require 'sinatra/base'
require 'slim'
require 'logger'
require 'pathname'
require_relative '../lib/sysdef'

ROOT          = Pathname.new(__dir__).parent.realpath.freeze
POST_DIR      = ROOT + 'posts'
ARTICLE_DIR   = ROOT + 'articles'
POST_INDEX    = Sysdef::IndexPosts.new(POST_DIR)
ARTICLE_INDEX = Sysdef::IndexArticles.new(ARTICLE_DIR)
LOG           = Logger.new(STDOUT)
KRAMDOWN_OPTS = { input:              'GFM',
                  syntax_highlighter: 'rouge',
                  hard_wrap:          false }.freeze

Slim::Engine.set_options pretty: true, sort_attrs: false

module Sysdef
  # Modularized application
  #
  class WebApp < Sinatra::Base
    helpers SlimHelpers
    set :root, ROOT

    get '/' do
      slim :front_page
    end

    get '/date/:ident' do
      @page = Sysdef::RenderPost.new(params[:ident]).render
      slim :post
    end

    get '/_health' do # render a random page
      @page = Sysdef::RenderPost.new(POST_INDEX.random_post).render
      slim :post
    end

    get '/tag/:tag' do
      @posts = POST_INDEX.by_tag(params[:tag])
      slim :post_list
    end

=begin


    get '/drafts/:page' do
      render_page(:drafts, params[:page], BlogPosts.new('drafts'))
    end

    get '/:year/?:month?/?:day?' do
      @posts = POSTS.by_date(params[:year], params[:month], params[:day])
      slim :post_list
    end
=end

    not_found do
      slim :'404'
    end

    run! if $PROGRAM_NAME == __FILE__
  end
end
