# Include hook code here
require 'acts_as_cacheable'
ActiveRecord::Base.send(:include, Acts::Cacheable)
ActiveResource::Base.send(:include, Acts::Cacheable)

