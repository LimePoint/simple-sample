Bundler.require

puts "ENV: #{ENV}"
puts "Properties: #{Opschain.properties}"

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
  OpsChain.logger.info "Hello from multi level action, inserting one extra child"
  OpsChain.child_steps = [:child_1, :child_2, :child_3, :child_4]
end

action :child_1, description: 'my children are modified', run_as: :parallel, steps: [:grandchild_1, :grandchild_2] do
  OpsChain.logger.info "Appending a grandchild"
  OpsChain.append_child_steps(:grandchild_3)
end

action :child_2, description: 'my children are replaced', run_as: :parallel, steps: [:grandchild_3, :grandchild_4] do
  OpsChain.logger.info "Replacing the steps entirely with a different count"
  OpsChain.child_steps = [:grandchild_5]
end

action :child_3, description: 'my children are replaced', run_as: :parallel, steps: [:grandchild_1, :grandchild_2, :grandchild_3] do
  OpsChain.logger.info "Replacing the steps with the same number, but different actions"
  OpsChain.child_steps = [:grandchild_4, :grandchild_5, :grandchild_6]
end

action :child_4, description: 'my children are removed', run_as: :parallel, steps: [:grandchild_1, :grandchild_2, :grandchild_3] do
  OpsChain.logger.info "Now I don't have any steps"
  OpsChain.child_steps = []
end

(1..6).each do |i|
  action "grandchild_#{i}" do
    OpsChain.logger.info "Hello from grandchild_#{i}"
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
