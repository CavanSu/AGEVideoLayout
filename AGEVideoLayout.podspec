Pod::Spec.new do |s|
  s.name         = "AGEVideoLayout"
  s.version      = "1.0.4"
  s.summary      = "A Great Evolution VideoLayout."
  s.description  = "You can use AGEVideoLayout to achieve the video views layout you want."

  s.homepage     = "https://github.com/CavanSu/AGEVideoLayout"
  s.license      = "MIT"
  s.author       = { "CavanSu" => "403029552@qq.com" }
  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.10"
  
  s.source         = { :git => "https://github.com/CavanSu/AGEVideoLayout.git", :tag => "#{s.version}" }
  s.source_files   = "sources/*.{h,m,swift}"
  s.ios.frameworks = "UIKit"
  s.osx.frameworks = "Cocoa"

  s.module_name   = 'AGEVideoLayout'
  s.swift_version = '4.0'
end
