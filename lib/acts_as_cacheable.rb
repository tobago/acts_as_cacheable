# ActsAsCacheable
# TODO:
# module für ActiveRecord (ONLY):
# Setting a timestamp when the last flushing was done
# Aim: ActiveResourceServerController has to be able to return a NotModified, if there was no updating process on the model 

# Caches a collection of ActiveRecord objects and ActiveResource objects as well for performance reasons (means not to hurt the database in these cases)
# This caching mechanism is intended for caching lookup objects, which won't be changed for longer periods of time, e.g. departments of a comapany
module Acts
  module Cacheable
    def self.included(base)
      base.extend(SingletonMethods)
    end

    module SingletonMethods
      # Defined options:
      # :reload --> current timestamp
      # E.g. 30.seconds; 2.hours
      # :key --> the key of the method to search for in the collection [optional], default: id
      # E.g. :name
      # Finder options [optional]
      # E.g. :order => :name
      def acts_as_cacheable(options = {})
        extend Acts::Cacheable::ClassMethods
        include Acts::Cacheable::InstanceMethods
        after_save :flush
        after_destroy :flush
        @c_cached_at = Time.now
        @c_reload_after = options.delete :reload
        @c_key = (options.delete :key) || :id
        @c_options = options
        cache_finder
      end
# TODO:
# Following scenario:
# The associated cached object was assigned to the belongs_to_cached association and has to be saved, 
# but meanwhile the cached collection was updated.
# Is the assigned belongs_to foreign key correctly?
      def belongs_to_cached attribute, options = {}
        ivar = "@#{attribute}"

        define_method attribute do
          instance_variable_get(ivar) || 
            instance_variable_set( ivar, (options[:class_name] || attribute.to_s.classify).constantize[self.send("#{attribute}_id")] )
        end
        
        define_method "#{attribute}=" do |object|
          instance_variable_set ivar, object
          self.send "#{attribute}_id=", (object ? object.id : nil)
        end
      end

    end

    module InstanceMethods
      def flush
        self.class.flush
      end

      def updated?
        false
      end
    end

    module ClassMethods
      # Returns a cached object or nil, defined by its ID.
      # E.g. Department[1] --> department
      def [] (id)
        all[id]
      end
 
      # Returns a cached object or nil, defined by its accessor method.
      # E.g. Department === 'Design Engineering' --> department
      # Department === 1 --> department (if no key was assigned)
      def ===(key)
        all.detect{|x| x.send(@c_key) == key if x}
      end
    
      # Returns a collection of all cached objects.
      # E.g.: Department.all --> departments
      def all
        @c_reload_after && ( (@c_cached_at + @c_reload_after) < Time.now ) ? flush : @c_all_cached_objects.compact
      end
  
      # Overwritten method, which returns the first object of the cached collection
      def first
        all.detect{|x| !x.nil?}
      end

      # Overwritten method, which returns the last object of the cached collection
      def last
        all.last
      end

      # Overwritten method, which returns a cached object or nil, defined by its ID.
      def find_by_id id
        all[id]
      end

      # Flushes the cached objects.
      # The timestamp and the collection of cached objects will be reset
      def flush
        @c_cached_at = Time.now
        cache_finder
      end

   private
      # Caches a collection of objects depending on the assigned finder options (see acts_as_cacheable).
      def cache_finder
        @c_all_cached_objects = Array.new
        find(:all, @c_options).each{|instance| @c_all_cached_objects[instance.id] = instance}
      end
    end
  end
end
