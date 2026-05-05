Bundler.require

action :ant_hello, description: 'Echo hello with ant', step_name: "ANT hello" do
  sh 'echo ant do stuff'
end

action :ant_welcome do
  sh 'echo ant do welcome stuff'
end

action :ant_phase, steps: %i[ant_hello ant_welcome], run_as: :parallel

action :ant_with_wait, description: 'Ant with a wait step', steps: [
         :ant_hello,
         OpsChain.wait_step(seconds: 5, step_name: '5 second wait'),
         OpsChain.wait_step(step_name: 'Pause for ANT welcome'),
         :ant_welcome
       ]

action :shell_hello, description: 'Echo hello with shell' do
  result = exec_command 'bash ./hello_world.sh'
  log.info "Failed with: #{result.stderr}" if result.failed?
end

action :default, steps: %i[ant_phase shell_hello], description: 'Default action' do
  log.info "Inside default action - to test fluent-bit"
end

action :single_step_action, description: 'Single step action' do
  log.info "Hello from single step action"
end

action :multi_level_action, steps: [:child_1, :child_2, :child_4, :child_6, :child_7, :child_8, :child_9], description: 'Multi level action' do
  log.info "Hello from multi level action, inserting one extra child and appending another"
  OpsChain.child_steps = [:child_1, :child_2, :child_3, :child_4, :child_5]
end

action :child_1, description: 'my children are modified', run_as: :parallel, steps: [:grandchild_1, :grandchild_2] do
  log.info "Appending a grandchild"
  OpsChain.append_child_steps(:grandchild_3)
end

action :child_2, description: 'my children are replaced', run_as: :parallel, steps: [:grandchild_4, :grandchild_5] do
  log.info "Replacing the steps entirely with a different count"
  OpsChain.child_steps = [:grandchild_4]
end

action :child_3, description: 'my children are replaced', run_as: :parallel, steps: [:grandchild_1, :grandchild_2, :grandchild_3] do
  log.info "Replacing the steps with the same number, but different actions and converting to sequential"
  OpsChain.child_steps = [:grandchild_5, :grandchild_6, :grandchild_7]
  OpsChain.child_execution_strategy=:sequential
end

action :child_4, description: 'my children are removed', run_as: :parallel, steps: [:grandchild_1, :grandchild_2, :grandchild_3] do
  log.info "Now I don't have any steps"
  OpsChain.child_steps = []
end

action :child_5, description: 'my children are removed', run_as: :sequential, steps: [:grandchild_9, :grandchild_10, :grandchild_8] do
  log.info "Reordering the steps and converting to parallel"
  OpsChain.child_steps = [:grandchild_8, :grandchild_9, :grandchild_10]
  OpsChain.child_execution_strategy=:parallel
end

(6..9).each do |i|
  action "child_#{i}" do
    log.info "Not actually executed, used to test removing steps from the multi_level_action parent"
  end
end

(1..10).each do |i|
  action "grandchild_#{i}" do
    log.info "Hello from grandchild_#{i}"
    OpsChain.child_steps = [:ant_phase] if i == 5
  end
end

action :change_with_wait, description: 'Change with a wait step', steps: [:properties_1, OpsChain.wait_step, :properties_2]

action :properties_1 do
  log.info("Starting properties_1 with #{JSON.pretty_generate(OpsChain.properties)}")
  OpsChain.properties_for(:project).run_number = (OpsChain.properties.run_number || 0) + 1
  OpsChain.properties_for(:asset).current_date = Time.now
end

action :properties_2 do
  log.info("Starting properties_2 with #{JSON.pretty_generate(OpsChain.properties)}")
end

action :many_parallel, steps: (1..20).map { |i| "many_parallel_child_#{i}" }, run_as: :parallel, description: 'Lots of steps in parallel'

(1..20).each do |i|
  action "many_parallel_child_#{i}", steps: ["many_parallel_grandchild_#{i}"], run_as: :sequential
end

(1..20).each do |i|
  action "many_parallel_grandchild_#{i}", steps: %w[nested_child_1 nested_child_2], run_as: :parallel
end


(1..2).each do |i|
  action "nested_child_#{i}" do
    log.info "Hello from nested_child_#{i}"
  end
end

