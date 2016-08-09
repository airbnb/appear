require 'ostruct'

module Appear
  # Dependency-injectable service class. Service will raise errors during
  # initialization if its dependencies are not met.
  class BaseService
    def initialize(given_services = {})
      req_service_instances = {}
      self.class.required_services.each do |service|
        unless given_services[service]
          raise ArgumentError.new("required service #{service.inspect} not provided to instance of #{self.class.inspect}")
        end

        req_service_instances[service] = given_services[service]
      end
      @services = OpenStruct.new(req_service_instances)
    end

    # Delegate a method to another service. Declares a dependency on that
    # service.
    def self.delegate(method, service)
      require_service(service)
      self.send(:define_method, method) do |*args, &block|
        unless @services.send(service).respond_to?(method)
          raise NoMethodError.new("Would call private method #{method.inspect} on #{service.inspect}")
        end
        @services.send(service).send(method, *args, &block)
      end
    end

    # List all the services required by this service class.
    def self.required_services
      @required_services ||= []

      if self.superclass.respond_to?(:required_services)
        @required_services + self.superclass.required_services
      else
        @required_services
      end
    end

    # Declare a dependency on another service.
    def self.require_service(name)
      @required_services ||= []

      return if required_services.include?(name)
      @required_services << name
    end


    private

    def services
      @services
    end
  end

  # All regular services want to log and output stuff, so they inherit from
  # here.
  class Service < BaseService
    delegate :log, :output
    delegate :log_error, :output
    delegate :output, :output
  end
end
