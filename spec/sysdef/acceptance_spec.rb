#!/usr/bin/env ruby
# frozen_string_literal: true

%w[minitest minitest/unit minitest/autorun rack/test pathname
   erb nokogiri].each { |f| require f }

APP_ROOT = Pathname.new(__dir__).realpath.parent.parent

OUTER_APP = Rack::Builder.parse_file((APP_ROOT + 'config.ru').to_s).first

# Acceptance tests for the Sysdef website. Just hit the app lots and
# lots of times
#
class TestSysdef < MiniTest::Test
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  def test_front_page
    get '/'
    assert_equal(200, last_response.status)
    assert last_response.body.include?('We have experience')
    body = Nokogiri::HTML(last_response.body)
    assert_header(body)
    assert body.css('#post_title').empty?
    assert_sidebar(body)
    assert_footer(body)
  end

  def test_privacy_policy
    get '/privacy'
    assert_equal(200, last_response.status)
    body = Nokogiri::HTML(last_response.body)
    assert_header(body)
    assert body.inner_html.include?('We do not log anything')
    assert body.css('#post_title').empty?
    assert_sidebar(body)
    assert_footer(body)
  end

  def test_all_posts
    get '/'
    extract_post_links(last_response.body).each do |uri|
      _test_blog_post(uri)
    end
  end

  def test_all_articles
    get '/'
    extract_article_links(last_response.body).each do |uri|
      _test_article(uri)
    end
  end

  def test_all_tags
    get '/'
    extract_tag_links(last_response.body).each do |uri|
      _test_tag(uri)
    end
  end

  def test_api_not_found
    get '/api/no_such_thing'
    assert_equal(404, last_response.status)
    refute last_response.body.include?('Sinatra doesn’t know this ditty')
    assert last_response.body.include?('404')
    body = Nokogiri::HTML(last_response.body)
    assert_header(body)
    refute body.css('#container').empty?
    assert_footer(body)
  end

  def test_health
    get '/_health'
    assert_equal(200, last_response.status)
    body = Nokogiri::HTML(last_response.body)
    assert_header(body)
    assert_sidebar(body)
    assert_footer(body)
  end

  # Everything below here is helper
  #
  def _test_blog_post(uri)
    get uri
    assert_equal(200, last_response.status)
    body = Nokogiri::HTML(last_response.body)
    assert_header(body)
    assert_sidebar(body)
    assert_footer(body)
  end

  def _test_article(uri)
    get uri
    assert_equal(200, last_response.status)
    body = Nokogiri::HTML(last_response.body)
    assert_header(body)
    assert_body_copy(body)
    assert_sidebar(body)
    assert_footer(body)
  end

  def _test_tag(uri)
    get ERB::Util.url_encode(uri)
    assert_equal(200, last_response.status)
    body = Nokogiri::HTML(last_response.body)
    refute body.css('.post_list li').empty?
  end

  def assert_header(body)
    assert_includes(body.css('header').inner_text, '$ sysdef_')
  end

  def assert_body_copy(body)
    refute body.css('#post_title').inner_text.empty?
    assert_match(/last updated: \d\d \w+ 20\d\d/,
                 body.css('#post_date').inner_text)
  end

  def assert_sidebar(body)
    refute body.css('#post_links').empty?
    refute body.css('#article_links').empty?
    refute body.css('#tag_links').empty?
  end

  def assert_footer(body)
    assert_includes(body.css('footer').inner_text, 'Sysdef')
    assert_includes(body.css('footer').inner_text, Date.today.year.to_s)
  end

  # Get all the review post links in the right-hand panel
  #
  def extract_post_links(body)
    Nokogiri::HTML(body).css('ul#post_links a').map do |l|
      l.attributes['href'].value
    end
  end

  def extract_article_links(body)
    Nokogiri::HTML(body).css('ul#article_links a').map do |l|
      l.attributes['href'].value
    end
  end

  def extract_tag_links(body)
    Nokogiri::HTML(body).css('ul#tag_links a').map do |l|
      l.attributes['href'].value
    end
  end
end
