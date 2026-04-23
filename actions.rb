Bundler.require

class DummyController
  def self.resource_type_actions
    %i[test test2 break]
  end

  def self.resource_type_properties
    %i[property1 token ssh_key password]
  end

  def initialize(opts)
    @options = opts
  end

  def test
    log.info "running test action with options: #{@options}"
  end

  def test2
    log.info "running test2 action with options: #{@options}"
  end

  def break
    raise "running break action with options: #{@options}"
  end
end

resource_type :dummy do
  controller DummyController

  property :another_property

  action :another_action, description: 'resource type action' do |resource|
    log.info "running another_action action with options: #{resource.controller.instance_variable_get(@options)}"
    log.info "running another_action action with options: #{another_property}"
  end
end

dummy :my_resource do
  property1 'value1'
  token 'value2'
  ssh_key 'value3'
  password 'value4'
  another_property 'another value'

  action :resource_action, description: 'resource action' do |resource|
    log.info "running resource_action action with options: #{resource.controller.instance_variable_get(@options)}"
    log.info "running resource_action action with options: #{property1}, #{property2}, #{property3}, #{another_property}"
  end
end
