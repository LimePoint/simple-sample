Bundler.require

action :ant_hello, description: 'Echo hello with ant' do
  sh 'echo ant do stuff'
end

action :ant_welcome do
  sh 'echo ant do welcome stuff'
end

action :ant_phase, steps: %i[ant_hello ant_welcome], run_as: :parallel

action :shell_hello, description: 'Echo hello with shell' do
  result = exec_command 'bash ./hello_world.sh'
  OpsChain.logger.info "Failed with: #{result.stderr}" if result.failed?
end

action :default, steps: %i[ant_phase shell_hello], description: 'Default action' do
  OpsChain.logger.info "Inside default action - to test fluent-bit"
end

action :single_step_action, description: 'Single step action' do
  OpsChain.logger.info "Hello from single step action"
end

action :multi_level_action, steps: [:child_1, :child_2, :child_4], description: 'Multi level action' do
  OpsChain.logger.info "Hello from multi level action, inserting one extra child and appending another"
  OpsChain.child_steps = [:child_1, :child_2, :child_3, :child_4, :child_5]
end

action :child_1, description: 'my children are modified', run_as: :parallel, steps: [:grandchild_1, :grandchild_2] do
  OpsChain.logger.info "Appending a grandchild"
  OpsChain.append_child_steps(:grandchild_3)
end

action :child_2, description: 'my children are replaced', run_as: :parallel, steps: [:grandchild_4, :grandchild_5] do
  OpsChain.logger.info "Replacing the steps entirely with a different count"
  OpsChain.child_steps = [:grandchild_4]
end

action :child_3, description: 'my children are replaced', run_as: :parallel, steps: [:grandchild_1, :grandchild_2, :grandchild_3] do
  OpsChain.logger.info "Replacing the steps with the same number, but different actions and converting to sequential"
  OpsChain.child_steps = [:grandchild_5, :grandchild_6, :grandchild_7]
  OpsChain.child_execution_strategy=:sequential
end

action :child_4, description: 'my children are removed', run_as: :parallel, steps: [:grandchild_1, :grandchild_2, :grandchild_3] do
  OpsChain.logger.info "Now I don't have any steps"
  OpsChain.child_steps = []
end

action :child_5, description: 'my children are removed', run_as: :sequential, steps: [:grandchild_9, :grandchild_10, :grandchild_8] do
  OpsChain.logger.info "Reordering the steps and converting to parallel"
  OpsChain.child_steps = [:grandchild_8, :grandchild_9, :grandchild_10]
  OpsChain.child_execution_strategy=:parallel
end

(1..10).each do |i|
  action "grandchild_#{i}" do
    OpsChain.logger.info "Hello from grandchild_#{i}"
    OpsChain.child_steps = [:ant_phase] if i == 5
  end
end

action :change_with_wait, description: 'Change with a wait step', steps: [:properties_1, OpsChain.wait_step, :properties_2]

action :properties_1 do
  OpsChain.logger.info("Starting properties_1 with #{JSON.pretty_generate(OpsChain.properties)}")
  OpsChain.properties_for(:project).run_number = (OpsChain.properties.run_number || 0) + 1
  OpsChain.properties_for(:environment).current_date = Time.now
end

action :properties_2 do
  OpsChain.logger.info("Starting properties_2 with #{JSON.pretty_generate(OpsChain.properties)}")
end

action :many_parallel, steps: (1..20).map { |i| "many_parallel_child_#{i}" }, run_as: :parallel, description: 'Lots of steps in parallel'

(1..20).each do |i|
  action "many_parallel_child_#{i}", steps: ["nested_child_#{i}"]
end

(1..20).each do |i|
  action "nested_child_#{i}" do
    OpsChain.logger.info "Hello from nested_child_#{i}"
  end
end
