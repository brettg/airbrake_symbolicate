# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = 'airbrake_symbolicate'
  s.version     = '0.1'
  s.date = Time.now.strftime('%Y-%m-%d')
  s.authors     = ['Brett Gibson']
  s.email       = ['brettdgibson@gmail.com']
  s.homepage    = ''
  s.summary     = 'symbolicate airbrake iOS crash reports'
  s.description = 'lib and cli tool to download airbrake iOS crash reports via the api and ' +
                  'symbolicate them'
  s.licenses = 'MIT'

  s.add_dependency('activeresource', '>= 0')
  s.add_development_dependency('bundler', '>= 0')

  s.files += Dir['lib/**/*.rb'] + Dir['bin/*'] + %w(LICENSE.txt README.rdoc Rakefile)
end
