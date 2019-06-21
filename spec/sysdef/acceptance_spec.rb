#!/usr/bin/env ruby
# frozen_string_literal: true

%w[minitest minitest/unit minitest/autorun rack/test pathname json
   yaml cgi nokogiri].each { |f| require f }

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
    refute body.css('#header').empty?
    refute body.css('#container').empty?
    refute body.css('#footer').empty?
    assert_links(last_response.body)
  end

  def test_all_posts
    get '/'
    extract_post_links(last_response.body).each do |uri|
      _test_review_post(uri)
    end
  end

  def test_all_articles
    get '/'
    extract_article_links(last_response.body).each do |uri|
      _test_article(uri)
    end
  end

  def test_api_404
    get '/api/no_such_thing'
    assert_equal(404, last_response.status)
    refute last_response.body.include?('Sinatra doesn’t know this ditty')
    assert last_response.body.include?('404')
    body = Nokogiri::HTML(last_response.body)
    refute body.css('#header').empty?
    refute body.css('#container').empty?
    refute body.css('#footer').empty?
  end

  def _test_by_score
    0.upto(5) do |i|
      get "/score/#{i}"
      assert_equal(200, last_response.status)
      assert_match(%r{<h1>\s*#{i}/5}, last_response.body)
      assert last_response.body.include?('<div id="link_list"')
    end

    get '/score/6'
    assert_equal(404, last_response.status)
  end

  def test_health
    get '/_health'
    assert_equal(200, last_response.status)
    body = Nokogiri::HTML(last_response.body)
    refute body.css('#header').empty?
    refute body.css('#container').empty?
    refute body.css('#footer').empty?
    assert_links(last_response.body)
  end

  def _test_review_post(uri)
    get uri
    assert_equal(200, last_response.status)
    assert_links(last_response.body)
    body = Nokogiri::HTML(last_response.body)
    refute body.css('#transducers').empty?
    refute body.css('#header').empty?
    refute body.css('#container').empty?
    refute body.css('#footer').empty?

    body.search('.review').each do |review|
      anchor = review.at_css('a')
      assert_match(/^[\w-]+-[\w-]+$/, anchor.attributes['name'].value)
      refute review.css('.artisttitle .artist').empty?
      refute review.css('.artisttitle .title').empty?
      assert review.css('.artisttitle a').first.attributes['href']
        .value.start_with?('/artist/')
      refute review.css('.review_body').empty?
      assert %w[0 1 2 3 4 5].include?(review.css('.score').text.strip)
    end
  end

  def _test_article(uri)
    get uri
    assert_equal(200, last_response.status)
    assert_links(last_response.body)
    body = Nokogiri::HTML(last_response.body)
    assert body.css('#transducers').empty?
    refute body.css('#header').empty?
    refute body.css('#container').empty?
    refute body.css('#footer').empty?
  end

  def assert_links(body)
    assert body.include?('blog posts')
    assert body.include?('articles')
  end

  # Get all the review post links in the right-hand panel
  #
  def extract_post_links(body)
    Nokogiri::HTML(body).css('li#post_links a').map do |l|
      l.attributes['href'].value
    end
  end

  def extract_article_links(body)
    Nokogiri::HTML(body).css('li#article_links a').map do |l|
      l.attributes['href'].value
    end
  end
end
