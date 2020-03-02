
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "mdextab/version"

Gem::Specification.new do |spec|
  spec.name          = "mdextab"
  spec.version       = Mdextab::VERSION
  spec.authors       = ["yasuo kominami"]
  spec.email         = ["ykominami@gmail.com"]

  spec.summary       = %q{mainly extend table tag of HTML5 of Makrdown on Pandoc.}
  spec.description   = %q{mainly extend table tag of HTML5 of Makrdown on Pandoc.}
  spec.homepage      = ""
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
#    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

#    spec.metadata["homepage_uri"] = spec.homepage
#    spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
#    spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "byebug"

  spec.add_runtime_dependency "simpleoptparse"
  spec.add_runtime_dependency "erubis"
  spec.add_runtime_dependency "messagex"
  spec.add_runtime_dependency "filex"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-performance"
  spec.add_development_dependency "rubocop-rails"
end
