# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'weixin_public/version'

Gem::Specification.new do |spec|
  spec.name          = "weixin_public"
  spec.version       = WeixinPublic::VERSION
  spec.authors       = "goxplanet"
  spec.email         = "otec.teng@gmail.com"
  spec.description   = %q{weixin public client }
  spec.summary       = %q{weixin public client,working with web page interface ,using HTTPS}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_dependency "nokogiri"
  spec.add_dependency "faraday"
end
