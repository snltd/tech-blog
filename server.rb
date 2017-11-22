#!/usr/bin/env ruby

%w(sinatra slim yaml date pathname kramdown).each { |f| require f }
ROOT = Pathname.new(__FILE__).dirname.realpath
%w(rouge common blog).each { |f| require ROOT + 'lib' + f }

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

set :bind, '0.0.0.0'

kramdown_options = {
  input:              'GFM',
  syntax_highlighter: 'rouge',
  hard_wrap:          false,
}

blog = Blog.new

get '/' do
  @posts = blog.cache
  @tags = blog.tags[0..9]
	slim :front_page
end

get '/post/:page' do
  md_file = ROOT + 'posts' + "#{params[:page]}.md"

  if md_file.exist?
    @meta = blog.cache["#{params[:page]}.md"]
    raw = blog.parse_file(md_file).last
    @content = Kramdown::Document.new(raw, kramdown_options).to_html
    @posts = blog.cache
    @tags = blog.tags[0..9]
    slim :post
  else
    status 404
    slim :error_page
  end
end

get '/tag/:tag' do
  @posts = blog.posts_by_tag(params[:tag])
  @tag = params[:tag]
  slim :post_list
end

get '/:year/?:month?/?:day?' do
  @posts = blog.posts_by_date(params[:year], params[:month], params[:day])
  if @posts.empty?
    status 404
    @breadcrumbs = nil
    @nofooter = true
    slim :error_page
  else
    slim :post_list
  end
end

not_found do
  status 404
  @breadcrumbs = nil
  @nofooter = true
  slim :error_page
end