action :dump_context, description: 'Print the OpsChain context' do
  log.info('The Step Context JSON file is:')
  log.info(JSON.pretty_generate(JSON.parse(OpsChain::Core::StepContext.step_context_json)))
  log.info("\n\n\n\n\nThe OpsChain Context is:")
  log.info(JSON.pretty_generate(OpsChain.context))
end

action :modify_properties, description: 'Test updating properties' do
  OpsChain.properties_for(:project).project_current_date = Time.now.utc.iso8601
  OpsChain.properties_for(:environment).environment_current_date = Time.now.utc.iso8601 if OpsChain.context.parents.include?('environment')
  OpsChain.properties_for(:template_version).template_current_date = Time.now.utc.iso8601
  OpsChain.properties_for(:asset).asset_current_date = Time.now.utc.iso8601
  OpsChain.properties_for(:change).change_current_date = Time.now.utc.iso8601
end

child_steps = [:stop, :do_stuff, :start, :stop]
child_steps.uniq.each do |child_step|
  action child_step do
    puts "running #{child_step}"
  end
end

action :dummy_action do
  puts "running dummy action"
end

action repeated_prereqs: child_steps, description: 'repeated prereqs'
action :repeated_child, steps: child_steps, description: 'repeated child steps'
action :repeated_tree, steps: [:repeated_child, :dummy_action, :repeated_child], description: 'repeated tree'

action :failure_ignored, ignore_failure: true, description: 'test the ignore failure kwarg' do
  log.info "Before failure"
  raise "This is a failure to be ignored"
end

action :parent_of_ignore_failure, steps: [:failure_ignored], description: 'parent with an ignore failure child'

action :input_step_change, steps: [
  :print_properties,
  :mod_properties,
  OpsChain.input_step(
    input_arguments: [
      :name,
      id: { type: :integer, path: '/input/id', default_value: 123 },
      optional_arg: { type: :array, required: false, default_value: ['a', 'b', 'c'] },
      boolean_arg: { path: '/my_values', type: :boolean, default_value: true},
      float_arg: { path: '/my_values', type: :float, default_value: 1234.56},
      arg_with_desc: { description: "an argument with a description" },
      arg_with_default: { gui_name: "Argument With Default", default_value: "default value" }
    ],
    step_name: "Data request!"
  ),
  :print_properties
], description: 'Test that input steps can change properties'

action :mod_properties do
  OpsChain.properties_for(:asset).project_current_date = Time.now.utc.iso8601
  OpsChain.properties_for(:change).change_current_date = Time.now.utc.iso8601
end

action :print_properties do
  log.info("Current properties are: #{JSON.pretty_generate(OpsChain.properties)}")
  log.info("Made up of: ")
  log.info("Project properties: #{JSON.pretty_generate(OpsChain.properties_for(:project))}")
  log.info("Environment properties: #{JSON.pretty_generate(OpsChain.properties_for(:environment))}") if OpsChain.context.parents.include?('environment')
  log.info("Asset properties: #{JSON.pretty_generate(OpsChain.properties_for(:asset))}") if OpsChain.context.parents.include?('asset')
  log.info("Template Version properties: #{JSON.pretty_generate(OpsChain.properties_for(:template_version))}") if OpsChain.context.include?('template_version')
  log.info("Change properties: #{JSON.pretty_generate(OpsChain.properties_for(:change))}")
end

class MyController
  def self.resource_type_actions = [:dummy_action]
  def self.resource_type_properties = [:cont_property, :type_property]

  def initialize(opts)
    @opts = opts
  end

  def type_property=(value)
    @opts[:type_property] = value
  end
  def cont_property = @opts[:cont_property]
  def type_property = @opts[:type_property]

  def dummy_action
    log.info "Hello from the controller action! cont_property: #{cont_property}, type_property: #{type_property}"
  end
end

resource_type :my_resource_type do
  controller MyController

  property :another_resource
end

my_resource_type :my_resource_1 do
  cont_property 'a value from the resource'
  type_property 'a value from the type'
end

my_resource_type :my_resource_2 do
  cont_property 'a value from the resource'
  type_property 'a value from the type'
  another_resource :my_resource_1

  action :resource_action do |res|
    log.info "Hello from the my_resource_2"
    log.info "the other resource is #{another_resource}"
    log.info "my_resource_1 is #{my_resource_1}"
    res.controller.type_property = :my_resource_1.controller
    log.info "res.controller.type_property is #{res.controller.type_property}"
  end
end

action :fred do
  puts :my_resource_1.controller
end
