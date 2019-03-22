Pod::Spec.new do |s|
  s.name         = "Cachyr"
  s.version      = "1.2.4"
  s.summary      = "A thread-safe and type-safe key-value data cache written in Swift."
  s.description  = <<-DESC
    Cachyr is a small key-value cache written in Swift. It has some nice properties:

    - Written in Swift 4.
    - Thread-safe.
    - Type-safe.
    - Disk and memory cache.
    - Clean, single-purpose implementation. Does caching and nothing else.
  DESC
  s.homepage     = "https://github.com/YR/Cachyr"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Yr" => "mobil-tilbakemelding@nrk.no" }
  s.social_media_url   = ""
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.watchos.deployment_target = "2.0"
  s.tvos.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/YR/Cachyr.git", :tag => s.version.to_s }
  s.source_files  = "Sources/**/*"
  s.frameworks  = "Foundation"
end
