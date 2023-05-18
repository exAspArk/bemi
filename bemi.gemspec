# frozen_string_literal: true

require_relative "lib/bemi/version"

Gem::Specification.new do |spec|
  spec.name = "bemi"
  spec.version = Bemi::VERSION
  spec.authors = ["exAspArk"]
  spec.email = ["exaspark@gmail.com"]

  spec.summary = "Ruby framework for managing code workflows."
  spec.description = "Bemi allows to describe and chain multiple actions similarly to function pipelines, have the execution reliability of a background job framework, unlock full visibility into business and infrastructure processes, distribute workload and implementation across multiple services as simply as running everything in the monolith."
  spec.homepage = "https://github.com/exAspArk/bemi"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/exAspArk/bemi"
  spec.metadata["changelog_uri"] = "https://github.com/exAspArk/bemi/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(bin|images|\.git|\.github)\/|(\.rspec|\.gitignore)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "json-schema", "~> 4.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
