# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'online_pay/version'

Gem::Specification.new do |spec|
  spec.name          = "online_pay"
  spec.version       = OnlinePay::VERSION
  spec.authors       = ["xixiaoyu"]
  spec.email         = ["xixiaoyu@yundianjia.com"]

  spec.summary       = "An unofficial simple online pay gem"
  spec.description   = "An unofficial simple online pau gem"
  spec.homepage      = "https://github.com/xixiaoyu/online_pay"

  spec.require_paths = ["lib"]


  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  spec.test_files = Dir["test/**/*"]

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }


  spec.add_runtime_dependency "rest-client", ">= 2.0.1"
  spec.add_runtime_dependency "activesupport", ">= 5.0.0"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rails", "~> 5.0.0"
end
