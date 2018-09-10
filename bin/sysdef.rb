#!/usr/bin/env ruby

require 'logger'
require 'English'
require 'sinatra/base'
require 'pathname'
require_relative '../lib/page_render'
require_relative '../lib/blog_posts'

ROOT          = Pathname.new(__FILE__).dirname.realpath.parent.freeze
LOG           = Logger.new(STDOUT)
POSTS         = BlogPosts.new.freeze
KRAMDOWN_OPTS = { input:              'GFM',
                  syntax_highlighter: 'rouge',
                  hard_wrap:          false }.freeze

# Modularized application
#
class WebApp < Sinatra::Base
  set :root, ROOT

  get '/' do
    @posts = POSTS.all
    slim :front_page
  end

  get '/_health' do
    @posts = POSTS.all
    render_page(:posts, POSTS.uris.sample, POSTS)
  end

  get '/post/:page' do
    render_page(:posts, params[:page], POSTS)
  end

  get '/drafts/:page' do
    render_page(:drafts, params[:page], BlogPosts.new('drafts'))
  end

  get '/tag/:tag' do
    @posts = POSTS.by_tag(params[:tag])
    @tag = params[:tag]
    slim :post_list
  end

  get '/:year/?:month?/?:day?' do
    @posts = POSTS.by_date(params[:year], params[:month], params[:day])
    slim :post_list
  end

  not_found do
    display_404
  end

  run! if $PROGRAM_NAME == __FILE__
end
